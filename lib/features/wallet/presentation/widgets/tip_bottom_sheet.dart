import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  int? _senderCoinBalance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WalletCubit _cubit = getIt<WalletCubit>();

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
      final balance = (doc.data()?['coinBalance'] as num?)?.toInt() ?? 0;
      if (mounted) {
        setState(() => _senderCoinBalance = balance);
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

  Future<void> _sendGift() async {
    if (!_formKey.currentState!.validate()) return;
    final coinAmount = int.tryParse(_amountController.text) ?? 0;
    if (coinAmount <= 0) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not authenticated')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      // Delegate atomic transfer and transaction creation to the repository via the cubit
      await _cubit.sendGift(
        toUserId: widget.creatorId,
        toUsername: widget.creatorUsername,
        coinAmount: coinAmount,
        videoId: widget.videoId,
        message: _messageController.text.isEmpty ? null : _messageController.text,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Gift sent successfully!')),
        );
        Navigator.of(context).pop();
      }
      debugPrint('✅ Gift of $coinAmount coins sent to ${widget.creatorUsername}');
    } catch (e) {
      debugPrint('❌ Gift transaction failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send gift: $e'),
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
            Text('Send Gift to @${widget.creatorUsername}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (_senderCoinBalance != null)
              Text(
                'Your balance: $_senderCoinBalance coins',
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
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    enabled: !_isSending,
                    decoration: const InputDecoration(
                      labelText: 'Coin Amount',
                      hintText: 'Enter coin amount',
                      border: OutlineInputBorder(),
                      suffixText: 'coins',
                    ),
                    validator: (v) {
                      final val = int.tryParse(v ?? '0') ?? 0;
                      if (val <= 0) return 'Enter a valid coin amount';
                      if (_senderCoinBalance != null) {
                        if (val > _senderCoinBalance!) return 'Insufficient coin balance';
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
                    onPressed: _isSending ? null : _sendGift,
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
                            'Send Gift',
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
