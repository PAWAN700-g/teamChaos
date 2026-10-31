import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for SecureMed IoT connected to `teamchaos4d`.
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
      case TargetPlatform.windows:
        return windows;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC_I3s16CXOOgQK5M3nsrsexjyQVdwD_vs',
    appId: '1:790684898710:web:40042a55667db162ec79b7',
    messagingSenderId: '790684898710',
    projectId: 'teamchaos4d',
    authDomain: 'teamchaos4d.firebaseapp.com',
    storageBucket: 'teamchaos4d.firebasestorage.app',
    measurementId: 'G-J2C7CPL8F4',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC_I3s16CXOOgQK5M3nsrsexjyQVdwD_vs',
    appId: '1:790684898710:web:40042a55667db162ec79b7',
    messagingSenderId: '790684898710',
    projectId: 'teamchaos4d',
    storageBucket: 'teamchaos4d.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC_I3s16CXOOgQK5M3nsrsexjyQVdwD_vs',
    appId: '1:790684898710:web:40042a55667db162ec79b7',
    messagingSenderId: '790684898710',
    projectId: 'teamchaos4d',
    storageBucket: 'teamchaos4d.firebasestorage.app',
    iosBundleId: 'com.teamchaos.securemed.securemedIot',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyC_I3s16CXOOgQK5M3nsrsexjyQVdwD_vs',
    appId: '1:790684898710:web:40042a55667db162ec79b7',
    messagingSenderId: '790684898710',
    projectId: 'teamchaos4d',
    authDomain: 'teamchaos4d.firebaseapp.com',
    storageBucket: 'teamchaos4d.firebasestorage.app',
  );
}
