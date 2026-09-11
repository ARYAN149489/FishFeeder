import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration options for each platform.
/// These values come from google-services.json (Android) and
/// the Firebase Console (Web).
///
/// To get web config: Firebase Console → Project Settings → General →
/// Your apps → Add app → Web → copy the config values.
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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Values from google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB549YsaHAGXsxoibFrKtBLTplq56QQnv4',
    appId: '1:1083258068643:android:2c70a91d24260f8dafa916',
    messagingSenderId: '1083258068643',
    projectId: 'aquafeed-ebe01',
    storageBucket: 'aquafeed-ebe01.firebasestorage.app',
  );

  // TODO: Add a Web app in Firebase Console → Project Settings → Add app → Web
  // Then replace these placeholder values with the real ones.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB549YsaHAGXsxoibFrKtBLTplq56QQnv4',
    appId: '1:1083258068643:web:REPLACE_WITH_WEB_APP_ID',
    messagingSenderId: '1083258068643',
    projectId: 'aquafeed-ebe01',
    storageBucket: 'aquafeed-ebe01.firebasestorage.app',
    authDomain: 'aquafeed-ebe01.firebaseapp.com',
  );

  // TODO: Add an iOS app in Firebase Console if needed
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_IOS_API_KEY',
    appId: 'REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: '1083258068643',
    projectId: 'aquafeed-ebe01',
    storageBucket: 'aquafeed-ebe01.firebasestorage.app',
    iosBundleId: 'com.aquafeed.aquafeed',
  );
}
