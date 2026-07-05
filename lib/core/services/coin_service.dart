import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nigergram/core/services/monnify_service.dart';
import 'package:nigergram/core/services/coin_service.dart';
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
  String _statusMessage = '';
  int _coinsPreview = 0;
  final MonnifyService _monnify = getIt<MonnifyService>();
  final _walletCubit = getIt<WalletCubit>();

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_updateCoinsPreview);
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateCoinsPreview);
    _amountController.dispose();
    super.dispose();
  }

  void _updateCoinsPreview() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final coins = CoinService.coinFromNaira(amount);
    if (coins != _coinsPreview) {
      setState(() => _coinsPreview = coins);
    }
  }

  void _updateStatus(String message) {
    if (mounted) {
      setState(() => _statusMessage = message);
    }
  }

  /// Launch payment URL with fallback strategies for Android 11+
  Future<void> _launchPaymentUrl(String checkoutUrl) async {
    final uri = Uri.parse(checkoutUrl);

    try {
      // First try: externalApplication mode (opens in external browser)
      debugPrint('Attempting to launch URL in external application: $checkoutUrl');
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (launched) {
        _updateStatus('Payment page opened in browser...');
        return;
      }

      // Second try: platformDefault mode (system default behavior)
      debugPrint('External app launch failed, trying platformDefault mode');
      launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );

      if (launched) {
        _updateStatus('Payment page opened...');
        return;
      }

      // If both fail, throw exception with helpful message
      throw Exception(
        'Could not launch payment URL. Please ensure your device has a web browser installed.',
      );
    } catch (e) {
      debugPrint('URL launch error: $e');
      throw Exception('Failed to open payment page: ${e.toString()}');
    }
  }

  Future<void> _startFunding() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;

    if (amount < CoinService.COIN_VALUE_IN_NAIRA) {
      _showErrorSnackBar(
        'Minimum amount is ₦${CoinService.COIN_VALUE_IN_NAIRA.toStringAsFixed(0)} (1 coin)',
      );
      return;
    }

    final coinAmount = CoinService.coinFromNaira(amount);
    if (coinAmount <= 0) {
      _showErrorSnackBar('Please enter a valid amount greater than 0');
      return;
    }

    setState(() => _isLoading = true);
    _updateStatus('Initializing payment...');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final customerEmail = user.email ?? 'user@nigergram.app';
      final customerName = user.displayName ?? 'NigerGram User';

      _updateStatus('Contacting payment gateway...');

      final init = await _monnify.initTransaction(
        amount: amount,
        customerEmail: customerEmail,
        customerName: customerName,
      );

      final checkoutUrl = init['checkoutUrl'] as String?;
      final paymentReference = init['paymentReference'] as String?;
      final transactionReference = init['transactionReference'] as String?;

      if (checkoutUrl == null ||
          paymentReference == null ||
          transactionReference == null) {
        throw Exception(
          'Invalid response from payment gateway. Missing checkout URL or reference.',
        );
      }

      _updateStatus('Opening payment page...');

      // Launch payment URL with fallback strategies
      await _launchPaymentUrl(checkoutUrl);

      // Start polling with generous timeout (bank transfers can take a few minutes to confirm)
      _updateStatus('Waiting for payment confirmation...');
      final paid = await _pollUntilPaid(
        transactionReference,
        timeout: const Duration(minutes: 5),
      );

      if (paid) {
        _updateStatus('Payment confirmed! Crediting coins...');

        await _walletCubit.fundWallet(
          coinAmount: coinAmount,
          monnifyTransactionReference: transactionReference,
        );

        if (mounted) {
          _showSuccessSnackBar(
            'Wallet funded successfully with $coinAmount coin${coinAmount == 1 ? '' : 's'}!',
          );
          _amountController.clear();
          _updateStatus('');
          // Close the view after short delay
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) Navigator.of(context).pop();
        }
      } else {
        _showErrorSnackBar(
          'Payment verification timeout. Please check your payment status and try again.',
        );
        _updateStatus('');
      }
    } on SocketException catch (e) {
      _showErrorSnackBar('Network error: ${e.message}. Please check your connection.');
      _updateStatus('');
    } on TimeoutException catch (_) {
      _showErrorSnackBar('Request timeout. Please try again.');
      _updateStatus('');
    } catch (e) {
      _showErrorSnackBar('Payment failed: $e');
      _updateStatus('');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _pollUntilPaid(
    String transactionReference, {
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final end = DateTime.now().add(timeout);
    int pollCount = 0;
    const pollInterval = Duration(milliseconds: 2000); // Poll every 2 seconds

    while (DateTime.now().isBefore(end)) {
      try {
        pollCount++;
        _updateStatus(
          'Waiting for payment confirmation... (${pollCount * 2}s)',
        );

        final res = await _monnify.queryTransaction(transactionReference);

        // Monnify returns paymentStatus in the response
        final status = (res['paymentStatus'] as String?) ?? '';
        final transactionStatus = (res['status'] as String?) ?? '';
        final statusUpper = status.toUpperCase();
        final transStatusUpper = transactionStatus.toUpperCase();

        debugPrint(
          '[FundWallet] paymentStatus=$statusUpper status=$transStatusUpper',
        );

        // Check for successful payment statuses
        if (statusUpper == 'PAID' ||
            statusUpper == 'SUCCESS' ||
            transStatusUpper == 'COMPLETED' ||
            transStatusUpper == 'SUCCESSFUL') {
          _updateStatus('Payment confirmed!');
          return true;
        }

        // Check for failed payment statuses
        if (statusUpper.contains('FAILED') ||
            statusUpper.contains('DECLINED') ||
            statusUpper.contains('CANCELLED') ||
            transStatusUpper.contains('FAILED')) {
          throw Exception(
            'Payment was declined or cancelled. Status: $status',
          );
        }

        // Continue polling if pending
        await Future.delayed(pollInterval);
      } on SocketException {
        // Network error - continue polling, we'll timeout if persistent
        await Future.delayed(pollInterval);
      } catch (e) {
        // Log the error but continue trying to verify
        debugPrint('Payment verification error: $e');
        await Future.delayed(pollInterval);
      }
    }

    // Timeout reached without confirmation
    return false;
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter Amount to Fund',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                enabled: !_isLoading,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Amount (₦)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  disabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.greenAccent),
                  ),
                  prefixText: '₦ ',
                  prefixStyle: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _coinsPreview > 0
                    ? 'You will receive $_coinsPreview coin${_coinsPreview == 1 ? '' : 's'}'
                    : 'Minimum ₦${CoinService.COIN_VALUE_IN_NAIRA.toStringAsFixed(0)} = 1 coin',
                style: TextStyle(
                  color: _coinsPreview > 0 ? Colors.greenAccent : Colors.grey[400],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              // Status message display
              if (_statusMessage.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blueAccent),
                  ),
                  child: Column(
                    children: [
                      if (_isLoading)
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.blueAccent,
                            strokeWidth: 2,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              ElevatedButton(
                onPressed: _isLoading ? null : _startFunding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  disabledBackgroundColor: Colors.grey,
                  foregroundColor: Colors.black,
                  disabledForegroundColor: Colors.black54,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Pay via Monnify',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                'You will be redirected to complete payment securely.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
