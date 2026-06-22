import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/di/dependency_injector.dart';
import 'package:nigergram/features/wallet/presentation/bloc/wallet_cubit.dart';
import 'package:nigergram/features/wallet/presentation/bloc/wallet_state.dart';
import 'package:nigergram/features/wallet/presentation/widgets/transaction_list_item.dart';
import 'package:go_router/go_router.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';

class WalletHomeView extends StatelessWidget {
  const WalletHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WalletCubit>(
      create: (_) => getIt<WalletCubit>(),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Wallet'),
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        body: BlocBuilder<WalletCubit, WalletState>(
          builder: (context, state) {
            final balance = state.wallet?.balance ?? 0.0;
            final balanceText = '₦${balance.toStringAsFixed(0)}';
            return RefreshIndicator(
              onRefresh: () async {
                await context.read<WalletCubit>().refresh();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: context.paddingAll(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: context.paddingAll(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900.withOpacity(0.6),
                          borderRadius: context.radiusAll(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Balance',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: context.fontSize(12),
                                  ),
                                ),
                                SizedBox(height: context.h(8)),
                                Text(
                                  balanceText,
                                  style: TextStyle(
                                    color: red,
                                    fontSize: context.fontSize(28),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    context.push('/wallet/fund');
                                  },
                                  child: Container(
                                    padding: context.paddingAll(12),
                                    decoration: BoxDecoration(
                                      color: red,
                                      borderRadius: context.radiusAll(8),
                                    ),
                                    child: Text(
                                      'Fund Wallet',
                                      style: TextStyle(color: Colors.white, fontSize: context.fontSize(13)),
                                    ),
                                  ),
                                ),
                                SizedBox(width: context.w(12)),
                                GestureDetector(
                                  onTap: () {
                                    context.push('/wallet/withdraw');
                                  },
                                  child: Container(
                                    padding: context.paddingAll(12),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: context.radiusAll(8),
                                      border: Border.all(color: Colors.grey.shade800),
                                    ),
                                    child: Text(
                                      'Withdraw',
                                      style: TextStyle(color: Colors.white, fontSize: context.fontSize(13)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: context.h(16)),
                      Text('Transactions', style: TextStyle(color: Colors.white70, fontSize: context.fontSize(14))),
                      SizedBox(height: context.h(12)),
                      if (state.transactions.isEmpty)
                        Center(
                          child: Padding(
                            padding: context.paddingAll(24),
                            child: Text('No transactions yet', style: TextStyle(color: Colors.white30)),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: state.transactions.length,
                          itemBuilder: (context, index) {
                            final tx = state.transactions[index];
                            return TransactionListItem(transaction: tx);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
