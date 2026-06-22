import 'package:equatable/equatable.dart';
import 'package:nigergram/features/wallet/domain/entities/transaction_entity.dart';
import 'package:nigergram/features/wallet/domain/entities/wallet_entity.dart';

class WalletState extends Equatable {
  final WalletEntity? wallet;
  final List<WalletTransactionEntity> transactions;
  final bool isLoading;
  final String error;

  const WalletState({
    this.wallet,
    this.transactions = const [],
    this.isLoading = false,
    this.error = '',
  });

  factory WalletState.initial() => const WalletState();

  WalletState copyWith({
    WalletEntity? wallet,
    List<WalletTransactionEntity>? transactions,
    bool? isLoading,
    String? error,
  }) {
    return WalletState(
      wallet: wallet ?? this.wallet,
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [wallet, transactions, isLoading, error];
}
