import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nigergram/features/wallet/presentation/bloc/wallet_cubit.dart';
import 'package:nigergram/features/wallet/presentation/bloc/wallet_state.dart';

class CreatorEarningsView extends StatelessWidget {
  const CreatorEarningsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: context.read<WalletCubit>(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Earnings')),
        body: BlocBuilder<WalletCubit, WalletState>(
          builder: (context, state) {
            final total = state.wallet?.totalEarned ?? 0.0;
            final txs = state.transactions;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total earned: ₦${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('Recent transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: txs.isEmpty
                        ? const Center(child: Text('No earnings yet'))
                        : ListView.builder(
                            itemCount: txs.length,
                            itemBuilder: (c, i) => ListTile(
                              title: Text(txs[i].type),
                              subtitle: Text(txs[i].toUsername ?? ''),
                              trailing: Text('₦${txs[i].amount.toStringAsFixed(0)}'),
                            ),
                          ),
                  )
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
