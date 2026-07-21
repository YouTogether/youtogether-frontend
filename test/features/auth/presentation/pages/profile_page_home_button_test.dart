import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_event.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_state.dart';
import 'package:youtogether/features/auth/presentation/pages/profile_page.dart';
import 'package:youtogether/l10n/generated/app_localizations.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

/// Regression test for the bug reported after: there was no
/// way to return to the home screen from `ProfilePage` — `context.go()`
/// does not build a back stack, so Flutter's automatic AppBar back
/// button never appeared, regardless of how `/profile` was reached
/// (a direct tap, or a redirect while unauthenticated).
///
/// @competency Unit/widget test harness, TDD cycle.
void main() {
  late MockAuthBloc authBloc;

  final user = UserEntity(
    id: '550e8400-e29b-41d4-a716-446655440000',
    email: 'test@example.com',
    displayName: 'Test User',
    role: UserRole.registered,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    authBloc = MockAuthBloc();
  });

  testWidgets('tapping the back-to-home button navigates to AppRoutes.home', (
    tester,
  ) async {
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: AuthState.authenticated(user),
    );

    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const SizedBox.shrink(key: Key('homeRouteReached')),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfilePage(),
        ),
      ],
    );

    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profileBackToHomeButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('homeRouteReached')), findsOneWidget);
  });
}
