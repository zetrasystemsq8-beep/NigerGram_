# 🔧 Firebase Configuration Fix Guide - NigerGram

## 🔴 **THE ROOT CAUSE OF YOUR TIMEOUT ERROR**

Your app times out after 15 seconds because:

1. ❌ `android/app/google-services.json` is **MISSING**
2. ❌ `lib/firebase_options.dart` has **WRONG credentials** (from the original fork)
3. ❌ Firebase cannot connect to your actual Firebase project

---

## ✅ **STEP-BY-STEP FIX (15 minutes)**

### **STEP 1: Get Your Firebase Credentials**

1. Go to **Firebase Console**: https://console.firebase.google.com/
2. Select your **nigergram** project
3. Click **⚙️ Project Settings** (top left)
4. Go to **Service Accounts** tab
5. Click **Generate New Private Key** (generates `google-services.json`)
6. Save the file - you need the values from it

---

### **STEP 2: Create `android/app/google-services.json`**

Create a new file at: `android/app/google-services.json`

**Paste this template and fill in YOUR values from the JSON file:**

```json
{
  "project_info": {
    "project_number": "YOUR_PROJECT_NUMBER",
    "project_id": "nigergram",
    "storage_bucket": "nigergram.firebasestorage.app"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:YOUR_PROJECT_NUMBER:android:YOUR_APP_ID_HERE",
        "android_client_info": {
          "package_name": "com.nigergram.app"
        }
      },
      "api_key": [
        {
          "current_key": "YOUR_API_KEY_HERE"
        }
      ],
      "services": {
        "appinvite_service": {
          "other_platform_oauth_client": []
        }
      }
    }
  ]
}
```

**Where to find the values in Firebase Console:**

- `YOUR_PROJECT_NUMBER` → Found in Project Settings (e.g., `378525386177`)
- `YOUR_APP_ID_HERE` → Android App ID from Firebase (e.g., `487545170906c572c5db40`)
- `YOUR_API_KEY_HERE` → Android API Key from Firebase Console

**Alternative: Download the official file:**
1. In Firebase Console, go to **Project Settings**
2. Under "Your apps" → Select "Android" app
3. Click "Download google-services.json"
4. Copy that entire file to `android/app/google-services.json`

---

### **STEP 3: Update `lib/firebase_options.dart`**

Replace the hardcoded values with YOUR actual credentials:

```dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not supported');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Platform not supported');
    }
  }

  // ✅ REPLACE THESE VALUES WITH YOUR FIREBASE CREDENTIALS
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_API_KEY_FROM_google_services_json',  // ← CHANGE THIS
    appId: '1:YOUR_PROJECT_NUMBER:android:YOUR_APP_ID',  // ← CHANGE THIS
    messagingSenderId: 'YOUR_PROJECT_NUMBER',  // ← CHANGE THIS
    projectId: 'nigergram',  // ✅ This is correct
    storageBucket: 'nigergram.firebasestorage.app',  // ✅ This is correct
  );
}
```

**Example of CORRECT values:**

```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'AIzaSyCLcQqsHrq9O0sMKAs5g1hdv7KqzvEb4zo',
  appId: '1:378525386177:android:487545170906c572c5db40',
  messagingSenderId: '378525386177',
  projectId: 'nigergram',
  storageBucket: 'nigergram.firebasestorage.app',
);
```

---

### **STEP 4: Verify Android Configuration**

**Check:** `android/app/build.gradle.kts` (should already be correct)

✅ **Line 32:** `applicationId = "com.nigergram.app"` — **CORRECT**
✅ **Line 3:** `id("com.google.gms.google-services")` — **CORRECT**

---

### **STEP 5: Configure GitHub Secrets (for CI/CD)**

The `.github/workflows/build.yml` injects `google-services.json` at build time.

1. Go to your GitHub repo → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Name: `GOOGLE_SERVICES_JSON`
4. Value: Copy the entire contents of your `android/app/google-services.json` file
5. Click **Add secret**

---

## 🧪 **VERIFICATION CHECKLIST**

Before rebuilding:

- [ ] ✅ `applicationId` in `android/app/build.gradle.kts` = `"com.nigergram.app"`
- [ ] ✅ `package_name` in `android/app/google-services.json` = `"com.nigergram.app"`
- [ ] ✅ `apiKey` in `lib/firebase_options.dart` matches your Firebase credentials
- [ ] ✅ `appId` in `lib/firebase_options.dart` matches your Firebase app ID
- [ ] ✅ `projectId` in both files = `"nigergram"`
- [ ] ✅ Google Services plugin applied in `android/app/build.gradle.kts` line 3
- [ ] ✅ `android/app/google-services.json` file exists locally

---

## 🚀 **REBUILD AND TEST**

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Rebuild APK
flutter build apk --debug --no-tree-shake-icons
```

**Test on device:**
1. Try login with **WRONG password** → Should show error after 15s ✅
2. Try login with **CORRECT credentials** → Should log in successfully ✅
3. Check **Android Logcat** for diagnostic messages (look for `[STARTUP]` prefix)

---

## 📋 **DIAGNOSTIC MESSAGES TO EXPECT**

When app starts on debug mode, you should see in Android Logcat:

```
✅ [STARTUP] Firebase initialized successfully
✅ [STARTUP] Supabase initialized successfully
✅ [STARTUP] Dependency injection setup complete
✅ [STARTUP] Running Firebase diagnostics...
✅ Firebase App: [DEFAULT] (initialized)
✅ Firestore: Connected and writable
✅ Firebase Auth: Not logged in (normal on startup)
```

**If you see red errors (🔴), that means the credentials are still wrong.**

---

## 🔗 **HOW THE FIX WORKS**

### **Before (Broken):**
```
App starts
  ↓
Firebase.initializeApp() called with WRONG credentials (from old fork)
  ↓
Firebase rejects connection
  ↓
App waits 15 seconds for response
  ↓
Timeout error: "Connection Timeout: Firebase login connection timed out"
```

### **After (Fixed):**
```
App starts
  ↓
Firebase.initializeApp() called with YOUR correct credentials
  ↓
Firebase connects successfully in <1 second
  ↓
User can login/register normally
```

---

## ⚠️ **IMPORTANT NOTES**

1. **Don't commit `google-services.json` with real API keys** to public repos
   - GitHub Actions uses the secret instead
   - Only keep it locally for development

2. **Each Firebase project has unique credentials**
   - If you're using a different Firebase project, get NEW credentials
   - Don't use credentials from the original fork

3. **The credentials must match the package name**
   - Firebase only accepts auth from `com.nigergram.app`
   - If package name is different, update it in both places

---

## 🆘 **STILL NOT WORKING?**

If you still get timeout errors:

1. Check Logcat output for exact error message
2. Run: `FirebaseDebugger.validateFirebaseSetup()` (already runs on debug mode)
3. Verify all 3 values match exactly (apiKey, appId, messagingSenderId)
4. Try different Firebase project credentials
5. Clear app cache: `Settings → Apps → NigerGram → Storage → Clear Cache`

---

## 📞 **GETTING HELP**

Share the diagnostic output from Logcat (with [STARTUP] prefix) and I can identify the exact issue.

---

**Status: Ready to implement** ✅
