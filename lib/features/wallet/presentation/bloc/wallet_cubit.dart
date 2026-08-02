import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nigergram/core/utils/app_auth.dart';
import 'package:nigergram/features/wallet/data/repository_impl/wallet_repository_impl.dart';
import 'package:nigergram/features/wallet/data/services/ztc_wallet_bridge.dart';
import 'package:nigergram/features/wallet/domain/entities/transaction_entity.dart';
import 'package:nigergram/features/wallet/domain/entities/wallet_entity.dart';
import 'package:nigergram/features/wallet/presentation/bloc/wallet_state.dart';

class WalletCubit extends Cubit<WalletState> {
  final WalletRepositoryImpl repository;
  StreamSubscription<WalletEntity?>? _walletSub;
  StreamSubscription<List<WalletTransactionEntity>>? _txSub;

  WalletCubit({required this.repository}) : super(WalletState.initial()) {
    if (AppAuth.isLoggedIn) {
      watchWallet(AppAuth.uid);
      watchTransactions(AppAuth.uid);
      ZtcWalletBridge.start();
    }
  }

  void watchWallet(String uid) {
    _walletSub?.cancel();
    _walletSub = repository.walletStream(uid).listen((wallet) {
      emit(state.copyWith(wallet: wallet));
    });
  }

  void watchTransactions(String uid) {
    _txSub?.cancel();
    _txSub = repository.transactionsStreamForUser(uid).listen((txs) {
      emit(state.copyWith(transactions: txs));
    });
  }

  Future<void> refresh() async {
    emit(state.copyWith(isLoading: true, error: ''));
    if (!AppAuth.isLoggedIn) {
      emit(state.copyWith(isLoading: false, error: 'Not authenticated'));
      return;
    }
    try {
      final wallet = await repository.fetchWallet(AppAuth.uid);
      final txs = await repository.transactionsStreamForUser(AppAuth.uid).first;
      emit(state.copyWith(wallet: wallet, transactions: txs, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> sendGift({
    required String toUserId,
    required String toUsername,
    required int coinAmount,
    String? videoId,
    String? message,
  }) async {
    try {
      await repository.sendGift(
        fromUserId: AppAuth.uid,
        toUserId: toUserId,
        fromUsername: AppAuth.displayHandle,
        toUsername: toUsername,
        coinAmount: coinAmount,
        videoId: videoId,
        message: message,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Submits a cash-out request for [centAmount] cents. NigerGram
  /// doesn't move real money — the actual payout happens on ZTC, tied
  /// to the user's ZetraID. This just records the request and deducts
  /// the balance.
  Future<void> requestWithdrawal({
    required int centAmount,
  }) async {
    await repository.requestWithdrawal(
      userId: AppAuth.uid,
      centAmount: centAmount,
    );
  }

  Future<void> setPin(String pin) async {
    await repository.setPin(userId: AppAuth.uid, pin: pin);
  }

  Future<bool> verifyPin(String pin) async {
    return repository.verifyPin(userId: AppAuth.uid, pin: pin);
  }

  Future<bool> hasPinSet() async {
    if (!AppAuth.isLoggedIn) return false;
    return repository.hasPinSet(AppAuth.uid);
  }

  @override
  Future<void> close() {
    _walletSub?.cancel();
    _txSub?.cancel();
    ZtcWalletBridge.stop();
    return super.close();
  }
}
