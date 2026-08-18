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

  // Wrapped in try/catch now too — the only previously-unguarded step
  // before runApp(). If this ever throws, we still reach runApp().
  try {
    debugPrint('🟡 [STARTUP] Setting up dependency injection...');
    injectionSetup();
    debugPrint('✅ [STARTUP] Dependency injection setup complete');
  } catch (e) {
    debugPrint('🔴 [STARTUP] Dependency injection failed: $e');
    debugPrint('⚠️ [STARTUP] Continuing anyway - app may have reduced functionality');
  }

  if (kDebugMode) {
    try {
      debugPrint('🟡 [STARTUP] Running Firebase diagnostics...');
      await Future.delayed(const Duration(milliseconds: 500));
      await FirebaseDebugger.validateFirebaseSetup();
    } catch (e) {
      debugPrint('⚠️ [STARTUP] Firebase diagnostics failed: $e');
    }
  }

  debugPrint('🟡 [STARTUP] Starting app...');
  runApp(const _NigerGramUpdateWrapper());
}

// ============================================================
// UPDATE WRAPPER
// ============================================================

class _NigerGramUpdateWrapper extends StatefulWidget {
  const _NigerGramUpdateWrapper();

  @override
  State<_NigerGramUpdateWrapper> createState() => _NigerGramUpdateWrapperState();
}

class _NigerGramUpdateWrapperState extends State<_NigerGramUpdateWrapper> {
  String? _apkUrl;
  bool _forceUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVersion();
    });
  }

  Future<void> _checkVersion() async {
    try {
      debugPrint('🟡 [UPDATE] Checking NigerGram version...');

      final result = await Supabase.instance.client
          .from('app_release_versions')
          .select('latest_version, minimum_version, apk_url')
          .eq('app_id', kAppId)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (result == null) {
        debugPrint('ℹ️ [UPDATE] No NigerGram release record found.');
        return;
      }

      final minimumVersion = result['minimum_version']?.toString();
      final apkUrl = result['apk_url']?.toString();

      if (minimumVersion == null || minimumVersion.isEmpty) {
        debugPrint('⚠️ [UPDATE] minimum_version is missing.');
        return;
      }

      if (_isOutdated(kCurrentVersion, minimumVersion)) {
        if (apkUrl == null || apkUrl.isEmpty) {
          debugPrint('⚠️ [UPDATE] App outdated but apk_url is missing.');
          return;
        }

        debugPrint('🔴 [UPDATE] Forced update required.');

        if (mounted) {
          setState(() {
            _apkUrl = apkUrl;
            _forceUpdate = true;
          });
        }
      } else {
        debugPrint('✅ [UPDATE] NigerGram version is current.');
      }
    } catch (e) {
      debugPrint('⚠️ [UPDATE] Version check failed. Continuing normally: $e');
    }
  }

  bool _isOutdated(String current, String minimum) {
    final currentParts = _parseVersion(current);
    final minimumParts = _parseVersion(minimum);

    final length = currentParts.length > minimumParts.length ? currentParts.length : minimumParts.length;

    for (var i = 0; i < length; i++) {
      final currentValue = i < currentParts.length ? currentParts[i] : 0;
      final minimumValue = i < minimumParts.length ? minimumParts[i] : 0;

      if (currentValue != minimumValue) {
        return currentValue < minimumValue;
      }
    }

    return false;
  }

  List<int> _parseVersion(String version) {
    return version.split('.').map((part) => int.tryParse(part) ?? 0).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const AppWidget(),
        if (_forceUpdate && _apkUrl != null)
          Positioned.fill(
            child: _ForceUpdateScreen(apkUrl: _apkUrl!),
          ),
      ],
    );
  }
}

// ============================================================
// FORCE UPDATE SCREEN
// ============================================================

class _ForceUpdateScreen extends StatelessWidget {
  final String apkUrl;

  const _ForceUpdateScreen({required this.apkUrl});

  Future<void> _openUpdate() async {
    final uri = Uri.tryParse(apkUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.system_update, color: Colors.white, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Update Required',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'A newer version of NigerGram is required to continue.',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _openUpdate,
                  child: const Text('Update NigerGram'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
