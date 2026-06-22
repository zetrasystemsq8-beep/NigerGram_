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

    setState(() => _isSending = true);
    final cubit = getIt<WalletCubit>();

    try {
      await cubit.sendTip(
        toUserId: widget.creatorId,
        toUsername: widget.creatorUsername,
        amount: amount,
        videoId: widget.videoId,
        message: _messageController.text.isEmpty ? null : _messageController.text,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tip sent successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send tip: $e')),
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
            Text('Tip @${widget.creatorUsername}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    decoration: const InputDecoration(
                      labelText: 'Amount (₦)',
                      hintText: 'Enter amount',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final val = double.tryParse(v ?? '0') ?? 0;
                      if (val <= 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      labelText: 'Message (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isSending ? null : _sendTip,
                    child: _isSending ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Send Tip'),
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
