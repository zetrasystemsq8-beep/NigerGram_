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
        debugPrint(
          '🔴 [STARTUP] Firebase initialization timeout after 20s',
        );

        throw TimeoutException(
          'Firebase init timeout',
        );
      },
    );

    debugPrint('✅ [STARTUP] Firebase initialized successfully');

    // Only configure persistence.
    // Do NOT disable and re-enable Firestore during startup.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );

    debugPrint(
      '✅ [STARTUP] Firestore persistence configured',
    );
  } on TimeoutException catch (e) {
    debugPrint(
      '🔴 [STARTUP] Firebase timeout: ${e.message}',
    );
  } catch (e) {
    debugPrint(
      '🔴 [STARTUP] Firebase error: $e',
    );
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
        throw TimeoutException(
          'Supabase initialization timeout',
        );
      },
    );

    supabaseReady = true;

    debugPrint(
      '✅ [STARTUP] Supabase initialized successfully',
    );
  } on TimeoutException catch (e) {
    debugPrint(
      '⚠️ [STARTUP] Supabase timeout: ${e.message}',
    );
  } catch (e) {
    debugPrint(
      '⚠️ [STARTUP] Supabase initialization error: $e',
    );
  }

  // ------------------------------------------------------------
  // DEPENDENCY INJECTION
  // ------------------------------------------------------------

  debugPrint(
    '🟡 [STARTUP] Setting up dependency injection...',
  );

  injectionSetup();

  debugPrint(
    '✅ [STARTUP] Dependency injection setup complete',
  );

  // ------------------------------------------------------------
  // FIREBASE DEBUGGER
  // ------------------------------------------------------------

  if (kDebugMode) {
    try {
      debugPrint(
        '🟡 [STARTUP] Running Firebase diagnostics...',
      );

      await Future.delayed(
        const Duration(milliseconds: 500),
      );

      await FirebaseDebugger.validateFirebaseSetup();
    } catch (e) {
      debugPrint(
        '⚠️ [STARTUP] Firebase diagnostics failed: $e',
      );
    }
  }

  // ------------------------------------------------------------
  // START APP IMMEDIATELY
  // ------------------------------------------------------------

  debugPrint(
    '🟢 [STARTUP] Starting NigerGram...',
  );

  runApp(
    _NigerGramStartup(
      supabaseReady: supabaseReady,
    ),
  );
}

// ============================================================
// STARTUP WIDGET
// ============================================================

class _NigerGramStartup extends StatefulWidget {
  final bool supabaseReady;

  const _NigerGramStartup({
    required this.supabaseReady,
  });

  @override
  State<_NigerGramStartup> createState() =>
      _NigerGramStartupState();
}

class _NigerGramStartupState
    extends State<_NigerGramStartup> {
  bool _checkingUpdate = true;
  String? _forceUpdateUrl;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdate();
    });
  }

  Future<void> _checkForUpdate() async {
    if (!widget.supabaseReady) {
      if (mounted) {
        setState(() {
          _checkingUpdate = false;
        });
      }

      return;
    }

    try {
      debugPrint(
        '🟡 [UPDATE] Checking NigerGram version...',
      );

      final update = await Supabase.instance.client
          .from('app_release_versions')
          .select(
            'latest_version, minimum_version, apk_url',
          )
          .eq('app_id', kAppId)
          .maybeSingle()
          .timeout(
            const Duration(seconds: 10),
          );

      if (update == null) {
        debugPrint(
          'ℹ️ [UPDATE] No NigerGram release record found',
        );

        if (mounted) {
          setState(() {
            _checkingUpdate = false;
          });
        }

        return;
      }

      final minimumVersion =
          update['minimum_version']?.toString();

      final apkUrl =
          update['apk_url']?.toString();

      if (minimumVersion == null ||
          minimumVersion.isEmpty) {
        debugPrint(
          '⚠️ [UPDATE] No minimum version configured',
        );

        if (mounted) {
          setState(() {
            _checkingUpdate = false;
          });
        }

        return;
      }

      if (_isOutdated(
        kCurrentVersion,
        minimumVersion,
      )) {
        debugPrint(
          '🔴 [UPDATE] Forced update required',
        );

        if (apkUrl != null && apkUrl.isNotEmpty) {
          if (mounted) {
            setState(() {
              _forceUpdateUrl = apkUrl;
              _checkingUpdate = false;
            });
          }

          return;
        }
      }

      debugPrint(
        '✅ [UPDATE] NigerGram version is current',
      );
    } on TimeoutException {
      debugPrint(
        '⚠️ [UPDATE] Version check timed out',
      );
    } catch (e) {
      debugPrint(
        '⚠️ [UPDATE] Version check failed: $e',
      );
    }

    if (mounted) {
      setState(() {
        _checkingUpdate = false;
      });
    }
  }

  bool _isOutdated(
    String current,
    String minimum,
  ) {
    final currentParts = _parseVersion(current);
    final minimumParts = _parseVersion(minimum);

    final length = currentParts.length >
            minimumParts.length
        ? currentParts.length
        : minimumParts.length;

    for (var i = 0; i < length; i++) {
      final currentValue =
          i < currentParts.length
              ? currentParts[i]
              : 0;

      final minimumValue =
          i < minimumParts.length
              ? minimumParts[i]
              : 0;

      if (currentValue != minimumValue) {
        return currentValue < minimumValue;
      }
    }

    return false;
  }

  List<int> _parseVersion(String version) {
    return version
        .split('.')
        .map(
          (part) => int.tryParse(part) ?? 0,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const AppWidget(),

        if (_checkingUpdate)
          const SizedBox.shrink(),

        if (_forceUpdateUrl != null)
          Positioned.fill(
            child: _ForceUpdateOverlay(
              apkUrl: _forceUpdateUrl!,
            ),
          ),
      ],
    );
  }
}

// ============================================================
// FORCE UPDATE OVERLAY
// ============================================================

class _ForceUpdateOverlay extends StatelessWidget {
  final String apkUrl;

  const _ForceUpdateOverlay({
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
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.system_update,
                  size: 64,
                  color: Colors.white,
                ),

                const SizedBox(height: 24),

                const Text(
                  'Update Required',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                const Text(
                  'A newer version of NigerGram is required to continue.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
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
