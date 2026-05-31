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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCLcQqsHrq9O0sMKAs5g1hdv7KqzvEb4zo',
    appId: '1:378525386177:android:487545170906c572c5db40',
    messagingSenderId: '378525386177',
    projectId: 'nigergram',
    storageBucket: 'nigergram.firebasestorage.app',
  );
}
