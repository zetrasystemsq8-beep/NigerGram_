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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final customerEmail = user?.email ?? 'user@example.com';
      final customerName = user?.displayName ?? 'NigerGram User';

      final init = await _monnify.initTransaction(
        amount: amount,
        customerEmail: customerEmail,
        customerName: customerName,
      );
      
      final checkoutUrl = init['checkoutUrl'] as String?;
      final transactionReference = init['transactionReference'] as String?;

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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Wallet funded successfully')),
              );
              Navigator.of(context).pop();
            }
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payment verification timeout or not confirmed')),
              );
            }
          }
        }
      } else {
        throw Exception('Failed to obtain sandbox checkout verification gateway URL');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Funding failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _pollUntilPaid(String reference, {Duration timeout = const Duration(minutes: 2)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      try {
        final res = await _monnify.queryTransaction(reference);
        final status = (res['paymentStatus'] as String?) ?? (res['status'] as String?) ?? '';
        if (status.toUpperCase() == 'PAID' || status.toUpperCase() == 'SUCCESS') {
          return true;
        }
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 5));
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Fund Wallet', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Amount (₦)',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.greenAccent),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _startFunding,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading 
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                  )
                : const Text('Pay via Monnify Sandbox', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
