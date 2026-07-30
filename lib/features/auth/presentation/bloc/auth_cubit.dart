import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nigergram/core/utils/zetra_mail_converter.dart';

part 'auth_state.dart';

/// Authentication is 100% Supabase. Firebase Auth has been fully removed.
///
/// Users log in with their ZetraMail address (e.g. testing@zetramail.ng).
/// That address is never sent to Supabase directly — it is converted into
/// an internal auth email (e.g. testing@auth.zetraid.internal) before
/// calling signInWithPassword(). The user never sees the internal email.
class AuthCubit extends Cubit<AuthState> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthCubit() : super(AuthInitial());

  /// Logs in using a ZetraMail address + password.
  ///
  /// [zetraMailOrRawInput] can be the full ZetraMail address
  /// (testing@zetramail.ng) or just the local part (testing) — both are
  /// converted the same way.
  Future<void> login(String zetraMailOrRawInput, String password) async {
    emit(AuthLoading());
    try {
      final internalEmail =
          ZetraMailConverter.toInternalEmail(zetraMailOrRawInput);

      debugPrint('🟡 [LOGIN] Attempting Supabase login for $internalEmail');

      final response = await _supabase.auth
          .signInWithPassword(
            email: internalEmail,
            password: password,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw TimeoutException('Login connection timed out.'),
          );

      final user = response.user;
      if (user == null) {
        emit(AuthError('Invalid ZetraMail or password.'));
        return;
      }

      debugPrint('✅ [LOGIN] Supabase login successful (uid: ${user.id})');

      // Ensure the Firestore profile documents exist for this uid. This
      // keeps every other feature (profile, wallet, uploads, chat, gist
      // hub) working without needing a separate signup flow — accounts
      // are provisioned upstream by ZetraID; this just bootstraps the
      // app-facing documents on first successful login.
      await _ensureFirestoreDocsExist(user);

      if (user.emailConfirmedAt != null) {
        emit(AuthSuccess());
        debugPrint('✅ [LOGIN] Email verified — proceeding to dashboard');
      } else {
        emit(AuthUnverified());
        debugPrint('🟡 [LOGIN] Email not verified — routing to verification');
      }
    } on AuthException catch (e) {
      debugPrint('🔴 [LOGIN] Supabase auth error: ${e.message}');
      emit(AuthError(_mapAuthError(e)));
    } on TimeoutException catch (e) {
      debugPrint('🔴 [LOGIN] Timeout: ${e.message}');
      emit(AuthError('Connection timed out. Please try again.'));
    } catch (e) {
      debugPrint('🔴 [LOGIN] Error: $e');
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _ensureFirestoreDocsExist(User user) async {
    try {
      final userDocRef = _firestore.collection('users').doc(user.id);
      final userDoc = await userDocRef.get().timeout(const Duration(seconds: 8));

      if (!userDoc.exists) {
        final baseHandle = ZetraMailConverter.localPartFromInternalEmail(
          user.email ?? '',
        ).replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');

        debugPrint('🟡 [LOGIN] Bootstrapping Firestore user doc for ${user.id}');
        await userDocRef.set({
          'uid': user.id,
          'email': user.email,
          'username': baseHandle.isEmpty ? 'naija_creator' : baseHandle,
          'displayName': baseHandle.isEmpty ? 'naija_creator' : baseHandle,
          'profileImageUrl': '',
          'profilePicUrl': '',
          'bio': 'New NigerGram Creator 🇳🇬',
          'followers': 0,
          'following': 0,
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 8));

        try {
          await _firestore.collection('wallets').doc(user.id).set({
            'uid': user.id,
            'balance': 0.0,
            'coinBalance': 0,
            'totalEarned': 0.0,
            'bankAccountNumber': null,
            'bankName': null,
            'bankAccountName': null,
            'bankCode': null,
            'updatedAt': FieldValue.serverTimestamp(),
          }).timeout(const Duration(seconds: 8));
        } catch (e) {
          debugPrint('⚠️ [LOGIN] Could not create wallet document: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [LOGIN] Could not verify/create Firestore user doc: $e');
      // Non-fatal — don't block login if this bootstrap step fails.
    }
  }

  /// Sends a fresh verification email to the currently signed-in user.
  Future<void> resendVerificationEmail() async {
    final user = _supabase.auth.currentUser;
    if (user?.email == null) return;
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: user!.email!,
      );
      debugPrint('✅ [VERIFY] Resent verification email');
    } catch (e) {
      debugPrint('🔴 [VERIFY] Failed to resend verification email: $e');
      rethrow;
    }
  }

  /// Refreshes the session and checks whether the email has now been
  /// verified. Emits AuthSuccess if verified, otherwise stays AuthUnverified.
  Future<void> refreshVerificationStatus() async {
    try {
      final response = await _supabase.auth.refreshSession();
      final user = response.user ?? _supabase.auth.currentUser;
      if (user?.emailConfirmedAt != null) {
        emit(AuthSuccess());
      } else {
        emit(AuthUnverified());
      }
    } catch (e) {
      debugPrint('🔴 [VERIFY] Failed to refresh verification status: $e');
      emit(AuthUnverified());
    }
  }

  /// Sends a password reset email for the given ZetraMail address.
  Future<void> sendPasswordResetEmail(String zetraMailOrRawInput) async {
    final internalEmail =
        ZetraMailConverter.toInternalEmail(zetraMailOrRawInput);
    await _supabase.auth.resetPasswordForEmail(internalEmail);
  }

  Future<void> logout() async {
    try {
      debugPrint('🟡 [LOGOUT] Logging out');
      await _supabase.auth.signOut();
      debugPrint('✅ [LOGOUT] Logout successful');
    } catch (e) {
      debugPrint('⚠️ [LOGOUT] Error during logout: $e');
    }
    emit(AuthInitial());
  }

  String _mapAuthError(AuthException e) {
    final code = e.statusCode;
    final message = e.message.toLowerCase();

    if (message.contains('invalid login credentials') ||
        message.contains('invalid_credentials')) {
      return '❌ Invalid ZetraMail or password.';
    }
    if (message.contains('email not confirmed')) {
      return '📧 Please verify your email to continue.';
    }
    if (message.contains('too many requests') || code == '429') {
      return '⏳ Too many attempts. Please try again later.';
    }
    if (message.contains('network')) {
      return '📡 Network issue. Please check your connection.';
    }
    return '⚠️ ${e.message}';
  }
}
