import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, UserCredential;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthCubit() : super(AuthInitial());

  Future<void> register(String email, String password) async {
    emit(AuthLoading());
    try {
      debugPrint('🟡 [REGISTER] Starting Firebase registration for $email');
      
      // 15-second hard limit to prevent infinite platform-channel hangs during registration
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: email,
            password: password,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Firebase authentication service timed out.'),
          );

      debugPrint('✅ [REGISTER] Firebase registration successful');
      final firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        final String baseHandle = email
            .split('@')
            .first
            .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');

        debugPrint('🟡 [REGISTER] Creating Firestore user document');
        await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .set({
              'uid': firebaseUser.uid,
              'email': email,
              'username': baseHandle,
              'profileImageUrl': '',
              'bio': 'New NigerGram Creator 🇳🇬',
              'followers': 0,
              'following': 0,
              'createdAt': FieldValue.serverTimestamp(),
            })
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw TimeoutException('Firestore database initialization timed out.'),
            );

        debugPrint('✅ [REGISTER] Firestore user document created');

        // ✅ FIXED: Send email verification without blocking auth flow
        try {
          debugPrint('🟡 [REGISTER] Sending email verification link to $email');
          await firebaseUser.sendEmailVerification().timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException('Email verification send timed out.'),
          );
          debugPrint('✅ [REGISTER] Email verification link sent');
        } catch (e) {
          debugPrint('⚠️ [REGISTER] Could not send verification email: $e');
          // Don't block registration if email sending fails
        }

        await _signInToSupabase(email, password);
      }

      emit(AuthSuccess());
      debugPrint('✅ [REGISTER] Registration complete - awaiting email verification');
    } on TimeoutException catch (e) {
      debugPrint('🔴 [REGISTER] Timeout: ${e.message}');
      emit(AuthError('Network Timeout: ${e.message}'));
    } on FirebaseAuthException catch (e) {
      debugPrint('🔴 [REGISTER] Firebase error: ${e.code} - ${e.message}');
      emit(AuthError(e.message ?? 'Registration failed.'));
    } catch (e) {
      debugPrint('🔴 [REGISTER] Error: $e');
      emit(AuthError(e.toString()));
    }
  }

  Future<void> login(String email, String password) async {
    emit(AuthLoading());
    try {
      debugPrint('🟡 [LOGIN] Attempting login for $email');

      // 15-second hard safety gate. If the handshake hangs, it breaks the loop and reports it.
      await _auth
          .signInWithEmailAndPassword(
            email: email,
            password: password,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Firebase login connection timed out.'),
          );

      debugPrint('✅ [LOGIN] Firebase credentials accepted');

      // ✅ FIXED: Get current user and handle email verification
      final user = _auth.currentUser;
      if (user != null) {
        debugPrint('🟡 [LOGIN] Checking email verification status');
        
        // Reload user to get latest email verification status
        await user.reload().timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException('User reload timed out.'),
        );

        debugPrint('📧 [LOGIN] Email verified: ${user.emailVerified}');

        // Check if email verification is required and not yet verified
        if (!user.emailVerified) {
          debugPrint('⚠️ [LOGIN] Email not verified - sending verification link');
          
          // Try to send verification email (non-blocking)
          try {
            await user.sendEmailVerification().timeout(
              const Duration(seconds: 5),
            );
            debugPrint('✅ [LOGIN] Verification email sent to $email');
          } catch (e) {
            debugPrint('⚠️ [LOGIN] Could not send verification email: $e');
          }

          // Emit error message asking user to verify
          emit(AuthError(
            'Email Verification Required\n\n'
            'A verification link has been sent to $email.\n\n'
            'Please check your inbox (and spam folder) and click the link to verify your email. '
            'Once verified, try logging in again.',
          ));
          return;
        }

        debugPrint('✅ [LOGIN] Email is verified, proceeding to Supabase sync');
      }

      // Synced call to avoid unawaited microtask background failures
      await _signInToSupabase(email, password);

      emit(AuthSuccess());
      debugPrint('✅ [LOGIN] Login successful');
    } on TimeoutException catch (e) {
      debugPrint('🔴 [LOGIN] Timeout: ${e.message}');
      emit(AuthError('Connection Timeout: ${e.message}'));
    } on FirebaseAuthException catch (e) {
      debugPrint('🔴 [LOGIN] Firebase error: ${e.code} - ${e.message}');
      emit(AuthError(e.message ?? 'Invalid credentials or configuration issue.'));
    } catch (e) {
      debugPrint('🔴 [LOGIN] Error: $e');
      emit(AuthError(e.toString()));
    }
  }

  /// ✅ NEW: Allow users to resend verification email
  Future<void> resendVerificationEmail() async {
    debugPrint('🟡 [RESEND] Resending verification email');
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.sendEmailVerification().timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException('Email send timed out.'),
        );
        debugPrint('✅ [RESEND] Verification email resent');
        emit(AuthSuccess()); // Indicates success
      } else {
        debugPrint('🔴 [RESEND] No user logged in');
        emit(AuthError('No user logged in.'));
      }
    } on TimeoutException catch (e) {
      debugPrint('🔴 [RESEND] Timeout: ${e.message}');
      emit(AuthError('Timeout: ${e.message}'));
    } catch (e) {
      debugPrint('🔴 [RESEND] Error: $e');
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _signInToSupabase(String email, String password) async {
    try {
      debugPrint('🟡 [SUPABASE] Attempting Supabase login');
      await Supabase.instance.client.auth
          .signInWithPassword(
            email: email,
            password: password,
          )
          .timeout(const Duration(seconds: 10));
      debugPrint('✅ [SUPABASE] Supabase login successful');
    } catch (e) {
      debugPrint('⚠️ [SUPABASE] Supabase login failed: $e - attempting signup');
      try {
        await Supabase.instance.client.auth
            .signUp(
              email: email,
              password: password,
            )
            .timeout(const Duration(seconds: 10));
        debugPrint('✅ [SUPABASE] Supabase signup successful');
      } catch (signupError) {
        debugPrint('⚠️ [SUPABASE] Supabase signup also failed: $signupError - continuing anyway');
      }
    }
  }

  Future<void> logout() async {
    try {
      debugPrint('🟡 [LOGOUT] Logging out');
      await _auth.signOut();
      await Supabase.instance.client.auth.signOut();
      debugPrint('✅ [LOGOUT] Logout successful');
    } catch (e) {
      debugPrint('⚠️ [LOGOUT] Error during logout: $e');
    }
    emit(AuthInitial());
  }
}
