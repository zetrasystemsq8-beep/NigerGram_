*** Begin Patch
*** Update File: lib/features/wallet/presentation/view/buy_cent_view.dart
@@
-import 'package:firebase_auth/firebase_auth.dart';
+import 'package:firebase_auth/firebase_auth.dart';
+import 'package:supabase_flutter/supabase_flutter.dart';
@@
-  Future<String> _idToken() async {
-    final user = FirebaseAuth.instance.currentUser;
-    if (user == null) throw Exception('Not authenticated');
-    final token = await user.getIdToken(true);
-    if (token == null) throw Exception('Failed to obtain ID token');
-    return token;
-  }
+  Future<String> _idToken() async {
+    // Prefer Supabase session access token (app uses Supabase for auth).
+    try {
+      final supaToken = Supabase.instance.client.auth.currentSession?.accessToken;
+      if (supaToken != null && supaToken.isNotEmpty) return supaToken;
+    } catch (_) {
+      // ignore and fallback
+    }
+
+    // Fallback to Firebase token for environments that still use Firebase
+    final user = FirebaseAuth.instance.currentUser;
+    if (user != null) {
+      final token = await user.getIdToken(true);
+      if (token != null && token.isNotEmpty) return token;
+    }
+
+    throw Exception('Not authenticated');
+  }
*** End Patch
