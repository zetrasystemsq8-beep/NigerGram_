// lib/features/wallet/presentation/view/wallet_home_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nigergram/core/di/dependency_injector.dart';
import 'package:nigergram/features/wallet/presentation/bloc/wallet_cubit.dart';
import 'package:nigergram/features/wallet/presentation/bloc/wallet_state.dart';
import 'package:nigergram/features/wallet/presentation/view/withdraw_view.dart';
import 'package:nigergram/features/wallet/presentation/view/fund_wallet_chooser_view.dart';
import 'package:nigergram/features/admin/presentation/view/admin_gate_view.dart';

class WalletHomeView extends StatefulWidget {
  const WalletHomeView({super.key});

  @override
  State<WalletHomeView> createState() => _WalletHomeViewState();
}

class _WalletHomeViewState extends State<WalletHomeView> {
  late final WalletCubit _walletCubit;
  bool _isRefreshing = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _walletCubit = getIt<WalletCubit>();
    _walletCubit.refresh();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    try {
      final result = await Supabase.instance.client.rpc('is_admin');
      if (mounted) setState(() => _isAdmin = result == true);
    } catch (_) {
      // Not an admin, or not logged in — stays false, icon stays hidden.
    }
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    await _walletCubit.refresh();
    setState(() => _isRefreshing = false);
  }

  String _formatCp(int cp) {
    return cp.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  }

  String _formatCent(int cent) {
    return cent.toString().padLeft(3, '0');
  }

  /// Splits a raw cent amount (as stored on transactions) into a
  /// "X CP" / "X CP Y Cent" / "Y Cent" display string, same rule as
  /// the balance card: no Cent segment shown when there's none.
  String _formatCentAmount(int rawCents) {
    final cp = rawCents ~/ 1000;
    final cent = rawCents % 1000;
    if (cp > 0 && cent > 0) return '${_formatCp(cp)} CP ${_formatCent(cent)} Cent';
    if (cp > 0) return '${_formatCp(cp)} CP';
    return '$cent Cent';
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Wallet',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_rounded),
              color: Colors.white,
              tooltip: 'Admin',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminGateView()),
                );
              },
            ),
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF0050),
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: _isRefreshing ? null : _refresh,
            color: Colors.white,
          ),
        ],
      ),
      body: BlocBuilder<WalletCubit, WalletState>(
        bloc: _walletCubit,
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF0050),
              ),
            );
          }

          if (state.error.isNotEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade400,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.error,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _walletCubit.refresh(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF0050),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          }

          final wallet = state.wallet;
          final transactions = state.transactions;
          final coinBalance = wallet?.coinBalance ?? 0;
          final centBalance = wallet?.centBalance ?? 0;
          final canWithdraw = (wallet?.balanceCents ?? 0) > 0;

          return RefreshIndicator(
            color: const Color(0xFFFF0050),
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Balance Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF0050), Color(0xFF7B0033)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF0050).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Balance',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_formatCp(coinBalance)} CP',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (centBalance > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '+ ${_formatCent(centBalance)} Cent',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  // OPEN the wallet-funding chooser (ZTC or Bank Transfer)
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const FundWalletChooserView(),
                                    ),
                                  ).then((_) => _walletCubit.refresh());
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFFFF0050),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Fund Wallet',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  if (!canWithdraw) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Insufficient balance to withdraw'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const WithdrawView(),
                                    ),
                                  ).then((_) => _walletCubit.refresh());
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Withdraw',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Transaction History Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Transaction History',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (transactions.isNotEmpty)
                        Text(
                          '${transactions.length}',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Transactions List
                  if (transactions.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Colors.grey.shade700,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No transactions yet',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fund your wallet to get started',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: transactions.length > 30 ? 30 : transactions.length,
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
                        final isCredit = tx.type == 'gift_received' ||
                            tx.type == 'purchase' ||
                            tx.type == 'deposit';
                        final coinAmount = tx.coinAmount;

                        final transactionName = _getTransactionName(tx.type);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A24),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isCredit
                                      ? Colors.green.withOpacity(0.15)
                                      : Colors.red.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isCredit
                                      ? Icons.arrow_downward_rounded
                                      : Icons.arrow_upward_rounded,
                                  color: isCredit ? Colors.green : Colors.red,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      transactionName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatDate(tx.timestamp),
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${isCredit ? '+' : '-'}${_formatCentAmount(coinAmount)}',
                                style: TextStyle(
                                  color: isCredit ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getTransactionName(String type) {
    switch (type) {
      case 'gift_sent':
        return 'Gift Sent';
      case 'gift_received':
        return 'Gift Received';
      case 'purchase':
        return 'Wallet Funding';
      case 'deposit':
        return 'Wallet Funding';
      case 'withdrawal':
        return 'Withdrawal';
      default:
        return 'Transaction';
    }
  }
}
