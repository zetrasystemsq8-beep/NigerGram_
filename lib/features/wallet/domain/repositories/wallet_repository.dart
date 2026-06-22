abstract class WalletRepository {
  Stream walletStream(String uid);
  Future fetchWallet(String uid);
  Stream transactionsStreamForUser(String uid);
  Future sendTip({
    required String fromUserId,
    required String toUserId,
    required String fromUsername,
    required String toUsername,
    required double amount,
    String? videoId,
    String? message,
  });
  Future fundWallet({required String userId, required double amount});
  Future requestWithdrawal({
    required String userId,
    required double amount,
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountName,
  });
  Future saveBankInfo({
    required String userId,
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountName,
  });
}
