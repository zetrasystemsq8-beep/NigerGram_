/// ════════════════════════════════════════════════════════════════
/// NIGERGRAM ZTC CENT SYSTEM — MASTER SERVICE
/// ════════════════════════════════════════════════════════════════
/// All cent (CP) system constants live here. No hardcoded values
/// anywhere else.
///
/// NigerGram no longer processes real money directly. Cents are
/// funded and cashed out through each user's linked ZTC account
/// (their ZetraID). No artificial minimums here — if someone has
/// 3 cents or 40 cents, they can send or cash out exactly that.
/// ════════════════════════════════════════════════════════════════

class CoinService {
  /// Smallest amount that can be sent, gifted, or cashed out. 1 cent
  /// is the real floor — there's nothing smaller than that.
  static const int MIN_UNIT_CENTS = 1;
}
