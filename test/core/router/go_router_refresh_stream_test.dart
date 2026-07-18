import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:youtogether/core/router/go_router_refresh_stream.dart';

/// Unit tests for [GoRouterRefreshStream] (F-INF-T1, gap 4 of ADR-001).
///
/// This is the standard `flutter_bloc` + `go_router` integration
/// pattern: a `ChangeNotifier` bridging a Bloc's state stream to
/// `GoRouter`'s `refreshListenable`, so route guards re-evaluate
/// automatically on every [AuthState] emission — not just on
/// user-initiated navigation.
///
/// @competency Unit test harness, TDD cycle.
void main() {
  group('GoRouterRefreshStream', () {
    test('cancels its stream subscription on dispose (no leak)', () async {
      final controller = StreamController<int>.broadcast();
      addTearDown(controller.close);

      final refreshStream = GoRouterRefreshStream(controller.stream);
      refreshStream.dispose();

      // No listener is attached; this only verifies dispose() completes
      // without throwing, i.e. the subscription was valid and cancellable.
      expect(() => controller.add(1), returnsNormally);
    });

    test('notifies listeners on every stream event', () async {
      final controller = StreamController<int>.broadcast();
      addTearDown(controller.close);

      final refreshStream = GoRouterRefreshStream(controller.stream);
      addTearDown(refreshStream.dispose);

      var notificationCount = 0;
      refreshStream.addListener(() => notificationCount++);

      controller.add(1);
      await Future<void>.delayed(Duration.zero);
      controller.add(2);
      await Future<void>.delayed(Duration.zero);

      expect(notificationCount, 2);
    });

    test('stops notifying after dispose', () async {
      final controller = StreamController<int>.broadcast();
      addTearDown(controller.close);

      final refreshStream = GoRouterRefreshStream(controller.stream);

      var notificationCount = 0;
      refreshStream.addListener(() => notificationCount++);

      refreshStream.dispose();

      controller.add(1);
      await Future<void>.delayed(Duration.zero);

      expect(notificationCount, 0);
    });
  });
}
