import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nigergram/core/services/monnify_service.dart';
import 'package:nigergram/core/di/dependency_injector.dart';
import 'package:nigergram/features/wallet/presentation/bloc/wallet_cubit.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FundWalletView extends StatefulWidget {
  const FundWalletView({super.key});

  @override
  State<FundWalletView> createState() => _FundWalletViewState();
}

class _FundWalletViewState extends State<FundWalletView> {
  final _amountController = TextEditingController();
  bool _isLoading = false;
  final MonnifyService _monnify = getIt<MonnifyService>();
  final _walletCubit = getIt<WalletCubit>();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _startFunding() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    setState(() => _isLoading = true);

    try {
      // Use authenticated user's email when available; fallback to a placeholder
      final user = FirebaseAuth.instance.currentUser;
      final customerEmail = user?.email ?? 'user@example.com';

      // Pass customerEmail as required by the Monnify SDK wrapper
      final init = await _monnify.initTransaction(amount: amount, customerEmail: customerEmail);
      final checkoutUrl = init['checkoutUrl'] as String?;
      final transactionReference = init['reference'] as String?;

      if (checkoutUrl != null) {
        final uri = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }

        if (transactionReference != null) {
          final paid = await _pollUntilPaid(transactionReference, timeout: const Duration(minutes: 2));
          if (paid) {
            await _walletCubit.fundWallet(amount: amount);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wallet funded successfully')));
              Navigator.of(context).pop();
            }
          } else {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment not confirmed')));
          }
        }
      } else {
        throw Exception('Failed to obtain checkout url');
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Funding failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // NOTE: queryTransaction expects a single positional reference parameter in this Monnify wrapper
  Future<bool> _pollUntilPaid(String reference, {Duration timeout = const Duration(minutes: 2)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      try {
        final res = await _monnify.queryTransaction(reference);
        final status = (res['status'] as String?) ?? '';
        if (status.toLowerCase() == 'paid' || status.toLowerCase() == 'success') return true;
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 5));
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fund Wallet')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (₦)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _startFunding,
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Pay via Monnify'),
            ),
          ],
        ),
      ),
    );
  }
}
