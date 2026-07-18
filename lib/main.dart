import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injection_container.dart';

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
  WidgetsFlutterBinding.ensureInitialized();

  const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );

  await initDependencies(apiBaseUrl: apiBaseUrl);

  runApp(const App());
}
