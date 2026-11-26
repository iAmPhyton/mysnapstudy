// File generated for SnapStudy Flutter Firebase integration.
// Project: snapstudy-hackathon
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDBKSBCoV4jo9VfviH4bnbzfUK4I4rvxTc',
    appId: '1:854206189215:web:363758cfaec900618a9caa',
    messagingSenderId: '854206189215',
    projectId: 'snapstudy-hackathon',
    authDomain: 'snapstudy-hackathon.firebaseapp.com',
    storageBucket: 'snapstudy-hackathon.firebasestorage.app",',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSySnapStudyHackathonApiKeyAndroid019',
    appId: '1:837261549021:android:3b2a1c0d9e8f7a6b5c4d3e',
    messagingSenderId: '837261549021',
    projectId: 'snapstudy-hackathon',
    storageBucket: 'snapstudy-hackathon.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSySnapStudyHackathonApiKeyIOS0192837',
    appId: '1:837261549021:ios:2a1b0c9d8e7f6a5b4c3d2e',
    messagingSenderId: '837261549021',
    projectId: 'snapstudy-hackathon',
    storageBucket: 'snapstudy-hackathon.firebasestorage.app',
    iosBundleId: 'com.snapstudy.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSySnapStudyHackathonApiKeyIOS0192837',
    appId: '1:837261549021:ios:2a1b0c9d8e7f6a5b4c3d2e',
    messagingSenderId: '837261549021',
    projectId: 'snapstudy-hackathon',
    storageBucket: 'snapstudy-hackathon.firebasestorage.app',
    iosBundleId: 'com.snapstudy.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSySnapStudyHackathonApiKeyWeb0192837',
    appId: '1:837261549021:web:9f8e7d6c5b4a3210fedcba',
    messagingSenderId: '837261549021',
    projectId: 'snapstudy-hackathon',
    authDomain: 'snapstudy-hackathon.firebaseapp.com',
    storageBucket: 'snapstudy-hackathon.firebasestorage.app',
  );
}
