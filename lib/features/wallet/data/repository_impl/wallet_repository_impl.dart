import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:nigergram/features/wallet/domain/entities/transaction_entity.dart';
import 'package:nigergram/features/wallet/domain/entities/wallet_entity.dart';
import 'package:nigergram/features/wallet/domain/repositories/wallet_repository.dart';

class WalletRepositoryImpl implements WalletRepository {
  final FirebaseFirestore firestore;

  WalletRepositoryImpl({required this.firestore});

  CollectionReference get _wallets => firestore.collection('wallets');
  CollectionReference get _transactions => firestore.collection('wallet_transactions');

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

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
        throw Exception('Insufficient cent balance');
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

  /// Cash-out request. NigerGram never moves real money — this simply
  /// records the request and deducts the cent balance. The user's ZTC
  /// account (their ZetraID) is what actually gets credited, handled
  /// entirely on ZTC's side.
  @override
  Future<void> requestWithdrawal({
    required String userId,
    required int centAmount,
  }) async {
    final ref = _wallets.doc(userId);
    final txRef = _transactions.doc();

    await firestore.runTransaction((transaction) async {
      final snap = await transaction.get(ref);

      final snapData = snap.data() as Map<String, dynamic>?;
      final current = (snapData?['coinBalance'] as num?)?.toInt() ?? 0;

      if (current < centAmount) {
        throw Exception('Insufficient cent balance');
      }
      final newBalance = current - centAmount;
      transaction.update(ref, {
        'coinBalance': newBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(txRef, {
        'fromUserId': userId,
        'toUserId': userId,
        'fromUsername': '',
        'toUsername': '',
        'coinAmount': centAmount,
        'type': 'withdrawal',
        'videoId': null,
        'message': null,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> setPin({
    required String userId,
    required String pin,
  }) async {
    final ref = _wallets.doc(userId);
    await ref.set({
      'pinHash': _hashPin(pin),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<bool> verifyPin({
    required String userId,
    required String pin,
  }) async {
    final doc = await _wallets.doc(userId).get();
    final data = doc.data() as Map<String, dynamic>?;
    final storedHash = data?['pinHash'] as String?;
    if (storedHash == null) return false;
    return storedHash == _hashPin(pin);
  }

  @override
  Future<bool> hasPinSet(String userId) async {
    final doc = await _wallets.doc(userId).get();
    final data = doc.data() as Map<String, dynamic>?;
    return (data?['pinHash'] as String?) != null;
  }
}
