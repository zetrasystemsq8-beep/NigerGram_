import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles Username+Password signup/login. Registers the account in BOTH
/// Firebase Auth (credentials recorded there, as requested) AND Supabase
/// Auth (so Community, Exchange, the CP ledger, and Crucible/Tribunal —
/// everything already built on Supabase's auth.uid() — keep working
/// unchanged). AppAuth keeps reading from Supabase exactly as before;
/// nothing downstream needs to change.
class FirebaseAuthService {
  final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;
  final SupabaseClient _supabase = Supabase.instance.client;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _emailDomain = 'nigergram.local';

  String _syntheticEmail(String username) => '${username.trim().toLowerCase()}@$_emailDomain';

  Future<void> signUpWithUsername({
    required String username,
    required String password,
    String? displayName,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty) throw Exception('Username cannot be empty');
    if (cleanUsername.contains(RegExp(r'[^a-z0-9_]'))) {
      throw Exception('Username can only contain letters, numbers, and underscores');
    }
    if (password.length < 6) throw Exception('Password must be at least 6 characters');

    final email = _syntheticEmail(cleanUsername);

    // Firebase first — if the username's taken, this throws before we
    // touch Supabase at all, so we never create a half-registered account.
    final fbCredential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    try {
      final supabaseResponse = await _supabase.auth.signUp(email: email, password: password);
      final supabaseUid = supabaseResponse.user?.id;

      if (supabaseUid == null) {
        throw Exception('Could not create matching Supabase account');
      }

      await _firestore.collection('users').doc(fbCredential.user!.uid).set({
        'username': cleanUsername,
        'displayName': displayName?.trim().isNotEmpty == true ? displayName!.trim() : cleanUsername,
        'profilePicUrl': '',
        'authMethod': 'username_password',
        'supabaseUid': supabaseUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Roll back the Firebase account if the Supabase mirror failed, so
      // we never leave a half-created account stuck in limbo.
      await fbCredential.user?.delete();
      rethrow;
    }
  }

  /// Logs in with username+password. Signs into Supabase — the session
  /// AppAuth and every feature actually reads from — and Firebase
  /// alongside it.
  Future<void> loginWithUsername({
    required String username,
    required String password,
  }) async {
    final email = _syntheticEmail(username);

    await _supabase.auth.signInWithPassword(email: email, password: password);

    try {
      await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    } catch (_) {
      // Non-fatal — Supabase is the session that actually matters to the
      // rest of the app. Firebase staying out of sync here doesn't block
      // the user from using NigerGram.
    }
  }

  /// Checks if a username is already taken, before the user commits to
  /// submitting the signup form.
  Future<bool> isUsernameTaken(String username) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty) return false;
    try {
      final methods = await _firebaseAuth.fetchSignInMethodsForEmail(_syntheticEmail(cleanUsername));
      return methods.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
