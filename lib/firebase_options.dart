// File generated with Firebase options for garment_measurement_app
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
    apiKey: 'AIzaSyBYAHjGJLVMerOmdWX3KwvwR5TnxVqxB5Q',
    appId: '1:551838289829:web:47c6b364afecd30685a24c',
    messagingSenderId: '551838289829',
    projectId: 'garmentsapp-29109',
    storageBucket: 'garmentsapp-29109.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBYAHjGJLVMerOmdWX3KwvwR5TnxVqxB5Q',
    appId: '1:551838289829:android:47c6b364afecd30685a24c',
    messagingSenderId: '551838289829',
    projectId: 'garmentsapp-29109',
    storageBucket: 'garmentsapp-29109.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBYAHjGJLVMerOmdWX3KwvwR5TnxVqxB5Q',
    appId: '1:551838289829:ios:47c6b364afecd30685a24c',
    messagingSenderId: '551838289829',
    projectId: 'garmentsapp-29109',
    storageBucket: 'garmentsapp-29109.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBYAHjGJLVMerOmdWX3KwvwR5TnxVqxB5Q',
    appId: '1:551838289829:web:47c6b364afecd30685a24c',
    messagingSenderId: '551838289829',
    projectId: 'garmentsapp-29109',
    storageBucket: 'garmentsapp-29109.firebasestorage.app',
  );
}
