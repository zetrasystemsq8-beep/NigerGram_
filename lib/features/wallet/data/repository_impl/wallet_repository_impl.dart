import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:nigergram/features/wallet/domain/entities/transaction_entity.dart';
import 'package:nigergram/features/wallet/domain/entities/wallet_entity.dart';
import 'package:nigergram/features/wallet/domain/repositories/wallet_repository.dart';

class WalletRepositoryImpl implements WalletRepository {
  final FirebaseFirestore firestore;

  WalletRepositoryImpl({required this.firestore});

  CollectionReference get _wallets => firestore.collection('wallets');
  CollectionReference get _transactions => firestore.collection('wallet_transactions');

  @override
  Stream<WalletEntity?> walletStream(String uid) {
    return _wallets.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return WalletEntity.fromFirestore(snap);
    });
  }

  @override
  Future<WalletEntity?> fetchWallet(String uid) async {
    final doc = await _wallets.doc(uid).get();
    if (!doc.exists) return null;
    return WalletEntity.fromFirestore(doc);
  }

  @override
  Stream<List<WalletTransactionEntity>> transactionsStreamForUser(String uid) {
    final fromQuery = _transactions.where('fromUserId', isEqualTo: uid).orderBy('timestamp', descending: true).limit(100);
    final toQuery = _transactions.where('toUserId', isEqualTo: uid).orderBy('timestamp', descending: true).limit(100);

    final fromStream = fromQuery.snapshots();

    return fromStream.asyncMap((fromSnap) async {
      final toSnap = await toQuery.get();
      final combined = <WalletTransactionEntity>[];
      combined.addAll(fromSnap.docs.map((d) => WalletTransactionEntity.fromFirestore(d)));
      combined.addAll(toSnap.docs.map((d) => WalletTransactionEntity.fromFirestore(d)));
      combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return combined;
    }).asBroadcastStream();
  }

  @override
  Future<void> sendGift({
    required String fromUserId,
    required String toUserId,
    required String fromUsername,
    required String toUsername,
    required int coinAmount,
    String? videoId,
    String? message,
  }) async {
    final fromRef = _wallets.doc(fromUserId);
    final toRef = _wallets.doc(toUserId);
    final txRef = _transactions.doc();

    await firestore.runTransaction((transaction) async {
      final fromSnap = await transaction.get(fromRef);
      final toSnap = await transaction.get(toRef);

      final fromData = fromSnap.data() as Map<String, dynamic>?;
      final fromBalance = (fromData?['coinBalance'] as num?)?.toInt() ?? 0;
      if (fromBalance < coinAmount) {
        throw Exception('Insufficient coin balance');
      }

      final newFromBalance = fromBalance - coinAmount;

      final toData = toSnap.data() as Map<String, dynamic>?;
      final toBalance = (toData?['coinBalance'] as num?)?.toInt() ?? 0;
      final newToBalance = toBalance + coinAmount;

      transaction.update(fromRef, {
        'coinBalance': newFromBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!toSnap.exists) {
        transaction.set(toRef, {
          'userId': toUserId,
          'coinBalance': newToBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.update(toRef, {
          'coinBalance': newToBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      transaction.set(txRef, {
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'fromUsername': fromUsername,
        'toUsername': toUsername,
        'coinAmount': coinAmount,
        'type': 'gift',
        'videoId': videoId,
        'message': message,
        'status': 'completed',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> fundWallet({
    required String userId,
    required int coinAmount,
    required String monnifyTransactionReference,
  }) async {
    final ref = _wallets.doc(userId);

    // Idempotency: if we've already recorded a purchase with this monnifyTransactionReference, skip.
    final existing = await _transactions
        .where('monnifyTransactionReference', isEqualTo: monnifyTransactionReference)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      debugPrint('[WalletRepository] fundWallet skipped - existing transaction for monnifyTransactionReference=$monnifyTransactionReference');
      return;
    }

    await firestore.runTransaction((transaction) async {
      final snap = await transaction.get(ref);

      final snapData = snap.data() as Map<String, dynamic>?;
      final current = (snapData?['coinBalance'] as num?)?.toInt() ?? 0;
      final newBalance = current + coinAmount;

      transaction.set(
        ref,
        {
          'userId': userId,
          'coinBalance': newBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final txRef = _transactions.doc();
      transaction.set(txRef, {
        'fromUserId': userId,
        'toUserId': userId,
        'fromUsername': '',
        'toUsername': '',
        'coinAmount': coinAmount,
        'type': 'purchase',
        'status': 'completed',
        'monnifyTransactionReference': monnifyTransactionReference,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> requestWithdrawal({
    required String userId,
    required double amount,
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountName,
    required String bankCode,
  }) async {
    final ref = _wallets.doc(userId);
    final txRef = _transactions.doc();

    await firestore.runTransaction((transaction) async {
      final snap = await transaction.get(ref);

      final snapData = snap.data() as Map<String, dynamic>?;
      final current = (snapData?['balance'] as num?)?.toDouble() ?? 0.0;

      if (current < amount) {
        throw Exception('Insufficient balance');
      }
      final newBalance = current - amount;
      transaction.update(ref, {
        'balance': newBalance,
        'bankAccountNumber': bankAccountNumber,
        'bankName': bankName,
        'bankAccountName': bankAccountName,
        'bankCode': bankCode,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(txRef, {
        'fromUserId': userId,
        'toUserId': userId,
        'fromUsername': '',
        'toUsername': '',
        'amount': amount,
        'type': 'withdrawal',
        'videoId': null,
        'message': null,
        'status': 'pending',
        'bankCode': bankCode,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> saveBankInfo({
    required String userId,
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountName,
    required String bankCode,
  }) async {
    final ref = _wallets.doc(userId);
    await ref.set({
      'bankAccountNumber': bankAccountNumber,
      'bankName': bankName,
      'bankAccountName': bankAccountName,
      'bankCode': bankCode,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
