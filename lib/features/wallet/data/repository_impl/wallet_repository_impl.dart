import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  Future<void> sendTip({
    required String fromUserId,
    required String toUserId,
    required String fromUsername,
    required String toUsername,
    required double amount,
    String? videoId,
    String? message,
  }) async {
    final fromRef = _wallets.doc(fromUserId);
    final toRef = _wallets.doc(toUserId);
    final txRef = _transactions.doc();

    await firestore.runTransaction((transaction) async {
      final fromSnap = await transaction.get(fromRef);
      final toSnap = await transaction.get(toRef);

      final fromBalance = (fromSnap.data()?['balance'] as num?)?.toDouble() ?? 0.0;
      if (fromBalance < amount) {
        throw Exception('Insufficient balance');
      }

      final newFromBalance = fromBalance - amount;
      final toBalance = (toSnap.data()?['balance'] as num?)?.toDouble() ?? 0.0;
      final toTotalEarned = (toSnap.data()?['totalEarned'] as num?)?.toDouble() ?? 0.0;
      final newToBalance = toBalance + amount;
      final newToTotalEarned = toTotalEarned + amount;

      transaction.update(fromRef, {
        'balance': newFromBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!toSnap.exists) {
        transaction.set(toRef, {
          'uid': toUserId,
          'balance': newToBalance,
          'totalEarned': newToTotalEarned,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.update(toRef, {
          'balance': newToBalance,
          'totalEarned': newToTotalEarned,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      transaction.set(txRef, {
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'fromUsername': fromUsername,
        'toUsername': toUsername,
        'amount': amount,
        'type': 'tip',
        'videoId': videoId,
        'message': message,
        'status': 'completed',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> fundWallet({required String userId, required double amount}) async {
    final ref = _wallets.doc(userId);
    await firestore.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      final current = (snap.data()?['balance'] as num?)?.toDouble() ?? 0.0;
      final newBalance = current + amount;
      final totalEarned = (snap.data()?['totalEarned'] as num?)?.toDouble() ?? 0.0;
      transaction.set(ref, {
        'uid': userId,
        'balance': newBalance,
        'totalEarned': totalEarned,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final txRef = _transactions.doc();
      transaction.set(txRef, {
        'fromUserId': userId,
        'toUserId': userId,
        'fromUsername': '',
        'toUsername': '',
        'amount': amount,
        'type': 'fund',
        'videoId': null,
        'message': null,
        'status': 'completed',
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
  }) async {
    final ref = _wallets.doc(userId);
    final txRef = _transactions.doc();

    await firestore.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      final current = (snap.data()?['balance'] as num?)?.toDouble() ?? 0.0;
      if (current < amount) {
        throw Exception('Insufficient balance');
      }
      final newBalance = current - amount;
      transaction.update(ref, {
        'balance': newBalance,
        'bankAccountNumber': bankAccountNumber,
        'bankName': bankName,
        'bankAccountName': bankAccountName,
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
  }) async {
    final ref = _wallets.doc(userId);
    await ref.set({
      'bankAccountNumber': bankAccountNumber,
      'bankName': bankName,
      'bankAccountName': bankAccountName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
