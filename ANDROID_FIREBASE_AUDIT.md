# 🔍 Android APK Firebase/Supabase Hang Audit

## Executive Summary

**Status:** ⚠️ **CRITICAL** - APK builds successfully but hangs indefinitely on login/registration Firebase calls.

**Root Causes Identified:**
1. ❌ No timeout handling on Firebase/Supabase operations
2. ❌ Supabase initialization happens **before** network state verification
3. ❌ Network operations are not bounded by timeouts
4. ❌ No retry logic or fallback mechanisms
5. ❌ Missing Android network security configuration
6. ❌ No diagnostics/logging to identify the hang source

---

## 🔴 Critical Issues Found

### 1. **No Timeout on Firebase Auth Operations** (HIGHEST PRIORITY)

**File:** `lib/features/auth/presentation/bloc/auth_cubit.dart` (Lines 20-43)

```dart
// ❌ PROBLEM: No timeout - will wait forever if Firebase is unresponsive
await _auth.signInWithEmailAndPassword(
  email: email,
  password: password,
);
```

**Impact:** When Firebase credentials are incorrect, network is flaky, or the project isn't configured properly, this call hangs indefinitely.

**Solution:**
```dart
// ✅ FIXED: Add timeout
try {
  await _auth.signInWithEmailAndPassword(
    email: email,
    password: password,
  ).timeout(
    const Duration(seconds: 15),
    onTimeout: () => throw TimeoutException('Firebase auth timeout after 15s'),
  );
} on TimeoutException catch (e) {
  emit(AuthError('Connection timeout: ${e.message}. Check your internet connection.'));
  return;
}
```

---

### 2. **Supabase Initialization Has No Error Handling**

**File:** `lib/main.dart` (Lines 12-15)

```dart
// ❌ PROBLEM: Supabase initialization has NO try-catch
// If Supabase URL/keys are wrong, app crashes silently or hangs
await Supabase.initialize(
  url: 'https://ssmwuihkafrulmvtiuam.supabase.co',
  anonKey: '...',
);
```

**Impact:** 
- Invalid credentials hang indefinitely
- No error message to user
- App appears frozen on startup

**Solution:**
```dart
// ✅ FIXED: Add error handling
try {
  await Supabase.initialize(
    url: 'https://ssmwuihkafrulmvtiuam.supabase.co',
    anonKey: '...',
  ).timeout(
    const Duration(seconds: 10),
    onTimeout: () => throw TimeoutException('Supabase init timeout'),
  );
} catch (e) {
  debugPrint('⚠️ Supabase initialization error: $e');
  // Continue app - Supabase is optional for core features
}
```

---

### 3. **Race Condition: Supabase Called Before Firebase Ready**

**File:** `lib/main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase initialization
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Supabase init (not awaited properly, no timeout)
  await Supabase.initialize(...);

  injectionSetup();  // ← Runs immediately

  runApp(const AppWidget());
}
```

**Problem:**
- Supabase credentials could be invalid
- Initialization fails silently
- Auth calls later expect Supabase to be ready

---

### 4. **Dual Auth System Without Proper Sync**

**File:** `lib/features/auth/presentation/bloc/auth_cubit.dart` (Lines 62-76)

```dart
Future<void> _signInToSupabase(String email, String password) async {
  try {
    await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  } catch (e) {
    try {
      // ❌ PROBLEM: Silent fallback to signup - credentials might be wrong
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
    } catch (_) {}  // ❌ Silent failure - no logging!
  }
}
```

**Issues:**
- No timeout on Supabase calls
- Empty catch block hides real errors
- Sign-up fallback could fail silently
- **Method is not awaited in `login()`** - authentication succeeds even if Supabase fails

---

### 5. **Firebase Options May Be Invalid for Fork**

**File:** `lib/firebase_options.dart`

```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'AIzaSyCLcQqsHrq9O0sMKAs5g1hdv7KqzvEb4zo',
  appId: '1:378525386177:android:487545170906c572c5db40',
  messagingSenderId: '378525386177',
  projectId: 'nigergram',
  storageBucket: 'nigergram.firebasestorage.app',
);
```

⚠️ **CRITICAL:** This Firebase project might not exist or these credentials could be:
- From the **original repository** (alperefesahin/flutter_video_feed)
- Invalid for YOUR fork
- Missing google-services.json at build time

**Check:** Does your `android/app/google-services.json` match this configuration?

---

### 6. **Missing Network Security Configuration**

**File:** `android/app/src/main/AndroidManifest.xml`

**Problem:** No `android:networkSecurityConfig` attribute

```xml
<!-- ❌ Missing network security configuration -->
<application
    android:label="NigerGram"
    android:name="${applicationName}"
    ...
>
```

**This could cause:**
- Certificate pinning failures
- TLS/SSL handshake timeouts
- Silent network drops

---

### 7. **Build Workflow Injects Credentials at Build Time** ⚠️

**File:** `.github/workflows/build.yml` (Line 28-30)

```yaml
- name: Inject google-services.json
  run: |
    echo '${{ secrets.GOOGLE_SERVICES_JSON }}' > android/app/google-services.json
```

**Issues:**
1. ✅ Good: Secrets are injected
2. ❌ **Problem:** If the secret is missing or malformed, build succeeds but app hangs at runtime
3. ❌ No validation that JSON is valid

---

### 8. **No Logging/Diagnostics**

**Missing:** All Firebase/Supabase calls lack diagnostic logging

When the app hangs, **there's no way to know WHY**:
- Is it Firebase timeout?
- Is it Supabase?
- Is it network?
- Is it wrong credentials?

---

## 🚀 Immediate Fixes (Priority Order)

### Fix #1: Add Timeouts to All Firebase Auth Calls

**File:** `lib/features/auth/presentation/bloc/auth_cubit.dart`

```dart
import 'dart:async';

class AuthCubit extends Cubit<AuthState> {
  static const _authTimeoutDuration = Duration(seconds: 15);

  Future<void> register(String email, String password) async {
    emit(AuthLoading());
    try {
      // ✅ FIXED: Add timeout
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      ).timeout(
        _authTimeoutDuration,
        onTimeout: () => throw TimeoutException(
          'Registration timeout: Please check your internet connection',
        ),
      );

      final firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        final String baseHandle = email
            .split('@')
            .first
            .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');

        // ✅ FIXED: Add timeout to Firestore write
        await _firestore.collection('users').doc(firebaseUser.uid).set({
          'uid': firebaseUser.uid,
          'email': email,
          'username': baseHandle,
          'profileImageUrl': '',
          'bio': 'New NigerGram Creator 🇳🇬',
          'followers': 0,
          'following': 0,
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(_authTimeoutDuration);

        // ✅ FIXED: Await Supabase with timeout
        await _signInToSupabase(email, password);
      }

      emit(AuthSuccess());
    } on TimeoutException catch (e) {
      emit(AuthError(e.message ?? 'Operation timed out'));
    } catch (e) {
      debugPrint('🔴 Registration error: $e');
      emit(AuthError(e.toString()));
    }
  }

  Future<void> login(String email, String password) async {
    emit(AuthLoading());
    try {
      // ✅ FIXED: Add timeout
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      ).timeout(
        _authTimeoutDuration,
        onTimeout: () => throw TimeoutException(
          'Login timeout: Please check your internet connection',
        ),
      );
      
      // ✅ FIXED: Await Supabase with proper error handling
      await _signInToSupabase(email, password);
      
      emit(AuthSuccess());
    } on TimeoutException catch (e) {
      emit(AuthError(e.message ?? 'Operation timed out'));
    } catch (e) {
      debugPrint('🔴 Login error: $e');
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _signInToSupabase(String email, String password) async {
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Supabase login timeout'),
      );
      debugPrint('✅ Supabase login successful');
    } catch (e) {
      debugPrint('⚠️ Supabase login failed: $e - Attempting signup');
      try {
        await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        ).timeout(
          Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Supabase signup timeout'),
        );
        debugPrint('✅ Supabase signup successful');
      } catch (signupError) {
        debugPrint('⚠️ Supabase signup also failed: $signupError');
        // Don't re-throw - Supabase is optional
      }
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut().timeout(Duration(seconds: 5));
      await Supabase.instance.client.auth.signOut().timeout(Duration(seconds: 5));
    } catch (e) {
      debugPrint('⚠️ Logout error: $e');
    }
    emit(AuthInitial());
  }
}
```

---

### Fix #2: Add Error Handling to main.dart

**File:** `lib/main.dart`

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:nigergram/core/di/dependency_injector.dart';
import 'package:nigergram/core/init/app_widget.dart';
import 'package:nigergram/firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // ✅ FIXED: Add timeout to Firebase initialization
    debugPrint('🟡 Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw TimeoutException('Firebase init timeout'),
    );
    debugPrint('✅ Firebase initialized');
  } on TimeoutException catch (e) {
    debugPrint('🔴 Firebase initialization timed out: $e');
    // Continue - Firebase may initialize later
  } catch (e) {
    debugPrint('🔴 Firebase initialization error: $e');
    // Continue - app can work offline
  }

  try {
    // ✅ FIXED: Add timeout and error handling to Supabase
    debugPrint('🟡 Initializing Supabase...');
    await Supabase.initialize(
      url: 'https://ssmwuihkafrulmvtiuam.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNzbXd1aWhrYWZydWxtdnRpdWFtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA4Mjk2NjAsImV4cCI6MjA5NjQwNTY2MH0.e1PxmDW77ZhbonS-Z96SWA_sPyVGedzpZNZbJQz7pQo',
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException('Supabase init timeout'),
    );
    debugPrint('✅ Supabase initialized');
  } on TimeoutException catch (e) {
    debugPrint('⚠�� Supabase initialization timed out: $e');
    // Supabase is optional - video feed works without it
  } catch (e) {
    debugPrint('⚠️ Supabase initialization error: $e');
    // Supabase is optional - video feed works without it
  }

  injectionSetup();

  runApp(const AppWidget());
}
```

---

### Fix #3: Add Network Security Configuration

**Create:** `android/app/src/main/res/xml/network_security_config.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- ✅ Allow cleartext traffic for development (REMOVE IN PRODUCTION) -->
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">10.0.2.2</domain>
        <domain includeSubdomains="true">localhost</domain>
    </domain-config>
    
    <!-- Firebase + Supabase require HTTPS -->
    <domain-config>
        <domain includeSubdomains="true">googleapis.com</domain>
        <domain includeSubdomains="true">supabase.co</domain>
        <domain includeSubdomains="true">firebasestorage.googleapis.com</domain>
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </domain-config>
</network-security-config>
```

**Update:** `android/app/src/main/AndroidManifest.xml`

```xml
<application
    android:label="NigerGram"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher"
    android:largeHeap="true"
    android:requestLegacyExternalStorage="true"
    android:networkSecurityConfig="@xml/network_security_config"
>
```

---

### Fix #4: Validate Firebase Configuration

**Create:** `lib/core/utils/debug/firebase_debugger.dart`

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FirebaseDebugger {
  static Future<void> validateFirebaseSetup() async {
    debugPrint('=== Firebase Configuration Debug ===');
    
    try {
      // Check Firebase instance
      final app = Firebase.app();
      debugPrint('✅ Firebase App: ${app.name}');
    } catch (e) {
      debugPrint('🔴 Firebase App Error: $e');
      return;
    }

    try {
      // Check Firestore connectivity
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('_health_check').doc('test').set({
        'timestamp': DateTime.now().toIso8601String(),
      }).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Firestore timeout'),
      );
      debugPrint('✅ Firestore: Connected');
      
      await firestore.collection('_health_check').doc('test').delete();
    } on TimeoutException {
      debugPrint('🔴 Firestore: Timeout (network issue?)');
    } catch (e) {
      debugPrint('🔴 Firestore: $e');
    }

    try {
      // Check Auth
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      debugPrint('✅ Firebase Auth: ${user != null ? 'Logged in' : 'Not logged in'}');
    } catch (e) {
      debugPrint('🔴 Firebase Auth: $e');
    }
  }
}
```

**Call in main.dart after initialization:**

```dart
import 'package:nigergram/core/utils/debug/firebase_debugger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ... Firebase init ...

  if (kDebugMode) {
    await FirebaseDebugger.validateFirebaseSetup();
  }

  // ... rest of main ...
}
```

---

### Fix #5: Verify google-services.json

**Check list:**
1. Does `android/app/google-services.json` exist locally?
2. Does its `project_id` match `nigergram` in `lib/firebase_options.dart`?
3. Does its `client > android_client_info > package_name` match `com.nigergram.app`?

**Example valid google-services.json structure:**
```json
{
  "type": "service_account",
  "project_id": "nigergram",
  "private_key_id": "...",
  "private_key": "...",
  "client_email": "firebase-adminsdk-...",
  "client_id": "...",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "..."
}
```

---

## 🧪 Testing the Fix

### Test 1: Timeout Handling
```dart
// Try login with invalid credentials
// Expected: "Operation timed out" error after 15s (not forever)
```

### Test 2: Firebase Connectivity
```dart
// Run the debug validator
// Look for ✅ or 🔴 indicators in console
```

### Test 3: Build APK with Valid Credentials
```bash
# Ensure google-services.json is valid before building
flutter build apk --debug --no-tree-shake-icons
```

---

## ✅ Checklist for Complete Fix

- [ ] Add timeouts to `auth_cubit.dart` (Fix #1)
- [ ] Update `main.dart` with error handling (Fix #2)
- [ ] Create `network_security_config.xml` (Fix #3)
- [ ] Update `AndroidManifest.xml` (Fix #3)
- [ ] Verify `firebase_options.dart` matches your Firebase project
- [ ] Ensure `android/app/google-services.json` exists and is valid
- [ ] Create Firebase debugger utility (Fix #4)
- [ ] Run validator to check Firebase setup
- [ ] Test login with timeout handling
- [ ] Rebuild APK and test on device

---

## 📋 Why APK Builds Succeed But Hangs at Runtime

1. **Build time:** No network calls - just compiles code ✅
2. **Runtime:** Firebase/Supabase calls have NO TIMEOUTS ❌
3. **Result:** App appears to hang indefinitely when credentials are invalid or network is unreliable

---

## 🔗 References

- [Firebase Auth Timeouts](https://firebase.google.com/docs/auth/errors)
- [Supabase Flutter Guide](https://supabase.com/docs/guides/getting-started/quickstarts/flutter)
- [Android Network Security Config](https://developer.android.com/training/articles/security-config)

---

**Last Updated:** 2026-06-12  
**Status:** Ready for implementation
