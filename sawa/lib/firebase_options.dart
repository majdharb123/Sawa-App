import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
    apiKey: 'AIzaSyDuzeS0rZ4ihh_HDYVR7mkT8JExrpsn2Rg',
    appId: '1:964290246470:web:caea12f5478e121b659747',
    messagingSenderId: '964290246470',
    projectId: 'sawa-30385',
    authDomain: 'sawa-30385.firebaseapp.com',
    storageBucket: 'sawa-30385.firebasestorage.app',
    measurementId: 'G-M2CCZJ8P02',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDXXzNtJyi8NBMX20gQ-4N9oCtakPI96Ak',
    appId: '1:964290246470:android:d27833b2da6e9d59659747',
    messagingSenderId: '964290246470',
    projectId: 'sawa-30385',
    storageBucket: 'sawa-30385.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDAYAhKFAl-cHBh4pg0Hrng3oy2Ef5sKq4',
    appId: '1:964290246470:ios:224c7b267f7a6481659747',
    messagingSenderId: '964290246470',
    projectId: 'sawa-30385',
    storageBucket: 'sawa-30385.firebasestorage.app',
    iosBundleId: 'com.example.sawa',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDAYAhKFAl-cHBh4pg0Hrng3oy2Ef5sKq4',
    appId: '1:964290246470:ios:224c7b267f7a6481659747',
    messagingSenderId: '964290246470',
    projectId: 'sawa-30385',
    storageBucket: 'sawa-30385.firebasestorage.app',
    iosBundleId: 'com.example.sawa',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDuzeS0rZ4ihh_HDYVR7mkT8JExrpsn2Rg',
    appId: '1:964290246470:web:7e7ac659b35717ca659747',
    messagingSenderId: '964290246470',
    projectId: 'sawa-30385',
    authDomain: 'sawa-30385.firebaseapp.com',
    storageBucket: 'sawa-30385.firebasestorage.app',
    measurementId: 'G-STJRN73K1M',
  );
}
