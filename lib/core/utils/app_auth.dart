import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized accessor for the currently authenticated user.
///
/// Firebase Auth has been fully removed from NigerGram. Supabase is now
/// the single source of truth for authentication. Every feature that used
/// to read `FirebaseAuth.instance.currentUser` should read from here
/// instead, using the Supabase user's UUID as the canonical identifier
/// for all Firestore documents going forward.
class AppAuth {
  AppAuth._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// The current Supabase user, or null if signed out.
  static User? get currentUser => _client.auth.currentUser;

  /// True if a user is currently signed in.
  static bool get isLoggedIn => currentUser != null;

  /// The current user's Supabase UUID. Empty string if signed out.
  /// This is the new canonical "uid" used across Firestore documents.
  static String get uid => currentUser?.id ?? '';

  /// The current user's internal auth email
  /// (e.g. testing@auth.zetraid.internal). Empty string if signed out.
  static String get email => currentUser?.email ?? '';

  /// True if the current user's email has been verified.
  static bool get isEmailVerified => currentUser?.emailConfirmedAt != null;

  /// A best-effort display handle derived from the internal email's
  /// local part (e.g. "testing" from "testing@auth.zetraid.internal").
  static String get displayHandle {
    final e = email;
    if (e.isEmpty || !e.contains('@')) return 'user';
    return e.split('@').first;
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
