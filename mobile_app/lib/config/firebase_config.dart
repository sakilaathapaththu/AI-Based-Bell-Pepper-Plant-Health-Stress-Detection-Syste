import 'package:firebase_core/firebase_core.dart';

import 'package:bell_pepper_app/firebase_options.dart';

/// Single entry point for Firebase startup, called once from `main()`
/// before `runApp`.
class FirebaseConfig {
  const FirebaseConfig._();

  static Future<FirebaseApp> initialize() {
    return Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
