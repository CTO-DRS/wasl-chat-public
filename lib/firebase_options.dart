// إعدادات Firebase لمشروع wasl-chat-7430e (أندرويد).
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError('Firebase مُعدّ لأندرويد فقط حالياً');
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBkkTOmErvw-X-0tASYPZSwPZQF4TKCD8E',
    appId: '1:217684408888:android:a5123f13d3363e328ac4cd',
    messagingSenderId: '217684408888',
    projectId: 'wasl-chat-7430e',
    storageBucket: 'wasl-chat-7430e.firebasestorage.app',
  );
}
