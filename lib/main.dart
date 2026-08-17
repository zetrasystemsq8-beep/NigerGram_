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

    debugPrint('🟡 [STARTUP] Enabling Firestore offline persistence...');
    await FirebaseFirestore.instance.disableNetwork();
    await FirebaseFirestore.instance.enableNetwork();
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
    debugPrint('✅ [STARTUP] Firestore offline persistence enabled - app will work offline');
  } on TimeoutException catch (e) {
    debugPrint('🔴 [STARTUP] Firebase initialization timed out: ${e.message}');
    debugPrint('⚠️ [STARTUP] Continuing anyway - Firebase may initialize later');
  } catch (e) {
    debugPrint('🔴 [STARTUP] Firebase initialization error: $e');
    debugPrint('⚠️ [STARTUP] Continuing anyway - app can work offline');
  }

  try {
    debugPrint('🟡 [STARTUP] Initializing Supabase...');
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      throw Exception('Supabase credentials not provided at build time');
    }
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
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

  if (kDebugMode) {
    debugPrint('🟡 [STARTUP] Running Firebase diagnostics...');
    await Future.delayed(const Duration(milliseconds: 500));
    await FirebaseDebugger.validateFirebaseSetup();
  }

  String? forceUpdateUrl;
  try {
    debugPrint('🟡 [STARTUP] Checking app version...');
    final update = await Supabase.instance.client
        .from('app_release_versions')
        .select()
        .eq('app_id', kAppId)
        .single();

    if (_isOutdated(kCurrentVersion, update['minimum_version'] as String)) {
      forceUpdateUrl = update['apk_url'] as String;
      debugPrint('🔴 [STARTUP] App is outdated, blocking launch');
    } else {
      debugPrint('✅ [STARTUP] App version is current');
    }
  } catch (e) {
    debugPrint('⚠️ [STARTUP] Version check failed, continuing anyway: $e');
  }

  if (forceUpdateUrl != null) {
    runApp(_ForceUpdateApp(apkUrl: forceUpdateUrl));
    return;
  }

  debugPrint('🟡 [STARTUP] Starting app...');
  runApp(const AppWidget());
}

bool _isOutdated(String current, String minimum) {
  List<int> parse(String v) =>
      v.split('.').map((p) => int.tryParse(p) ?? 0).toList();

  final c = parse(current);
  final m = parse(minimum);
  final len = c.length > m.length ? c.length : m.length;

  for (var i = 0; i < len; i++) {
    final cv = i < c.length ? c[i] : 0;
    final mv = i < m.length ? m[i] : 0;
    if (cv != mv) return cv < mv;
  }
  return false;
}

class _ForceUpdateApp extends StatelessWidget {
  final String apkUrl;
  const _ForceUpdateApp({required this.apkUrl});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'A new version of this app is required to continue.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => launchUrl(
                    Uri.parse(apkUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('Update Required'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
