import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nigergram/features/wallet/data/repository_impl/wallet_repository_impl.dart';
import 'package:nigergram/features/wallet/domain/entities/transaction_entity.dart';
import 'package:nigergram/features/wallet/domain/entities/wallet_entity.dart';
import 'package:nigergram/features/wallet/presentation/bloc/wallet_state.dart';

class WalletCubit extends Cubit<WalletState> {
  final WalletRepositoryImpl repository;
  StreamSubscription<WalletEntity?>? _walletSub;
  StreamSubscription<List<WalletTransactionEntity>>? _txSub;

  WalletCubit({required this.repository}) : super(WalletState.initial()) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      watchWallet(user.uid);
      watchTransactions(user.uid);
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      emit(state.copyWith(isLoading: false, error: 'Not authenticated'));
      return;
    }
    try {
      final wallet = await repository.fetchWallet(user.uid);
      final txs = await repository.transactionsStreamForUser(user.uid).first;
      emit(state.copyWith(wallet: wallet, transactions: txs, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> sendTip({
    required String toUserId,
    required String toUsername,
    required double amount,
    String? videoId,
    String? message,
  }) async {
    final user = FirebaseAuth.instance.currentUser!;
    try {
      await repository.sendTip(
        fromUserId: user.uid,
        toUserId: toUserId,
        fromUsername: user.displayName ?? user.email?.split('@').first ?? 'user',
        toUsername: toUsername,
        amount: amount,
        videoId: videoId,
        message: message,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> fundWallet({required double amount}) async {
    final user = FirebaseAuth.instance.currentUser!;
    await repository.fundWallet(userId: user.uid, amount: amount);
  }

  Future<void> requestWithdrawal({
    required double amount,
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountName,
  }) async {
    final user = FirebaseAuth.instance.currentUser!;
    await repository.requestWithdrawal(
      userId: user.uid,
      amount: amount,
      bankName: bankName,
      bankAccountNumber: bankAccountNumber,
      bankAccountName: bankAccountName,
    );
  }

  Future<void> saveBankInfo({
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountName,
  }) async {
    final user = FirebaseAuth.instance.currentUser!;
    await repository.saveBankInfo(
      userId: user.uid,
      bankName: bankName,
      bankAccountNumber: bankAccountNumber,
      bankAccountName: bankAccountName,
    );
  }

  @override
  Future<void> close() {
    _walletSub?.cancel();
    _txSub?.cancel();
    return super.close();
  }
}
