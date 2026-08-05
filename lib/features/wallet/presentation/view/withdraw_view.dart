import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nigergram/core/di/dependency_injector.dart';
import 'package:nigergram/core/services/coin_service.dart';
import 'package:nigergram/features/wallet/presentation/bloc/wallet_cubit.dart';

/// Cash-out request screen. NigerGram doesn't move real money here —
/// this just deducts the cent balance and logs a request. The actual
/// payout happens on ZTC, tied to the user's ZetraID.
class WithdrawView extends StatefulWidget {
  const WithdrawView({super.key});

  @override
  State<WithdrawView> createState() => _WithdrawViewState();
}

class _WithdrawViewState extends State<WithdrawView> {
  final _amountController = TextEditingController();
  bool _isSubmitting = false;
  bool _isCheckingPin = true;
  bool _hasPin = false;
  final _cubit = getIt<WalletCubit>();

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
  }

  Future<void> _checkPinStatus() async {
    final hasPin = await _cubit.hasPinSet();
    if (mounted) {
      setState(() {
        _hasPin = hasPin;
        _isCheckingPin = false;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<String?> _promptForPin({required String title, required String body}) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 8),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                counterText: '',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Confirm', style: TextStyle(color: Color(0xFFFF0050))),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final centAmount = int.tryParse(_amountController.text) ?? 0;
    if (centAmount < CoinService.MIN_UNIT_CENTS) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Minimum cash-out is ${CoinService.MIN_UNIT_CENTS} cent')),
      );
      return;
    }

    // Set up a PIN the first time, otherwise verify it before proceeding.
    if (!_hasPin) {
      final newPin = await _promptForPin(
        title: 'Set a Wallet PIN',
        body: 'Choose a 4-digit PIN. You\'ll use this to confirm withdrawals going forward.',
      );
      if (newPin == null || newPin.length != 4) return;
      await _cubit.setPin(newPin);
      setState(() => _hasPin = true);
    } else {
      final pin = await _promptForPin(
        title: 'Enter Your PIN',
        body: 'Confirm this cash-out request with your wallet PIN.',
      );
      if (pin == null || pin.isEmpty) return;
      final valid = await _cubit.verifyPin(pin);
      if (!valid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incorrect PIN'), backgroundColor: Colors.red),
          );
        }
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      await _cubit.requestWithdrawal(centAmount: centAmount);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cash-out requested'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cash-out failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      appBar: AppBar(
        title: const Text('Cash Out', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isCheckingPin
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF0050)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Amount to cash out',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _amountController,
                    enabled: !_isSubmitting,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: InputDecoration(
                      hintText: 'Cents (CP)',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: const Color(0xFF1A1A24),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Minimum ${CoinService.MIN_UNIT_CENTS} cent per request.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.blueAccent, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'These cents leave your NigerGram wallet now. They\'ll be available to convert to real money on ZTC afterward.',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF0050),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Request Cash Out',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
