import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase options for the vendor Android app (`com.p4u.p4u_vendor`).
///
/// Phone OTP still requires a real `google-services.json` from Firebase Console
/// with your debug/release SHA-1 and SHA-256 fingerprints registered.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Vendor mobile app does not target web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'Add GoogleService-Info.plist from Firebase Console for iOS.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBcV0QJNWV95S2u5mBnOHxA1gXg96hcYfA',
    appId: '1:784503032650:android:5850a71430673e49028fb3',
    messagingSenderId: '784503032650',
    projectId: 'p4u-console',
    storageBucket: 'p4u-console.appspot.com',
  );
}
