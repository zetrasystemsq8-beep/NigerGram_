// lib/features/wallet/presentation/view/fund_wallet_chooser_view.dart
//
// Lets the user choose how to fund their wallet:
//   - ZTC transfer (fast, but requires the ZTC app to be installed)
//   - Bank transfer (no extra app — uses the createTopup + reference
//     code flow via BuyCentAmountView / BuyCentPaymentView)
import 'package:flutter/material.dart';

import 'buy_cent_amount_view.dart';
import 'fund_wallet_view.dart';

class FundWalletChooserView extends StatelessWidget {
  const FundWalletChooserView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Fund Wallet',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'How do you want to pay?',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose whichever is easier for you',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
              const SizedBox(height: 28),
              _FundOptionCard(
                icon: Icons.bolt_rounded,
                title: 'Pay via ZTC',
                subtitle: 'Instant — sends straight from your ZTC balance. Requires the ZTC app.',
                badge: 'Fastest',
                badgeColor: const Color(0xFF3DDC84),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FundWalletView()),
                  );
                },
              ),
              const SizedBox(height: 16),
              _FundOptionCard(
                icon: Icons.account_balance_rounded,
                title: 'Bank Transfer',
                subtitle: 'No extra app needed. Pay from any bank app and confirm with a reference code.',
                badge: 'No app needed',
                badgeColor: const Color(0xFFFFD84D),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BuyCentAmountView()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FundOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _FundOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A24),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0050).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFFFF0050), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }
}
