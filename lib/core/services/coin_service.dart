/// ════════════════════════════════════════════════════════════════
/// NIGERGRAM ZTC CENT SYSTEM — MASTER SERVICE
/// ════════════════════════════════════════════════════════════════
/// All cent (CP) system constants live here. No hardcoded values
/// anywhere else.
///
/// NigerGram no longer processes real money directly. Cents are
/// funded and cashed out through each user's linked ZTC account
/// (their ZetraID). This service only tracks the constants NigerGram
/// itself needs — minimums for actions taken inside the app.
/// ════════════════════════════════════════════════════════════════

class CoinService {
  // ────────────────────────────────────────────────────────────────
  // CONSTANTS
  // ────────────────────────────────────────────────────────────────

  /// Minimum cents required for a creator to submit a cash-out request.
  static const int MIN_WITHDRAWAL_CENTS = 100;

  /// Maximum cents a creator can request to cash out per calendar month.
  static const int MAX_MONTHLY_WITHDRAWAL_CENTS = 1000;

  /// Minimum cents required to send a gift/tip.
  static const int MIN_GIFT_CENTS = 1;
}
