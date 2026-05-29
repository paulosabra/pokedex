// PLACEHOLDER — regenerate before enabling analytics in production (T-31).
//
// This file is normally produced by `flutterfire configure` against a real
// Firebase project. No project is wired yet, so these are non-functional
// placeholder values. They are load-bearing ONLY when `ANALYTICS_ENABLED=true`
// (release/prod) — under `flutter test` and debug runs Firebase never
// initialises (§4.2), so the seam and its tests are unaffected. Replace this
// file with `flutterfire configure --platforms=web` output before the T-31
// production deploy.
//
// coverage:ignore-file — flutterfire-generated-style config boilerplate, not
// hand-written logic; excluded from the coverage gate like other codegen.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Default [FirebaseOptions] for the current platform.
///
/// Placeholder until `flutterfire configure` is run (see file header). Only the
/// web target is the deploy target; other platforms throw, matching the shape
/// `flutterfire` generates for unconfigured platforms.
class DefaultFirebaseOptions {
  /// The [FirebaseOptions] for the platform the app is currently running on.
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'DefaultFirebaseOptions are only configured for web. Run '
      '`flutterfire configure` to add the current platform.',
    );
  }

  /// Placeholder web Firebase options. Replace via `flutterfire configure`.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'PLACEHOLDER_API_KEY',
    appId: 'PLACEHOLDER_APP_ID',
    messagingSenderId: 'PLACEHOLDER_SENDER_ID',
    projectId: 'placeholder-pokedex',
    authDomain: 'placeholder-pokedex.firebaseapp.com',
    storageBucket: 'placeholder-pokedex.appspot.com',
    measurementId: 'PLACEHOLDER_MEASUREMENT_ID',
  );
}
