import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injection_container.dart';
import 'firebase_options.dart';

/// Application entry point.
///
/// [apiBaseUrl] is read from a build-time `--dart-define`, e.g.:
/// ```
/// flutter run --dart-define=API_BASE_URL=https://api.youtogether.example.com
/// ```
/// Falling back to a local development default when not provided, so
/// `flutter run` with no flags still works against a locally running
/// backend. This is gap 7's remediation (`ADR-001`): the API host is an
/// environment-specific value and must never be hardcoded in source.
Future<void> main() async {
  // Required before any plugin channel is touched, and before
  // Firebase.initializeApp in particular.
  WidgetsFlutterBinding.ensureInitialized();

  // Must complete before initDependencies: the service locator's
  // FirebaseDatabase registration resolves Firebase.instance, and
  // App.initState resolves the whole video-sync chain synchronously at
  // startup — so deferring this to "whenever Firebase is first needed"
  // is not an option.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await initDependencies(
    apiBaseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:3000',
    ),
  );

  runApp(const App());
}
