import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, UserCredential;
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

      final firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        final String baseHandle = email
            .split('@')
            .first
            .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');

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

        // ✅ FIXED: Send email verification without blocking auth flow
        try {
          await firebaseUser.sendEmailVerification();
          emit(AuthSuccess());
        } catch (e) {
          // Email sending failed but auth succeeded - continue anyway
          emit(AuthSuccess());
        }

        await _signInToSupabase(email, password);
      }

      emit(AuthSuccess());
    } on TimeoutException catch (e) {
      emit(AuthError('Network Timeout: ${e.message}'));
    } on FirebaseAuthException catch (e) {
      emit(AuthError(e.message ?? 'Registration failed.'));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> login(String email, String password) async {
    emit(AuthLoading());
    try {
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

      // ✅ FIXED: Get current user and handle email verification
      final user = _auth.currentUser;
      if (user != null) {
        // Reload user to get latest email verification status
        await user.reload().timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException('User reload timed out.'),
        );

        // Check if email verification is required and not yet verified
        if (!user.emailVerified) {
          // Try to send verification email (non-blocking)
          try {
            await user.sendEmailVerification().timeout(
              const Duration(seconds: 5),
            );
          } catch (e) {
            debugPrint('⚠️ Could not send verification email: $e');
          }

          // Emit error message asking user to verify
          emit(AuthError(
            'Please verify your email. A verification link has been sent to $email. '
            'Check your inbox (and spam folder) and click the link to verify.',
          ));
          return;
        }
      }

      // Synced call to avoid unawaited microtask background failures
      await _signInToSupabase(email, password);

      emit(AuthSuccess());
    } on TimeoutException catch (e) {
      emit(AuthError('Connection Timeout: ${e.message}}'));
    } on FirebaseAuthException catch (e) {
      emit(AuthError(e.message ?? 'Invalid credentials or configuration issue.'));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  /// ✅ NEW: Allow users to resend verification email
  Future<void> resendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.sendEmailVerification().timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException('Email send timed out.'),
        );
        emit(AuthSuccess()); // Indicates success without clearing state
      } else {
        emit(AuthError('No user logged in.'));
      }
    } on TimeoutException catch (e) {
      emit(AuthError('Timeout: ${e.message}'));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _signInToSupabase(String email, String password) async {
    try {
      await Supabase.instance.client.auth
          .signInWithPassword(
            email: email,
            password: password,
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      try {
        await Supabase.instance.client.auth
            .signUp(
              email: email,
              password: password,
            )
            .timeout(const Duration(seconds: 10));
      } catch (_) {}
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    emit(AuthInitial());
  }
}
