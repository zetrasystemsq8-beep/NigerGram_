import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

/// Firestore-only diagnostics. Firebase Auth has been fully removed from
/// NigerGram (authentication is 100% Supabase now), so this debugger only
/// validates Firebase Core initialization and Firestore connectivity,
/// which remain in use for Gist Hub, comments, reactions, and legacy data.
class FirebaseDebugger {
  /// Validates Firebase setup and connectivity.
  /// Returns true if all systems are healthy.
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

  /// Logs detailed Firebase configuration info.
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
      final firestore = FirebaseFirestore.instance;
      debugPrint('Firestore Instance: ${firestore.runtimeType}');
    } catch (e) {
      debugPrint('Firestore Error: $e');
    }

    debugPrint('────────────────────────────────────────────');
  }
}
