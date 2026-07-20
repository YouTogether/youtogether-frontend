import 'package:flutter_test/flutter_test.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/core/router/app_router.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_state.dart';

/// Unit tests for [resolveRedirect] (F-INF-T1, gap 3 of ADR-001).
///
/// Extracted as a standalone, pure function of `(AuthState,
/// String matchedLocation) -> String?` specifically so the route-guard
/// decision table can be exercised without booting a `GoRouter` or a
/// widget tree — `AppRouter`'s `redirect` callback is a two-line
/// adapter that reads `authBloc.state` and the current
/// `GoRouterState.matchedLocation` and delegates here.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Route guard behaviour (ergonomic, secure prototype).
void main() {
  final user = UserEntity(
    id: '550e8400-e29b-41d4-a716-446655440000',
    email: 'test@example.com',
    displayName: 'testuser',
    role: UserRole.registered,
    createdAt: DateTime.utc(2025, 1, 1),
  );

  group('resolveRedirect — session status still resolving', () {
    test('does not redirect while AuthState.initial (avoids a login flash '
        'before checkStatusRequested resolves)', () {
      expect(resolveRedirect(const AuthState.initial(), '/'), isNull);
    });

    test('does not redirect while AuthState.loading', () {
      expect(resolveRedirect(const AuthState.loading(), '/'), isNull);
    });
  });

  group('resolveRedirect — authenticated', () {
    test('redirects away from /login to the home route', () {
      expect(resolveRedirect(AuthState.authenticated(user), '/login'), '/');
    });

    test('redirects away from /register to the home route', () {
      expect(resolveRedirect(AuthState.authenticated(user), '/register'), '/');
    });

    test('does not redirect when already on a protected route', () {
      expect(resolveRedirect(AuthState.authenticated(user), '/'), isNull);
    });
  });

  group('resolveRedirect — unauthenticated', () {
    test('redirects to /login from a protected route', () {
      expect(resolveRedirect(const AuthState.unauthenticated(), '/'), '/login');
    });

    test('does not redirect when already on /login', () {
      expect(
        resolveRedirect(const AuthState.unauthenticated(), '/login'),
        isNull,
      );
    });

    test('does not redirect when already on /register', () {
      expect(
        resolveRedirect(const AuthState.unauthenticated(), '/register'),
        isNull,
      );
    });
  });

  group('resolveRedirect — failure', () {
    test('treats AuthState.failure the same as unauthenticated: redirects '
        'to /login from a protected route', () {
      expect(
        resolveRedirect(
          const AuthState.failure(Failure.cache(message: 'irrelevant')),
          '/',
        ),
        '/login',
      );
    });
  });
}
