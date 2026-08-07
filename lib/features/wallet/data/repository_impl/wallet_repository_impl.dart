import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nigergram/features/wallet/domain/entities/transaction_entity.dart';
import 'package:nigergram/features/wallet/domain/entities/wallet_entity.dart';
import 'package:nigergram/features/wallet/domain/repositories/wallet_repository.dart';

class WalletRepositoryImpl implements WalletRepository {
  final FirebaseFirestore firestore;

  WalletRepositoryImpl({required this.firestore});

  static const String _ztcAppId = 'nigergram';

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

  /// Withdrawal. Calls ZTC's cash_out_app_currency RPC, which debits
  /// NigerGram's app_currency_balances AND credits the real CP wallet
  /// on ZTC's side (both `balance` and `balance_cents`) in the same DB
  /// transaction — a genuine, immediate transfer, not just a note in
  /// NigerGram's own database. CP and Cent are the same currency at two
  /// denominations (1 CP = 1000 Cent), so this moves value back to ZTC
  /// regardless of which unit the user thinks in.
  /// cash_out_app_currency acts on the currently authenticated user,
  /// so [userId] is only used for the Firestore side (optimistic
  /// balance + transaction log) — the actual debit/credit always
  /// happens against whoever is signed in.
  @override
  Future<void> requestWithdrawal({
    required String userId,
    required int centAmount,
  }) async {
    final Map<String, dynamic> result;
    try {
      final response = await Supabase.instance.client.rpc(
        'cash_out_app_currency',
        params: {
          'p_app_id': _ztcAppId,
          'p_amount': centAmount,
        },
      );
      result = response is Map<String, dynamic> ? response : {};
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }

    if (result['success'] != true) {
      throw Exception(result['error']?.toString() ?? 'Withdrawal failed');
    }

    final ref = _wallets.doc(userId);
    final txRef = _transactions.doc();

    // Optimistic local update — ZtcWalletBridge will overwrite this
    // with the authoritative value once the realtime update arrives,
    // so this is just for a snappy UI, not a source of truth.
    await firestore.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      final snapData = snap.data() as Map<String, dynamic>?;
      final current = (snapData?['coinBalance'] as num?)?.toInt() ?? 0;
      final newBalance = (current - centAmount).clamp(0, current);

      transaction.set(ref, {
        'coinBalance': newBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(txRef, {
        'fromUserId': userId,
        'toUserId': userId,
        'fromUsername': '',
        'toUsername': '',
        'coinAmount': centAmount,
        'type': 'withdrawal',
        'videoId': null,
        'message': null,
        'status': 'completed',
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
