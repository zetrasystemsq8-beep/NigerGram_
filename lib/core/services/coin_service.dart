/// ════════════════════════════════════════════════════════════════
/// NIGERGRAM COIN SYSTEM — MASTER SERVICE
/// ════════════════════════════════════════════════════════════════
/// All coin system constants live here. No hardcoded values anywhere else.
/// ════════════════════════════════════════════════════════════════

class CoinService {
  // ────────────────────────────────────────────────────────────────
  // CONSTANTS
  // ────────────────────────────────────────────────────────────────

  /// 1 coin = ₦100.00 (naira value)
  static const double COIN_VALUE_IN_NAIRA = 100.0;

  /// Monnify's fee when user purchases coins (1.5%)
  /// Deducted from platform revenue at settlement, NOT from user's coin purchase
  static const double MONNIFY_PURCHASE_FEE = 0.015;

  /// Monnify's fee when creator withdraws (1.5%)
  /// Deducted from creator payout (from naira amount before sending to creator)
  static const double MONNIFY_DISBURSEMENT_FEE = 0.015;

  /// Platform fee on creator withdrawal (3.5%)
  /// Deducted from creator payout (from naira amount before sending to creator)
  static const double PLATFORM_FEE_PERCENT = 0.035;

  /// Minimum coins required for creator withdrawal request
  static const int MIN_WITHDRAWAL_COINS = 100;

  /// Maximum coins a creator can withdraw per calendar month
  static const int MAX_MONTHLY_WITHDRAWAL_COINS = 1000;

  // ────────────────────────────────────────────────────────────────
  // CALCULATED PAYOUTS
  // ────────────────────────────────────────────────────────────────

  /// Calculate net payout for creator after all fees
  /// Formula: coinAmount * COIN_VALUE_IN_NAIRA * (1 - MONNIFY_DISBURSEMENT_FEE - PLATFORM_FEE_PERCENT)
  /// Example: 100 coins = ₦10,000 → ₦10,000 * 0.95 = ₦9,500 to creator
  static double calculateCreatorPayout(int coinAmount) {
    final nairaValue = coinAmount * COIN_VALUE_IN_NAIRA;
    final totalFeePercent = MONNIFY_DISBURSEMENT_FEE + PLATFORM_FEE_PERCENT;
    final payout = nairaValue * (1 - totalFeePercent);
    return payout;
  }

  /// Calculate Monnify disbursement fee for display
  static double calculateMonnifyDisbursementFee(int coinAmount) {
    final nairaValue = coinAmount * COIN_VALUE_IN_NAIRA;
    return nairaValue * MONNIFY_DISBURSEMENT_FEE;
  }

  /// Calculate platform fee for display
  static double calculatePlatformFee(int coinAmount) {
    final nairaValue = coinAmount * COIN_VALUE_IN_NAIRA;
    return nairaValue * PLATFORM_FEE_PERCENT;
  }

  /// Convert naira to coins (floored, no fractional coins)
  static int coinFromNaira(double nairaPaid) {
    return (nairaPaid / COIN_VALUE_IN_NAIRA).floor();
  }
}
