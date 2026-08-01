import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nigergram/core/utils/app_auth.dart';

/// NigerGram no longer processes payments directly. To fund their
/// wallet, a user sends cents (CP) from ZTC to their NigerGram
/// account — identified by their ZetraID.
///
/// Two ways to do that:
/// 1. Open ZTC, tap the NigerGram card on the ZTC dashboard — ZTC
///    already knows to send straight to their NigerGram wallet.
/// 2. Copy the account number below, leave the app, open ZTC
///    manually, and send to that number using ZTC's normal
///    "Send Money" flow.
///
/// Either way, crediting happens on ZTC's side. This screen never
/// polls or waits — the balance updates the moment ZTC credits it,
/// because the wallet screen is already listening to Firestore in
/// real time.
class FundWalletView extends StatelessWidget {
  const FundWalletView({super.key});

  String get _accountNumber => AppAuth.displayHandle;

  void _copyAccountNumber(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _accountNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account number copied'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      appBar: AppBar(
        title: const Text('Fund Wallet', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF0050), Color(0xFF7B0033)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your NigerGram Account Number',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _accountNumber,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: Colors.white),
                        onPressed: () => _copyAccountNumber(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'This is your ZetraID — the same number ZTC uses for your account.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'How to fund your wallet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _stepTile(
              icon: Icons.apps_rounded,
              title: 'Fastest way',
              body: 'Open ZTC, tap the NigerGram card on your dashboard, and send. It goes straight into this wallet.',
            ),
            const SizedBox(height: 12),
            _stepTile(
              icon: Icons.copy_all_rounded,
              title: 'Or send manually',
              body: 'Copy your account number above, open ZTC, use "Send Money," and paste it in as the recipient.',
            ),
            const SizedBox(height: 28),
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
                      'No need to wait here — your balance updates automatically the moment ZTC sends it.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
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

  Widget _stepTile({required IconData icon, required String title, required String body}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF0050).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFFF0050), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
