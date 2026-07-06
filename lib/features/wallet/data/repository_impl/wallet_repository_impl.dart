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
