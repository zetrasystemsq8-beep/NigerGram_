import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class FirebaseDebugger {
  /// Validates Firebase setup and connectivity
  /// Returns true if all systems are healthy
  static Future<bool> validateFirebaseSetup() async {
    debugPrint('╔════════════════════════════════════════════╗');
    debugPrint('║  Firebase Configuration Debug Start       ║');
    debugPrint('╚════════════════════════════════════════════╝');

    bool allHealthy = true;

    // Check Firebase App
    try {
      final app = Firebase.app();
      debugPrint('✅ Firebase App: ${app.name} (initialized)');
    } catch (e) {
      debugPrint('🔴 Firebase App Error: $e');
      allHealthy = false;
      return allHealthy;
    }

    // Check Firestore Connectivity
    try {
      debugPrint('🟡 Testing Firestore connectivity...');
      final firestore = FirebaseFirestore.instance;
      
      // Create a test document
      await firestore
          .collection('_health_check')
          .doc('test_${DateTime.now().millisecondsSinceEpoch}')
          .set({
        'timestamp': DateTime.now().toIso8601String(),
        'message': 'Health check',
      }).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Firestore write timeout after 5s');
        },
      );

      debugPrint('✅ Firestore: Connected and writable');

      // Clean up test document
      try {
        await firestore
            .collection('_health_check')
            .where('message', isEqualTo: 'Health check')
            .get()
            .then((snapshot) {
          for (final doc in snapshot.docs) {
            doc.reference.delete();
          }
        });
      } catch (e) {
        debugPrint('⚠️ Could not clean up test documents: $e');
      }
    } on TimeoutException catch (e) {
      debugPrint('🔴 Firestore: Timeout - $e');
      debugPrint('   → Likely network issue or Firebase credentials invalid');
      allHealthy = false;
    } catch (e) {
      debugPrint('🔴 Firestore: Error - $e');
      debugPrint('   → Check Firebase credentials and internet connection');
      allHealthy = false;
    }

    // Check Firebase Auth
    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      if (user != null) {
        debugPrint('✅ Firebase Auth: Logged in as ${user.email}');
      } else {
        debugPrint('✅ Firebase Auth: Not logged in (normal on startup)');
      }
    } catch (e) {
      debugPrint('🔴 Firebase Auth: Error - $e');
      allHealthy = false;
    }

    // Summary
    debugPrint('╔════════════════════════════════════════════╗');
    if (allHealthy) {
      debugPrint('║  ✅ All Systems Healthy                   ║');
    } else {
      debugPrint('║  🔴 Issues Detected - See Details Above   ║');
    }
    debugPrint('╚════════════════════════════════════════════╝');

    return allHealthy;
  }

  /// Logs detailed Firebase configuration info
  static Future<void> logFirebaseInfo() async {
    debugPrint('╔════════════════════════════════════════════╗');
    debugPrint('║  Firebase Configuration Info              ║');
    debugPrint('╚════════════════════════════════════════════╝');

    try {
      final app = Firebase.app();
      debugPrint('App Name: ${app.name}');
    } catch (e) {
      debugPrint('App: Not initialized - $e');
    }

    try {
      final auth = FirebaseAuth.instance;
      debugPrint('Auth Instance: ${auth.runtimeType}');
      debugPrint('Current User: ${auth.currentUser?.email ?? "None"}');
      debugPrint('Is Signed In: ${auth.currentUser != null}');
    } catch (e) {
      debugPrint('Auth Error: $e');
    }

    try {
      final firestore = FirebaseFirestore.instance;
      debugPrint('Firestore Instance: ${firestore.runtimeType}');
    } catch (e) {
      debugPrint('Firestore Error: $e');
    }

    debugPrint('────────────────────────────────────────────');
  }

  /// Simulates login process to debug issues
  static Future<void> debugLogin({
    required String email,
    required String password,
  }) async {
    debugPrint('╔════════════════════════════════════════════╗');
    debugPrint('║  Debug Login Process                      ║');
    debugPrint('╚════════════════════════════════════════════╝');

    try {
      debugPrint('🟡 Attempting login with: $email');
      
      final auth = FirebaseAuth.instance;
      
      final userCredential = await auth
          .signInWithEmailAndPassword(
            email: email,
            password: password,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                'Login timed out after 15s - check internet connection',
              );
            },
          );

      debugPrint('✅ Login successful!');
      debugPrint('   User: ${userCredential.user?.email}');
      debugPrint('   UID: ${userCredential.user?.uid}');

      // Sign out for testing
      await auth.signOut();
      debugPrint('✅ Signed out for testing');
    } on FirebaseAuthException catch (e) {
      debugPrint('🔴 Firebase Auth Error: ${e.code}');
      debugPrint('   Message: ${e.message}');
      _handleAuthError(e.code);
    } on TimeoutException catch (e) {
      debugPrint('🔴 Timeout: $e');
      debugPrint('   → Check internet connection');
      debugPrint('   → Check if Firebase credentials are valid');
    } catch (e) {
      debugPrint('🔴 Error: $e');
    }

    debugPrint('────────────────────────────────────────────');
  }

  /// Handle specific Firebase auth errors
  static void _handleAuthError(String code) {
    final errorMessages = {
      'invalid-email': 'Email format is invalid',
      'user-disabled': 'User account has been disabled',
      'user-not-found': 'No account exists with this email',
      'wrong-password': 'Incorrect password',
      'invalid-credential': 'Invalid credentials',
      'too-many-requests': 'Too many failed login attempts. Try again later.',
      'operation-not-allowed': 'Email/password login is disabled',
      'network-request-failed': 'Network error - check internet connection',
    };

    final message = errorMessages[code] ?? 'Unknown error: $code';
    debugPrint('   Details: $message');
  }
}
