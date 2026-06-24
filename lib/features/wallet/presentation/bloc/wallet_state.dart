// lib/features/wallet/presentation/bloc/wallet_state.dart
import 'package:nigergram/features/wallet/domain/entities/wallet_entity.dart';
import 'package:nigergram/features/wallet/domain/entities/transaction_entity.dart';

class WalletState {
  final WalletEntity? wallet;
  final List<WalletTransactionEntity> transactions;
  final bool isLoading;
  final String error;

  WalletState({
    this.wallet,
    this.transactions = const [],
    this.isLoading = false,
    this.error = '',
  });

  factory WalletState.initial() {
    return WalletState(
      wallet: null,
      transactions: const [],
      isLoading: false,
      error: '',
    );
  }

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
}
