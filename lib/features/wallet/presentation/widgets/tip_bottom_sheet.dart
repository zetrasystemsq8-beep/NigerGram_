import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nigergram/core/di/dependency_injector.dart';
import 'package:nigergram/features/wallet/presentation/bloc/wallet_cubit.dart';

class TipBottomSheet extends StatefulWidget {
  final String creatorId;
  final String creatorUsername;
  final String? videoId;

  const TipBottomSheet({
    required this.creatorId,
    required this.creatorUsername,
    this.videoId,
    super.key,
  });

  @override
  State<TipBottomSheet> createState() => _TipBottomSheetState();
}

class _TipBottomSheetState extends State<TipBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSending = false;
  String? _senderBalance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadSenderBalance();
  }

  Future<void> _loadSenderBalance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('wallets').doc(user.uid).get();
      final balance = (doc.data()?['balance'] as num?)?.toDouble() ?? 0.0;
      if (mounted) {
        setState(() => _senderBalance = balance.toStringAsFixed(2));
      }
    } catch (e) {
      debugPrint('❌ Failed to load sender balance: $e');
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendTip() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not authenticated')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      // ✅ PRODUCTION-GRADE: Execute atomic Firestore transaction
      // This ensures:
      // 1. Funds are deducted from sender's wallet
      // 2. Funds are added to creator's wallet
      // 3. Transaction record is created for both users
      // 4. All operations succeed or all fail (no partial transactions)

      await _firestore.runTransaction<void>((tx) async {
        // 1. Get sender's wallet
        final senderWalletRef = _firestore.collection('wallets').doc(currentUser.uid);
        final senderWalletSnap = await tx.get(senderWalletRef);

        if (!senderWalletSnap.exists) {
          throw Exception('Sender wallet not found');
        }

        final senderBalance = (senderWalletSnap.data()?['balance'] as num?)?.toDouble() ?? 0.0;
        if (senderBalance < amount) {
          throw Exception('Insufficient balance. Current balance: ₦$senderBalance');
        }

        // 2. Get creator's wallet (create if doesn't exist)
        final creatorWalletRef = _firestore.collection('wallets').doc(widget.creatorId);
        final creatorWalletSnap = await tx.get(creatorWalletRef);
        final creatorBalance = (creatorWalletSnap.data()?['balance'] as num?)?.toDouble() ?? 0.0;

        // 3. Deduct from sender
        tx.update(senderWalletRef, {
          'balance': FieldValue.increment(-amount),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 4. Add to creator (create if needed)
        if (creatorWalletSnap.exists) {
          tx.update(creatorWalletRef, {
            'balance': FieldValue.increment(amount),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          tx.set(creatorWalletRef, {
            'userId': widget.creatorId,
            'balance': amount,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // 5. Create transaction record for sender
        final txnDocRef = _firestore
            .collection('wallets')
            .doc(currentUser.uid)
            .collection('transactions')
            .doc();
        tx.set(txnDocRef, {
          'type': 'tip_sent',
          'amount': amount,
          'recipient': widget.creatorUsername,
          'recipientId': widget.creatorId,
          'videoId': widget.videoId ?? '',
          'message': _messageController.text.isEmpty ? null : _messageController.text,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // 6. Create transaction record for creator
        final creatorTxnDocRef = _firestore
            .collection('wallets')
            .doc(widget.creatorId)
            .collection('transactions')
            .doc();
        tx.set(creatorTxnDocRef, {
          'type': 'tip_received',
          'amount': amount,
          'sender': currentUser.displayName ?? currentUser.email?.split('@').first ?? 'User',
          'senderId': currentUser.uid,
          'videoId': widget.videoId ?? '',
          'message': _messageController.text.isEmpty ? null : _messageController.text,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Tip sent successfully!')),
        );
        Navigator.of(context).pop();
      }
      debugPrint('✅ Tip of ₦$amount sent to ${widget.creatorUsername}');
    } catch (e) {
      debugPrint('❌ Tip transaction failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send tip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.32,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: ListView(
          controller: controller,
          children: [
            const SizedBox(height: 8),
            Center(child: Container(height: 4, width: 48, color: Colors.grey[300])),
            const SizedBox(height: 16),
            Text('Tip @${widget.creatorUsername}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (_senderBalance != null)
              Text(
                'Your balance: ₦$_senderBalance',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true, signed: false),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]'))],
                    enabled: !_isSending,
                    decoration: const InputDecoration(
                      labelText: 'Amount (₦)',
                      hintText: 'Enter amount',
                      border: OutlineInputBorder(),
                      prefixText: '₦ ',
                    ),
                    validator: (v) {
                      final val = double.tryParse(v ?? '0') ?? 0;
                      if (val <= 0) return 'Enter a valid amount';
                      if (_senderBalance != null) {
                        final balance = double.tryParse(_senderBalance!) ?? 0;
                        if (val > balance) return 'Insufficient balance';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _messageController,
                    enabled: !_isSending,
                    decoration: const InputDecoration(
                      labelText: 'Message (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isSending ? null : _sendTip,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFE2C55),
                      disabledBackgroundColor: Colors.grey[400],
                    ),
                    child: _isSending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Send Tip',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
