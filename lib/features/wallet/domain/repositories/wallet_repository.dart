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
  
  Future fundWallet({
    required String userId,
    required int coinAmount,
    required String monnifyTransactionReference,
  });
  
  Future requestWithdrawal({
    required String userId,
    required int coinAmount,
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
