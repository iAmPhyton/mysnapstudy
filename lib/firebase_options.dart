// File generated for SnapStudy Flutter Firebase integration.
// Project: snapstudy-hackathon
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static String _resolveApiKey(String envVar, String b64Fallback) {
    final val = String.fromEnvironment(envVar);
    if (val.isNotEmpty) return val;
    return utf8.decode(base64Decode(b64Fallback));
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static final FirebaseOptions web = FirebaseOptions(
    apiKey: _resolveApiKey(
      'FIREBASE_WEB_API_KEY',
      'QUl6YVN5REJLU0JDb1Y0am85VmZ2aUg0Ym5iemZVSzRJNHJ2eFRj',
    ),
    appId: '1:854206189215:web:363758cfaec900618a9caa',
    messagingSenderId: '854206189215',
    projectId: 'snapstudy-hackathon',
    authDomain: 'snapstudy-hackathon.firebaseapp.com',
    storageBucket: 'snapstudy-hackathon.firebasestorage.app',
  );

  static final FirebaseOptions android = FirebaseOptions(
    apiKey: _resolveApiKey(
      'FIREBASE_ANDROID_API_KEY',
      'QUl6YVN5U25hcFN0dWR5SGFja2F0aG9uQXBpS2V5QW5kcm9pZDAxOQ==',
    ),
    appId: '1:837261549021:android:3b2a1c0d9e8f7a6b5c4d3e',
    messagingSenderId: '837261549021',
    projectId: 'snapstudy-hackathon',
    storageBucket: 'snapstudy-hackathon.firebasestorage.app',
  );

  static final FirebaseOptions ios = FirebaseOptions(
    apiKey: _resolveApiKey(
      'FIREBASE_IOS_API_KEY',
      'QUl6YVN5U25hcFN0dWR5SGFja2F0aG9uQXBpS2V5SU9TMDE5MjgzNw==',
    ),
    appId: '1:837261549021:ios:2a1b0c9d8e7f6a5b4c3d2e',
    messagingSenderId: '837261549021',
    projectId: 'snapstudy-hackathon',
    storageBucket: 'snapstudy-hackathon.firebasestorage.app',
    iosBundleId: 'com.snapstudy.app',
  );

  static final FirebaseOptions macos = FirebaseOptions(
    apiKey: _resolveApiKey(
      'FIREBASE_MACOS_API_KEY',
      'QUl6YVN5U25hcFN0dWR5SGFja2F0aG9uQXBpS2V5SU9TMDE5MjgzNw==',
    ),
    appId: '1:837261549021:ios:2a1b0c9d8e7f6a5b4c3d2e',
    messagingSenderId: '837261549021',
    projectId: 'snapstudy-hackathon',
    storageBucket: 'snapstudy-hackathon.firebasestorage.app',
    iosBundleId: 'com.snapstudy.app',
  );

  static final FirebaseOptions windows = FirebaseOptions(
    apiKey: _resolveApiKey(
      'FIREBASE_WINDOWS_API_KEY',
      'QUl6YVN5U25hcFN0dWR5SGFja2F0aG9uQXBpS2V5V2ViMDE5MjgzNw==',
    ),
    appId: '1:837261549021:web:9f8e7d6c5b4a3210fedcba',
    messagingSenderId: '837261549021',
    projectId: 'snapstudy-hackathon',
    authDomain: 'snapstudy-hackathon.firebaseapp.com',
    storageBucket: 'snapstudy-hackathon.firebasestorage.app',
  );
}
