import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      // 1. Create User in Firebase Auth
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        // 2. Provision the High-Fidelity User Profile in Firestore
        await _createUserProfile(firebaseUser, email);
        
        // 3. Sync/Register with Supabase for Video Storage
        await _signInToSupabase(email, password);
      }
      
      emit(AuthSuccess());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> login(String email, String password) async {
    emit(AuthLoading());
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Ensure Supabase session is active for the feed/uploads
      await _signInToSupabase(email, password);
      emit(AuthSuccess());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  /// Internal helper to create the "users" collection document.
  /// This ensures zero "naija_creator" defaults and sets up the TikTok-style data structure.
  Future<void> _createUserProfile(User user, String email) async {
    // Generate a clean handle from the email (e.g. "chima_dev" from "chima.dev@gmail.com")
    final String baseHandle = email.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': email,
      'username': baseHandle,
      'displayName': baseHandle, // Initial display name matches handle
      'profilePicUrl': '',       // To be updated in Profile settings
      'bio': 'New NigerGram Creator 🇳🇬',
      'createdAt': FieldValue.serverTimestamp(),
      'isVerified': false,       // For future institutional-grade verification badges
      'stats': {
        'followers': 0,
        'following': 0,
        'likes': 0,
        'videoCount': 0,
      },
      'searchTokens': [baseHandle.toLowerCase()], // For future search functionality
    });
  }

  Future<void> _signInToSupabase(String email, String password) async {
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      // If sign-in fails, try to sign up in Supabase (Dual-Auth sync)
      try {
        await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );
      } catch (_) {
        // Log or handle Supabase-specific silent failures here
      }
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    await Supabase.instance.client.auth.signOut();
    emit(AuthInitial());
  }
}
