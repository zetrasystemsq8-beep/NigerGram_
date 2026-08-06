import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nigergram/core/utils/app_auth.dart';

/// Bridges ZTC's real per-app currency system into NigerGram's own
/// Firestore wallet, which is what every screen in the app (tips,
/// gifts, cash out, wallet home) already reads and writes.
///
/// ZTC tracks NigerGram's balance in `app_currency_balances`
/// (app_id = 'nigergram'), with the raw stored `balance` in cents —
/// 1000 cents = 1 CP. This class listens for changes in real time,
/// mirrors the RAW cents into `wallets/{uid}.balanceCents` (source of
/// truth), and also writes the split `coinBalance` (CP) for any old
/// screens still reading it directly. It also logs a 'deposit'
/// transaction whenever the balance increases, since ZTC-side credits
/// don't otherwise create any record in NigerGram's own history.
class ZtcWalletBridge {
  static const String _appId = 'nigergram';
  static const int _centsPerUnit = 1000;

  static RealtimeChannel? _channel;

  static void start() {
    stop();

    final uid = AppAuth.uid;
    if (uid.isEmpty) return;

    final supabase = Supabase.instance.client;

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

  /// Mirrors ZTC's raw balance (cents) into Firestore, keeping the full
  /// precision (no floor division loss), and logs a 'deposit' transaction
  /// if the balance went UP since the last known value — that's the only
  /// place a ZTC-side credit ever gets recorded in NigerGram's history.
  static Future<void> _mirrorToFirestore(String uid, int rawBalance) async {
    final walletRef = FirebaseFirestore.instance.collection('wallets').doc(uid);
    final txRef = FirebaseFirestore.instance.collection('wallet_transactions').doc();

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snap = await transaction.get(walletRef);
      final data = snap.data();
      final previousRaw = (data?['balanceCents'] as num?)?.toInt() ?? 0;
      final delta = rawBalance - previousRaw;

      final cp = rawBalance ~/ _centsPerUnit;

      transaction.set(walletRef, {
        'userId': uid,
        'coinBalance': cp,
        'balanceCents': rawBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Only log an increase we haven't already logged elsewhere
      // (withdrawals log themselves explicitly and always decrease).
      if (delta > 0) {
        transaction.set(txRef, {
          'fromUserId': uid,
          'toUserId': uid,
          'fromUsername': '',
          'toUsername': '',
          'coinAmount': delta,
          'type': 'deposit',
          'videoId': null,
          'message': null,
          'status': 'completed',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  static void stop() {
    _channel?.unsubscribe();
    _channel = null;
  }
}
