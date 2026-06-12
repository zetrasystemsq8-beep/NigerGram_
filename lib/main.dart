import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nigergram/core/di/dependency_injector.dart';
import 'package:nigergram/core/init/app_widget.dart';
import 'package:nigergram/core/utils/debug/firebase_debugger.dart';
import 'package:nigergram/firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ FIXED: Add timeout and error handling to Firebase initialization
  try {
    debugPrint('🟡 [STARTUP] Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        debugPrint('🔴 [STARTUP] Firebase initialization timeout after 20s');
        throw TimeoutException('Firebase init timeout - check internet connection');
      },
    );
    debugPrint('✅ [STARTUP] Firebase initialized successfully');
  } on TimeoutException catch (e) {
    debugPrint('🔴 [STARTUP] Firebase initialization timed out: ${e.message}');
    debugPrint('⚠️ [STARTUP] Continuing anyway - Firebase may initialize later');
  } catch (e) {
    debugPrint('🔴 [STARTUP] Firebase initialization error: $e');
    debugPrint('⚠️ [STARTUP] Continuing anyway - app can work offline');
  }

  // ✅ FIXED: Add timeout and error handling to Supabase initialization
  try {
    debugPrint('🟡 [STARTUP] Initializing Supabase...');
    await Supabase.initialize(
      url: 'https://ssmwuihkafrulmvtiuam.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNzbXd1aWhrYWZydWxtdnRpdWFtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA4Mjk2NjAsImV4cCI6MjA5NjQwNTY2MH0.e1PxmDW77ZhbonS-Z96SWA_sPyVGedzpZNZbJQz7pQo',
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        debugPrint('🔴 [STARTUP] Supabase initialization timeout after 15s');
        throw TimeoutException('Supabase init timeout - check internet connection');
      },
    );
    debugPrint('✅ [STARTUP] Supabase initialized successfully');
  } on TimeoutException catch (e) {
    debugPrint('⚠️ [STARTUP] Supabase initialization timed out: ${e.message}');
    debugPrint('⚠️ [STARTUP] Continuing anyway - Supabase is optional for video feed');
  } catch (e) {
    debugPrint('⚠️ [STARTUP] Supabase initialization error: $e');
    debugPrint('⚠️ [STARTUP] Continuing anyway - Supabase is optional for video feed');
  }

  debugPrint('🟡 [STARTUP] Setting up dependency injection...');
  injectionSetup();
  debugPrint('✅ [STARTUP] Dependency injection setup complete');

  // ✅ DEBUG: Validate Firebase setup on debug mode
  if (kDebugMode) {
    debugPrint('🟡 [STARTUP] Running Firebase diagnostics...');
    await Future.delayed(const Duration(milliseconds: 500));
    await FirebaseDebugger.validateFirebaseSetup();
  }

  debugPrint('🟡 [STARTUP] Starting app...');
  runApp(const AppWidget());
}
