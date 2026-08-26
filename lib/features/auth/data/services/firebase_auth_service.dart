import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles Username+Password AND Google signup/login. Both register the
/// account in Firebase (credentials recorded there, as requested) AND
/// mirror a matching account into Supabase (so Community, Exchange, the
/// CP ledger, and Crucible/Tribunal — everything already built on
/// Supabase's auth.uid() — keep working unchanged). AppAuth keeps
/// reading from Supabase exactly as before; nothing downstream needs to
/// change.
///
/// IMPORTANT #1: the shared Supabase project has an on_auth_user_created
/// trigger (handle_new_user) that fires on every new auth.users row
/// across the whole Zetra ecosystem — it requires
/// raw_user_meta_data->>'username' to be present, so every signUp call
/// here passes `data: {'username': ...}`.
///
/// IMPORTANT #2: AppAuth treats the Supabase user ID as the canonical
/// identifier for every Firestore document in the app (see AppAuth's own
/// comments). So the `users/{id}` profile document here MUST be keyed by
/// the Supabase UID, not the Firebase UID — otherwise every other screen
/// that reads a profile via AppAuth.uid finds nothing.
class FirebaseAuthService {
  final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
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
    final resolvedDisplayName = displayName?.trim().isNotEmpty == true ? displayName!.trim() : cleanUsername;

    final fbCredential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    try {
      final supabaseResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': cleanUsername,
          'full_name': resolvedDisplayName,
        },
      );
      final supabaseUid = supabaseResponse.user?.id;

      if (supabaseUid == null) {
        throw Exception('Could not create matching Supabase account');
      }

      // Keyed by Supabase UID — the canonical identifier AppAuth and
      // every other feature reads by.
      await _firestore.collection('users').doc(supabaseUid).set({
        'username': cleanUsername,
        'displayName': resolvedDisplayName,
        'profilePicUrl': '',
        'authMethod': 'username_password',
        'firebaseUid': fbCredential.user!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      await fbCredential.user?.delete();
      rethrow;
    }
  }

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
      // rest of the app.
    }
  }

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

  /// Signs in with Google. Establishes a session in both Firebase (front
  /// door) and a Supabase "shadow" account keyed to the same email — the
  /// bridge password is just the Firebase UID, never seen or typed by
  /// the user, purely an internal implementation detail. Needs no
  /// Supabase Console configuration at all.
  Future<void> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google sign-in cancelled');
    }

    final googleAuth = await googleUser.authentication;
    final credential = fb.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final fbResult = await _firebaseAuth.signInWithCredential(credential);
    final fbUser = fbResult.user;
    if (fbUser == null || fbUser.email == null) {
      throw Exception('Google sign-in failed — no account email returned');
    }

    final bridgePassword = fbUser.uid;
    final email = fbUser.email!;

    String? supabaseUid;

    try {
      // Returning user — shadow account already exists.
      final signInResp = await _supabase.auth.signInWithPassword(email: email, password: bridgePassword);
      supabaseUid = signInResp.user?.id;
    } catch (_) {
      // First time this Google account has signed into NigerGram —
      // create the shadow account, with the username metadata the
      // shared profile-creation trigger requires.
      final suggestedUsername = await _uniqueUsernameFromEmail(email);
      final signUpResp = await _supabase.auth.signUp(
        email: email,
        password: bridgePassword,
        data: {
          'username': suggestedUsername,
          'full_name': fbUser.displayName,
        },
      );
      supabaseUid = signUpResp.user?.id;

      if (supabaseUid == null) {
        throw Exception('Could not create matching Supabase account');
      }

      // Keyed by Supabase UID — matches every other profile lookup in
      // the app.
      await _firestore.collection('users').doc(supabaseUid).set({
        'username': suggestedUsername,
        'displayName': fbUser.displayName ?? suggestedUsername,
        'profilePicUrl': fbUser.photoURL ?? '',
        'authMethod': 'google',
        'firebaseUid': fbUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (supabaseUid == null) {
      throw Exception('Could not establish a Supabase session for this Google account');
    }
  }

  Future<String> _uniqueUsernameFromEmail(String email) async {
    final base = email.split('@').first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    var candidate = base.isEmpty ? 'user' : base;
    var suffix = 0;
    while (true) {
      final query = await _firestore.collection('users').where('username', isEqualTo: candidate).limit(1).get();
      if (query.docs.isEmpty) return candidate;
      suffix += 1;
      candidate = '$base$suffix';
    }
  }
}
