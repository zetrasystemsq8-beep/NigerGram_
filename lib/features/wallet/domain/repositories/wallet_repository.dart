abstract class WalletRepository {
  Stream walletStream(String uid);
  Future fetchWallet(String uid);
  Stream transactionsStreamForUser(String uid);

  Future sendGift({
    required String fromUserId,
    required String toUserId,
    required String fromUsername,
    required String toUsername,
    required int coinAmount,
    String? videoId,
    String? message,
  });

  /// Creates a cash-out request. NigerGram does not move real money —
  /// this just records the request and deducts the cent balance. The
  /// actual payout happens on ZTC, tied to the user's ZetraID.
  Future requestWithdrawal({
    required String userId,
    required int centAmount,
  });

  /// Sets (or updates) the user's wallet PIN. Stored as a hash, never
  /// in plain text.
  Future setPin({
    required String userId,
    required String pin,
  });

  /// Verifies a PIN attempt against the stored hash. Returns true if
  /// it matches, false otherwise (including if no PIN has been set).
  Future<bool> verifyPin({
    required String userId,
    required String pin,
  });

  /// Whether this user has already set a wallet PIN.
  Future<bool> hasPinSet(String userId);
}
