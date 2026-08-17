import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nigergram/core/di/dependency_injector.dart';
import 'package:nigergram/core/init/app_widget.dart';
import 'package:nigergram/core/utils/debug/firebase_debugger.dart';
import 'package:nigergram/firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const String kAppId = 'nigergram';
const String kCurrentVersion = '1.0.0';

const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------------
  // FIREBASE
  // ------------------------------------------------------------
  try {
    debugPrint('🟡 [STARTUP] Initializing Firebase...');

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        debugPrint('🔴 [STARTUP] Firebase initialization timeout after 20s');
        throw TimeoutException(
          'Firebase init timeout - check internet connection',
        );
      },
    );

    debugPrint('✅ [STARTUP] Firebase initialized successfully');

    debugPrint('🟡 [STARTUP] Enabling Firestore offline persistence...');

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );

    debugPrint('✅ [STARTUP] Firestore offline persistence enabled');
  } on TimeoutException catch (e) {
    debugPrint('🔴 [STARTUP] Firebase initialization timed out: ${e.message}');
    debugPrint('⚠️ [STARTUP] Continuing anyway');
  } catch (e) {
    debugPrint('🔴 [STARTUP] Firebase initialization error: $e');
    debugPrint('⚠️ [STARTUP] Continuing anyway');
  }

  // ------------------------------------------------------------
  // SUPABASE
  // ------------------------------------------------------------
  bool supabaseReady = false;

  try {
    debugPrint('🟡 [STARTUP] Initializing Supabase...');

    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      throw Exception(
        'Supabase credentials not provided at build time',
      );
    }

    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        debugPrint('🔴 [STARTUP] Supabase initialization timeout after 15s');
        throw TimeoutException(
          'Supabase init timeout - check internet connection',
        );
      },
    );

    supabaseReady = true;

    debugPrint('✅ [STARTUP] Supabase initialized successfully');
  } on TimeoutException catch (e) {
    debugPrint('⚠️ [STARTUP] Supabase initialization timed out: ${e.message}');
    debugPrint('⚠️ [STARTUP] Continuing anyway');
  } catch (e) {
    debugPrint('⚠️ [STARTUP] Supabase initialization error: $e');
    debugPrint('⚠️ [STARTUP] Continuing anyway');
  }

  // ------------------------------------------------------------
  // DEPENDENCY INJECTION
  // ------------------------------------------------------------
  debugPrint('🟡 [STARTUP] Setting up dependency injection...');

  injectionSetup();

  debugPrint('✅ [STARTUP] Dependency injection setup complete');

  // ------------------------------------------------------------
  // FIREBASE DEBUGGER
  // ------------------------------------------------------------
  if (kDebugMode) {
    debugPrint('🟡 [STARTUP] Running Firebase diagnostics...');

    try {
      await Future.delayed(
        const Duration(milliseconds: 500),
      );

      await FirebaseDebugger.validateFirebaseSetup();
    } catch (e) {
      debugPrint('⚠️ [STARTUP] Firebase diagnostics failed: $e');
    }
  }

  // ------------------------------------------------------------
  // START APP FIRST
  // ------------------------------------------------------------
  //
  // IMPORTANT:
  // The app is started BEFORE the Supabase version check.
  // This prevents the native splash/logo from being held
  // while waiting for Supabase/network/database operations.
  //
  // ------------------------------------------------------------

  debugPrint('🟢 [STARTUP] Starting app...');

  runApp(const AppWidget());

  // ------------------------------------------------------------
  // FORCE UPDATE CHECK
  // ------------------------------------------------------------
  //
  // This runs AFTER runApp().
  // It can no longer prevent the application from launching.
  //
  // ------------------------------------------------------------

  if (supabaseReady) {
    unawaited(_checkForForcedUpdate());
  } else {
    debugPrint(
      '⚠️ [UPDATE] Supabase unavailable - skipping version check',
    );
  }
}

// ============================================================
// FORCE UPDATE CHECK
// ============================================================

Future<void> _checkForForcedUpdate() async {
  try {
    debugPrint('🟡 [UPDATE] Checking app version...');

    final response = await Supabase.instance.client
        .from('app_release_versions')
        .select('latest_version, minimum_version, apk_url')
        .eq('app_id', kAppId)
        .maybeSingle()
        .timeout(
          const Duration(seconds: 10),
        );

    // No NigerGram release record yet.
    if (response == null) {
      debugPrint(
        'ℹ️ [UPDATE] No release record found for $kAppId',
      );
      return;
    }

    final minimumVersion =
        response['minimum_version']?.toString();

    final apkUrl = response['apk_url']?.toString();

    if (minimumVersion == null || minimumVersion.isEmpty) {
      debugPrint(
        '⚠️ [UPDATE] minimum_version is missing',
      );
      return;
    }

    if (_isOutdated(kCurrentVersion, minimumVersion)) {
      debugPrint(
        '🔴 [UPDATE] Forced update required',
      );

      if (apkUrl == null || apkUrl.isEmpty) {
        debugPrint(
          '🔴 [UPDATE] Update required but apk_url is missing',
        );
        return;
      }

      // Show the force-update screen after the main app has already
      // launched.
      _showForceUpdateScreen(apkUrl);
    } else {
      debugPrint(
        '✅ [UPDATE] App version is current',
      );
    }
  } on TimeoutException {
    debugPrint(
      '⚠️ [UPDATE] Version check timed out - allowing app to continue',
    );
  } catch (e) {
    debugPrint(
      '⚠️ [UPDATE] Version check failed - allowing app to continue: $e',
    );
  }
}

// ============================================================
// SHOW FORCE UPDATE SCREEN
// ============================================================

void _showForceUpdateScreen(String apkUrl) {
  final navigatorKey = AppWidget.navigatorKey;

  final context = navigatorKey.currentContext;

  if (context == null) {
    debugPrint(
      '⚠️ [UPDATE] Navigator context unavailable',
    );
    return;
  }

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => _ForceUpdateApp(
        apkUrl: apkUrl,
      ),
    ),
    (route) => false,
  );
}

// ============================================================
// VERSION COMPARISON
// ============================================================

bool _isOutdated(String current, String minimum) {
  final c = _parseVersion(current);
  final m = _parseVersion(minimum);

  final len = c.length > m.length ? c.length : m.length;

  for (var i = 0; i < len; i++) {
    final cv = i < c.length ? c[i] : 0;
    final mv = i < m.length ? m[i] : 0;

    if (cv != mv) {
      return cv < mv;
    }
  }

  return false;
}

List<int> _parseVersion(String version) {
  return version
      .split('.')
      .map((part) => int.tryParse(part) ?? 0)
      .toList();
}

// ============================================================
// FORCE UPDATE SCREEN
// ============================================================

class _ForceUpdateApp extends StatelessWidget {
  final String apkUrl;

  const _ForceUpdateApp({
    required this.apkUrl,
  });

  Future<void> _openUpdate() async {
    final uri = Uri.tryParse(apkUrl);

    if (uri == null) {
      return;
    }

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.system_update,
                  size: 64,
                ),

                const SizedBox(height: 24),

                const Text(
                  'Update Required',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                const Text(
                  'A newer version of NigerGram is required to continue.',
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _openUpdate,
                  child: const Text(
                    'Update NigerGram',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
