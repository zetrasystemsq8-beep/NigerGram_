import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nigergram/core/utils/app_auth.dart';

/// Bridges ZTC's real per-app currency system into NigerGram's own
/// Firestore wallet, which is what every screen in the app (tips,
/// gifts, cash out, wallet home) already reads and writes.
///
/// ZTC tracks NigerGram's balance in `app_currency_balances`
/// (app_id = 'nigergram'), with the raw stored `balance` in cents —
/// 1000 cents = 1 CP, per NigerGram's registration in
/// `app_currencies`. This class listens for changes in real time,
/// converts to CP, and mirrors the total into
/// `wallets/{uid}.coinBalance` (Firestore) — so the moment ZTC
/// credits someone, their NigerGram balance updates automatically,
/// with zero changes needed anywhere else in the app.
class ZtcWalletBridge {
  static const String _appId = 'nigergram';
  static const int _centsPerUnit = 1000;

  static RealtimeChannel? _channel;

  /// Call this once after login (e.g. from WalletCubit's constructor).
  /// Safe to call multiple times — it replaces any existing listener.
  static void start() {
    stop();

    final uid = AppAuth.uid;
    if (uid.isEmpty) return;

    final supabase = Supabase.instance.client;

    // Catch up immediately in case a balance was credited while the
    // app was closed.
    _syncOnce(uid);

    _channel = supabase
        .channel('nigergram_app_balance_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'app_currency_balances',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if ((newRecord['app_id'] as String?) != _appId) return;
            final balance = (newRecord['balance'] as num?)?.toInt();
            if (balance != null) {
              _mirrorToFirestore(uid, balance);
            }
          },
        )
        .subscribe();
  }

  static Future<void> _syncOnce(String uid) async {
    try {
      final row = await Supabase.instance.client
          .from('app_currency_balances')
          .select('balance')
          .eq('user_id', uid)
          .eq('app_id', _appId)
          .maybeSingle();

      final balance = (row?['balance'] as num?)?.toInt();
      if (balance != null) {
        await _mirrorToFirestore(uid, balance);
      }
    } catch (e) {
      // Non-fatal — realtime subscription will still catch future updates.
    }
  }

  /// Converts ZTC's raw balance (cents) into NigerGram's CP unit and
  /// writes it into the Firestore wallet doc that the rest of the app
  /// already reads.
  static Future<void> _mirrorToFirestore(String uid, int rawBalance) async {
    final cp = rawBalance ~/ _centsPerUnit;
    await FirebaseFirestore.instance.collection('wallets').doc(uid).set({
      'coinBalance': cp,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static void stop() {
    _channel?.unsubscribe();
    _channel = null;
  }
}
