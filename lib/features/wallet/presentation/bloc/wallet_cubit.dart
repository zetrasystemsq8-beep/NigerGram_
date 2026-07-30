import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nigergram/core/utils/app_auth.dart';
import 'package:nigergram/features/wallet/data/repository_impl/wallet_repository_impl.dart';
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

  Future<void> fundWallet({
    required int coinAmount,
    required String monnifyTransactionReference,
  }) async {
    await repository.fundWallet(
      userId: AppAuth.uid,
      coinAmount: coinAmount,
      monnifyTransactionReference: monnifyTransactionReference,
    );
  }

  Future<void> requestWithdrawal({
    required double amount,
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountName,
    required String bankCode,
  }) async {
    await repository.requestWithdrawal(
      userId: AppAuth.uid,
      amount: amount,
      bankName: bankName,
      bankAccountNumber: bankAccountNumber,
      bankAccountName: bankAccountName,
      bankCode: bankCode,
    );
  }

  Future<void> saveBankInfo({
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountName,
    required String bankCode,
  }) async {
    await repository.saveBankInfo(
      userId: AppAuth.uid,
      bankName: bankName,
      bankAccountNumber: bankAccountNumber,
      bankAccountName: bankAccountName,
      bankCode: bankCode,
    );
  }

  @override
  Future<void> close() {
    _walletSub?.cancel();
    _txSub?.cancel();
    return super.close();
  }
}
