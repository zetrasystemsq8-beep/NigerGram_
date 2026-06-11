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
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        final String baseHandle = email
            .split('@')
            .first
            .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');

        await _firestore.collection('users').doc(firebaseUser.uid).set({
          'uid': firebaseUser.uid,
          'email': email,
          'username': baseHandle,
          'profileImageUrl': '',
          'bio': 'New NigerGram Creator 🇳🇬',
          'followers': 0,
          'following': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });

        _signInToSupabase(email, password);
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
      _signInToSupabase(email, password);
      emit(AuthSuccess());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _signInToSupabase(String email, String password) async {
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      try {
        await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );
      } catch (_) {}
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    await Supabase.instance.client.auth.signOut();
    emit(AuthInitial());
  }
}
