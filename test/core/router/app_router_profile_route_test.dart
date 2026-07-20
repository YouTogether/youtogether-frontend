import 'package:either_dart/either.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/core/router/app_router.dart';
import 'package:youtogether/core/usecases/usecase.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';
import 'package:youtogether/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:youtogether/features/auth/domain/usecases/login_usecase.dart';
import 'package:youtogether/features/auth/domain/usecases/logout_usecase.dart';
import 'package:youtogether/features/auth/domain/usecases/refresh_token_usecase.dart';
import 'package:youtogether/features/auth/domain/usecases/register_usecase.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_event.dart';
import 'package:youtogether/features/auth/presentation/pages/login_page.dart';
import 'package:youtogether/features/auth/presentation/pages/profile_page.dart';
import 'package:youtogether/l10n/generated/app_localizations.dart';

class MockGetCurrentUserUseCase extends Mock implements GetCurrentUserUseCase {}

class MockRefreshTokenUseCase extends Mock implements RefreshTokenUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockRegisterUseCase extends Mock implements RegisterUseCase {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

/// Widget tests verifying that `/profile` is actually wired into the
/// route table built by [buildAppRouter] (closing the remaining part of
/// ADR-001 gap 3, discovered when F-INF-T1's completeness was audited:
/// `ProfilePage` existed and was fully unit-tested since Sprint 1, but
/// no `GoRoute` ever pointed to it).
///
/// `resolveRedirect` itself already handles `/profile` correctly as a
/// generic protected route — see `app_router_test.dart` — so these
/// tests exist specifically to verify the *route table*, not the guard
/// logic a second time.
///
/// @competency Unit/widget test harness, TDD cycle.
/// @competency Route protection as part of the secure prototype.
void main() {
  late MockGetCurrentUserUseCase getCurrentUserUseCase;
  late MockRefreshTokenUseCase refreshTokenUseCase;
  late MockLogoutUseCase logoutUseCase;
  late MockRegisterUseCase registerUseCase;
  late MockLoginUseCase loginUseCase;
  late AuthBloc authBloc;

  final user = UserEntity(
    id: '550e8400-e29b-41d4-a716-446655440000',
    email: 'test@example.com',
    displayName: 'Test User',
    role: UserRole.registered,
    createdAt: DateTime.utc(2025, 1, 1),
  );

  setUp(() {
    getCurrentUserUseCase = MockGetCurrentUserUseCase();
    refreshTokenUseCase = MockRefreshTokenUseCase();
    logoutUseCase = MockLogoutUseCase();
    registerUseCase = MockRegisterUseCase();
    loginUseCase = MockLoginUseCase();
    authBloc = AuthBloc(
      getCurrentUserUseCase: getCurrentUserUseCase,
      refreshTokenUseCase: refreshTokenUseCase,
      logoutUseCase: logoutUseCase,
    );
  });

  tearDown(() {
    authBloc.close();
  });

  Future<GoRouter> pumpRouterAt(WidgetTester tester, String location) async {
    final router = buildAppRouter(
      authBloc: authBloc,
      registerUseCase: registerUseCase,
      loginUseCase: loginUseCase,
    );

    await tester.pumpWidget(
      BlocProvider.value(
        value: authBloc,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    router.go(location);
    await tester.pumpAndSettle();

    return router;
  }

  group('AppRoutes.profile route wiring', () {
    testWidgets(
      'renders ProfilePage when navigating to /profile while authenticated',
      (tester) async {
        when(
          () => getCurrentUserUseCase(const NoParams()),
        ).thenAnswer((_) async => Right(user));

        authBloc.add(const AuthEvent.checkStatusRequested());
        await pumpRouterAt(tester, AppRoutes.profile);

        expect(find.byType(ProfilePage), findsOneWidget);
      },
    );

    testWidgets('redirects away from /profile to /login when unauthenticated', (
      tester,
    ) async {
      when(() => getCurrentUserUseCase(const NoParams())).thenAnswer(
        (_) async => const Left(Failure.auth(message: 'no session')),
      );
      when(() => refreshTokenUseCase(const NoParams())).thenAnswer(
        (_) async => const Left(Failure.auth(message: 'no refresh token')),
      );

      authBloc.add(const AuthEvent.checkStatusRequested());
      await pumpRouterAt(tester, AppRoutes.profile);

      expect(find.byType(ProfilePage), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
    });
  });
}
