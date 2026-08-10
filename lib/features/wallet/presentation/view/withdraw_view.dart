import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nigergram/core/di/dependency_injector.dart';
import 'package:nigergram/core/services/coin_service.dart';
import 'package:nigergram/features/wallet/presentation/bloc/wallet_cubit.dart';

/// Withdrawal request screen. CP and Cent are ONE currency at two
/// denominations (1 CP = 1000 Cent) — not two separate currencies.
/// This screen takes both a CP amount and a Cent amount and combines
/// them into a single total (in the smallest unit, Cent) before
/// sending to ZTC, exactly mirroring how the ZTC "Send to Apps" screen
/// already lets someone enter CP + Cent together.
class WithdrawView extends StatefulWidget {
  const WithdrawView({super.key});

  @override
  State<WithdrawView> createState() => _WithdrawViewState();
}

class _WithdrawViewState extends State<WithdrawView> {
  final _cpController = TextEditingController();
  final _centController = TextEditingController();
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
    _cpController.dispose();
    _centController.dispose();
    super.dispose();
  }

  /// Combines the CP field and Cent field into one total, expressed in
  /// the smallest unit (Cent) — the only unit the backend RPC accepts.
  int get _totalCentAmount {
    final cp = int.tryParse(_cpController.text) ?? 0;
    final cent = int.tryParse(_centController.text) ?? 0;
    return (cp * 1000) + cent;
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

  Future<bool> _setupPin() async {
    final newPin = await _promptForPin(
      title: 'Set a Wallet PIN',
      body: 'Choose a 4-digit PIN. You\'ll use this to confirm withdrawals going forward.',
    );
    if (newPin == null || newPin.length != 4) return false;

    final confirmPin = await _promptForPin(
      title: 'Confirm Your PIN',
      body: 'Enter the same 4-digit PIN again to confirm.',
    );
    if (confirmPin == null) return false;

    if (newPin != confirmPin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PINs didn\'t match. Try again.'), backgroundColor: Colors.red),
        );
      }
      return false;
    }

    await _cubit.setPin(newPin);
    if (mounted) {
      setState(() => _hasPin = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wallet PIN set. Keep it safe — you\'ll need it for every withdrawal.'),
          backgroundColor: Colors.green,
        ),
      );
    }
    return true;
  }

  Future<void> _submit() async {
    final totalCent = _totalCentAmount;

    if (totalCent < CoinService.MIN_UNIT_CENTS) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Minimum withdrawal is ${CoinService.MIN_UNIT_CENTS} cent')),
      );
      return;
    }

    if (!_hasPin) {
      await _setupPin();
      return;
    }

    final pin = await _promptForPin(
      title: 'Enter Your PIN',
      body: 'Confirm this withdrawal with your wallet PIN.',
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

    setState(() => _isSubmitting = true);
    try {
      await _cubit.requestWithdrawal(centAmount: totalCent);
      if (context.mounted) {
        final cp = totalCent ~/ 1000;
        final cent = totalCent % 1000;
        final summary = cp > 0 && cent > 0
            ? '$cp CP $cent Cent'
            : cp > 0
                ? '$cp CP'
                : '$cent Cent';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Withdrew $summary to ZTC'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Withdrawal failed: $e'), backgroundColor: Colors.red),
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
        title: const Text('Withdraw', style: TextStyle(color: Colors.white)),
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
                    'Amount to withdraw',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('CP', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _cpController,
                              enabled: !_isSubmitting,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: const TextStyle(color: Colors.white, fontSize: 18),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: '0',
                                hintStyle: TextStyle(color: Colors.grey[600]),
                                filled: true,
                                fillColor: const Color(0xFF1A1A24),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Cent', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _centController,
                              enabled: !_isSubmitting,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: const TextStyle(color: Colors.white, fontSize: 18),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: '0',
                                hintStyle: TextStyle(color: Colors.grey[600]),
                                filled: true,
                                fillColor: const Color(0xFF1A1A24),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total: ${_totalCentAmount ~/ 1000} CP ${_totalCentAmount % 1000} Cent',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
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
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.blueAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _hasPin
                                ? 'This leaves your NigerGram wallet now and is credited straight to your ZTC balance.'
                                : 'You\'ll be asked to set a wallet PIN first — enter it twice to confirm, then tap this button again to withdraw.',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
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
                        : Text(
                            _hasPin ? 'Request Withdrawal' : 'Set PIN to Continue',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
