import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nigergram/core/services/coin_service.dart';
import 'package:nigergram/features/wallet/domain/entities/transaction_entity.dart';
import 'package:nigergram/features/wallet/domain/entities/wallet_entity.dart';
import 'package:nigergram/features/wallet/domain/repositories/wallet_repository.dart';

class WalletRepositoryImpl implements WalletRepository {
  final FirebaseFirestore firestore;

  WalletRepositoryImpl({required this.firestore});

  CollectionReference get _wallets => firestore.collection('wallets');
  CollectionReference get _transactions => firestore.collection('wallet_transactions');
  CollectionReference get _users => firestore.collection('users');
  CollectionReference get _withdrawalRequests => firestore.collection('withdrawal_requests');

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
    final fromQuery = _transactions
        .where('fromUserId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(100);
    final toQuery = _transactions
        .where('toUserId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(100);

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
    final giftId = firestore.collection('_').doc().id;

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

      final txRef1 = _transactions.doc();
      transaction.set(txRef1, {
        'fromUserId': fromUserId,
        'toUserId': fromUserId,
        'fromUsername': fromUsername,
        'toUsername': fromUsername,
        'coinAmount': coinAmount,
        'type': 'gift_sent',
        'videoId': videoId,
        'message': message,
        'status': 'completed',
        'giftId': giftId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      final txRef2 = _transactions.doc();
      transaction.set(txRef2, {
        'fromUserId': toUserId,
        'toUserId': toUserId,
        'fromUsername': toUsername,
        'toUsername': toUsername,
        'coinAmount': coinAmount,
        'type': 'gift_received',
        'videoId': videoId,
        'message': message,
        'status': 'completed',
        'giftId': giftId,
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
    required int coinAmount,
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountName,
  }) async {
    final userDoc = await _users.doc(userId).get();
    final userData = userDoc.data() as Map<String, dynamic>?;
    final isCreator = (userData?['isCreator'] as bool?) ?? false;

    if (!isCreator) {
      throw Exception('Only creators can request withdrawals');
    }

    if (coinAmount < CoinService.MIN_WITHDRAWAL_COINS) {
      throw Exception('Minimum withdrawal is ${CoinService.MIN_WITHDRAWAL_COINS} coins');
    }

    final today = DateTime.now();
    if (today.day != 1) {
      throw Exception('Withdrawals can only be requested on the 1st of the month');
    }

    final monthStart = DateTime(today.year, today.month, 1);
    final monthEnd = today.month == 12
        ? DateTime(today.year + 1, 1, 1)
        : DateTime(today.year, today.month + 1, 1);

    final existingPending = await _withdrawalRequests
        .where('creatorId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existingPending.docs.isNotEmpty) {
      throw Exception('You already have a pending withdrawal request');
    }

    final thisMonthWithdrawals = await _withdrawalRequests
        .where('creatorId', isEqualTo: userId)
        .where('requestedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .where('requestedAt', isLessThan: Timestamp.fromDate(monthEnd))
        .where('status', whereIn: ['pending', 'completed']).get();

    int totalWithdrawnThisMonth = 0;
    for (final doc in thisMonthWithdrawals.docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalWithdrawnThisMonth += (data['coinAmount'] as num?)?.toInt() ?? 0;
    }

    if (totalWithdrawnThisMonth + coinAmount > CoinService.MAX_MONTHLY_WITHDRAWAL_COINS) {
      final remaining = CoinService.MAX_MONTHLY_WITHDRAWAL_COINS - totalWithdrawnThisMonth;
      throw Exception('Monthly limit exceeded. You can withdraw $remaining more coins this month');
    }

    final nairaValue = coinAmount * CoinService.COIN_VALUE_IN_NAIRA;
    final payout = CoinService.calculateCreatorPayout(coinAmount);

    final walletRef = _wallets.doc(userId);

    await firestore.runTransaction((transaction) async {
      final snap = await transaction.get(walletRef);
      final snapData = snap.data() as Map<String, dynamic>?;
      final current = (snapData?['coinBalance'] as num?)?.toInt() ?? 0;

      if (current < coinAmount) {
        throw Exception('Insufficient coin balance');
      }

      final newBalance = current - coinAmount;
      transaction.update(walletRef, {
        'coinBalance': newBalance,
        'bankAccountNumber': bankAccountNumber,
        'bankName': bankName,
        'bankAccountName': bankAccountName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final requestRef = _withdrawalRequests.doc();
      transaction.set(requestRef, {
        'creatorId': userId,
        'coinAmount': coinAmount,
        'nairaValue': nairaValue,
        'payout': payout,
        'bankName': bankName,
        'bankAccountNumber': bankAccountNumber,
        'bankAccountName': bankAccountName,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      final txRef = _transactions.doc();
      transaction.set(txRef, {
        'fromUserId': userId,
        'toUserId': userId,
        'fromUsername': '',
        'toUsername': '',
        'coinAmount': coinAmount,
        'type': 'withdrawal',
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
    await ref.set(
      {
        'bankAccountNumber': bankAccountNumber,
        'bankName': bankName,
        'bankAccountName': bankAccountName,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
