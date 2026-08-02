import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nigergram/core/utils/app_auth.dart';

/// Bridges ZTC's Supabase wallet table into NigerGram's own Firestore
/// wallet, which is what every screen in the app (tips, gifts, cash
/// out, wallet home) already reads and writes.
///
/// ZTC writes to `nigergram_wallets` (Supabase), storing raw
/// balance_cents where 1000 balance_cents = 1 CP. This class listens
/// for changes in real time, converts to CP, and mirrors the total
/// into `wallets/{uid}.coinBalance` (Firestore) — so the moment ZTC
/// credits someone, their NigerGram balance updates automatically,
/// with zero changes needed anywhere else in the app.
class ZtcWalletBridge {
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
        .channel('nigergram_wallet_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'nigergram_wallets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            final balanceCents = (newRecord['balance_cents'] as num?)?.toInt();
            if (balanceCents != null) {
              _mirrorToFirestore(uid, balanceCents);
            }
          },
        )
        .subscribe();
  }

  static Future<void> _syncOnce(String uid) async {
    try {
      final row = await Supabase.instance.client
          .from('nigergram_wallets')
          .select('balance_cents')
          .eq('user_id', uid)
          .maybeSingle();

      final balanceCents = (row?['balance_cents'] as num?)?.toInt();
      if (balanceCents != null) {
        await _mirrorToFirestore(uid, balanceCents);
      }
    } catch (e) {
      // Non-fatal — realtime subscription will still catch future updates.
    }
  }

  /// Converts ZTC's raw balance_cents into NigerGram's CP unit
  /// (1000 balance_cents = 1 CP) and writes it into the Firestore
  /// wallet doc that the rest of the app already reads.
  static Future<void> _mirrorToFirestore(String uid, int balanceCents) async {
    final cp = balanceCents ~/ 1000;
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
