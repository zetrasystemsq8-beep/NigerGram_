import 'package:flutter/material.dart';
import 'package:nigergram/core/di/dependency_injector.dart';
import 'package:nigergram/features/wallet/presentation/bloc/wallet_cubit.dart';

class WithdrawView extends StatefulWidget {
  const WithdrawView({super.key});

  @override
  State<WithdrawView> createState() => _WithdrawViewState();
}

class _WithdrawViewState extends State<WithdrawView> {
  final _amountController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();
  bool _isSubmitting = false;
  final _cubit = getIt<WalletCubit>();

  @override
  void dispose() {
    _amountController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    if (_bankNameController.text.isEmpty || _accountNumberController.text.isEmpty || _accountNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter bank details')));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await _cubit.requestWithdrawal(
        amount: amount,
        bankName: _bankNameController.text,
        bankAccountNumber: _accountNumberController.text,
        bankAccountName: _accountNameController.text,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Withdrawal requested')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Withdrawal failed: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Withdraw')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (₦)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _bankNameController, decoration: const InputDecoration(labelText: 'Bank Name', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _accountNumberController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Account Number', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _accountNameController, decoration: const InputDecoration(labelText: 'Account Name', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _isSubmitting ? null : _submit, child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Request Withdrawal')),
          ],
        ),
      ),
    );
  }
}
