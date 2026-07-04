import 'dart:async';
import 'dart:io';
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
  String _statusMessage = '';
  final MonnifyService _monnify = getIt<MonnifyService>();
  final _walletCubit = getIt<WalletCubit>();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
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
      debugPrint('[Monnify Debug] UI EVENT: Launching payment URL: $checkoutUrl');
      
      // First try: externalApplication mode (opens in external browser)
      debugPrint('[Monnify Debug] UI EVENT: Attempting to launch URL in external application');
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (launched) {
        debugPrint('[Monnify Debug] UI EVENT: Browser launched successfully (externalApplication)');
        _updateStatus('Payment page opened in browser...');
        return;
      }

      // Second try: platformDefault mode (system default behavior)
      debugPrint('[Monnify Debug] UI EVENT: External app launch failed, trying platformDefault mode');
      launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );

      if (launched) {
        debugPrint('[Monnify Debug] UI EVENT: Browser launched successfully (platformDefault)');
        _updateStatus('Payment page opened...');
        return;
      }

      // If both fail, throw exception with helpful message
      debugPrint('[Monnify Debug] UI EVENT: Both launch modes failed');
      throw Exception(
        'Could not launch payment URL. Please ensure your device has a web browser installed.',
      );
    } catch (e) {
      debugPrint('[Monnify Debug] UI EVENT: URL launch error: $e');
      throw Exception('Failed to open payment page: ${e.toString()}');
    }
  }

  Future<void> _startFunding() async {
    debugPrint('[Monnify Debug] ============ UI EVENT: USER PRESSED PAY VIA MONNIFY ============');
    
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      debugPrint('[Monnify Debug] UI EVENT: Invalid amount: $amount');
      _showErrorSnackBar('Please enter a valid amount greater than 0');
      return;
    }

    debugPrint('[Monnify Debug] UI EVENT: Amount entered: $amount');

    setState(() => _isLoading = true);
    _updateStatus('Initializing payment...');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[Monnify Debug] UI EVENT: User not authenticated');
        throw Exception('User not authenticated');
      }

      final customerEmail = user.email ?? 'user@nigergram.app';
      final customerName = user.displayName ?? 'NigerGram User';

      debugPrint('[Monnify Debug] UI EVENT: User authenticated: $customerEmail');

      _updateStatus('Contacting payment gateway...');

      debugPrint('[Monnify Debug] UI EVENT: Calling initTransaction()');
      final init = await _monnify.initTransaction(
        amount: amount,
        customerEmail: customerEmail,
        customerName: customerName,
      );

      final checkoutUrl = init['checkoutUrl'] as String?;
      final paymentReference = init['paymentReference'] as String?;
      final transactionReference = init['transactionReference'] as String?;

      debugPrint('[Monnify Debug] UI EVENT: Init transaction returned');
      debugPrint('[Monnify Debug] UI EVENT: checkoutUrl: $checkoutUrl');
      debugPrint('[Monnify Debug] UI EVENT: paymentReference: $paymentReference');
      debugPrint('[Monnify Debug] UI EVENT: transactionReference: $transactionReference');

      if (checkoutUrl == null ||
          paymentReference == null ||
          transactionReference == null) {
        debugPrint('[Monnify Debug] UI EVENT: Missing required fields from init response');
        throw Exception(
          'Invalid response from payment gateway. Missing checkout URL or reference.',
        );
      }

      _updateStatus('Opening payment page...');

      // Launch payment URL with fallback strategies
      await _launchPaymentUrl(checkoutUrl);

      // Start polling with 35 second timeout (generous time for user to complete payment)
      _updateStatus('Waiting for payment confirmation...');
      debugPrint('[Monnify Debug] UI EVENT: Starting polling');
      final paid = await _pollUntilPaid(
        transactionReference,
        timeout: const Duration(seconds: 35),
      );

      debugPrint('[Monnify Debug] UI EVENT: Polling finished, paid: $paid');

      if (paid) {
        debugPrint('[Monnify Debug] UI EVENT: Payment confirmed');
        _updateStatus('Payment confirmed! Crediting wallet...');
        await _walletCubit.fundWallet(amount: amount);

        if (mounted) {
          debugPrint('[Monnify Debug] UI EVENT: Wallet funded successfully');
          _showSuccessSnackBar('Wallet funded successfully with ₦${amount.toStringAsFixed(2)}');
          _amountController.clear();
          _updateStatus('');
          // Close the view after short delay
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) Navigator.of(context).pop();
        }
      } else {
        debugPrint('[Monnify Debug] UI EVENT: Payment verification timeout');
        _showErrorSnackBar(
          'Payment verification timeout. Please check your payment status and try again.',
        );
        _updateStatus('');
      }
    } on SocketException catch (e) {
      debugPrint('[Monnify Debug] UI EVENT: SocketException: ${e.message}');
      _showErrorSnackBar('Network error: ${e.message}. Please check your connection.');
      _updateStatus('');
    } on TimeoutException catch (_) {
      debugPrint('[Monnify Debug] UI EVENT: TimeoutException');
      _showErrorSnackBar('Request timeout. Please try again.');
      _updateStatus('');
    } catch (e) {
      debugPrint('[Monnify Debug] UI EVENT: Exception: $e');
      debugPrint('[Monnify Debug] UI EVENT: Stack trace: ${StackTrace.current}');
      _showErrorSnackBar('Payment failed: $e');
      _updateStatus('');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _pollUntilPaid(
    String transactionReference, {
    Duration timeout = const Duration(seconds: 35),
  }) async {
    final end = DateTime.now().add(timeout);
    int pollCount = 0;
    const pollInterval = Duration(milliseconds: 2000); // Poll every 2 seconds

    debugPrint('[Monnify Debug] ============ POLLING START ============');
    debugPrint('[Monnify Debug] Polling timeout: ${timeout.inSeconds}s');
    debugPrint('[Monnify Debug] Polling interval: ${pollInterval.inMilliseconds}ms');
    debugPrint('[Monnify Debug] Polling transactionReference: $transactionReference');

    while (DateTime.now().isBefore(end)) {
      try {
        pollCount++;
        final elapsedSeconds = pollCount * 2;
        debugPrint('[Monnify Debug] ---- POLL #$pollCount (${elapsedSeconds}s) ----');
        
        _updateStatus(
          'Waiting for payment confirmation... (${pollCount * 2}s)',
        );

        debugPrint('[Monnify Debug] Poll #$pollCount: Calling queryTransaction()');
        final res = await _monnify.queryTransaction(transactionReference);

        debugPrint('[Monnify Debug] Poll #$pollCount: Query returned');
        debugPrint('[Monnify Debug] Poll #$pollCount: Response keys: ${res.keys.toList()}');

        // Monnify returns paymentStatus in the response
        final status = (res['paymentStatus'] as String?) ?? '';
        final transactionStatus = (res['status'] as String?) ?? '';
        final statusUpper = status.toUpperCase();
        final transStatusUpper = transactionStatus.toUpperCase();

        debugPrint('[Monnify Debug] Poll #$pollCount: paymentStatus: $status');
        debugPrint('[Monnify Debug] Poll #$pollCount: status: $transactionStatus');
        debugPrint('[Monnify Debug] Poll #$pollCount: Full response: ${res.toString()}');

        // Check for successful payment statuses
        if (statusUpper == 'PAID' ||
            statusUpper == 'SUCCESS' ||
            transStatusUpper == 'COMPLETED' ||
            transStatusUpper == 'SUCCESSFUL') {
          debugPrint('[Monnify Debug] Poll #$pollCount: PAYMENT CONFIRMED - Status: $statusUpper / $transStatusUpper');
          _updateStatus('Payment confirmed!');
          debugPrint('[Monnify Debug] ============ POLLING END (SUCCESS) ============');
          return true;
        }

        // Check for failed payment statuses
        if (statusUpper.contains('FAILED') ||
            statusUpper.contains('DECLINED') ||
            statusUpper.contains('CANCELLED') ||
            transStatusUpper.contains('FAILED')) {
          debugPrint('[Monnify Debug] Poll #$pollCount: PAYMENT FAILED - Status: $statusUpper / $transStatusUpper');
          throw Exception(
            'Payment was declined or cancelled. Status: $status',
          );
        }

        debugPrint('[Monnify Debug] Poll #$pollCount: Payment pending, continuing polling');
        
        // Continue polling if pending
        await Future.delayed(pollInterval);
      } on SocketException catch (e) {
        debugPrint('[Monnify Debug] Poll #$pollCount: SocketException: ${e.message}');
        debugPrint('[Monnify Debug] Poll #$pollCount: Network error - continuing polling');
        // Network error - continue polling, we'll timeout if persistent
        await Future.delayed(pollInterval);
      } catch (e) {
        // Log the error but continue trying to verify
        debugPrint('[Monnify Debug] Poll #$pollCount: Exception: $e');
        debugPrint('[Monnify Debug] Poll #$pollCount: Stack trace: ${StackTrace.current}');
        debugPrint('[Monnify Debug] Poll #$pollCount: Continuing despite error');
        await Future.delayed(pollInterval);
      }
    }

    // Timeout reached without confirmation
    debugPrint('[Monnify Debug] Polling TIMEOUT REACHED after ${pollCount * 2}s with $pollCount polls');
    debugPrint('[Monnify Debug] ============ POLLING END (TIMEOUT) ============');
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
