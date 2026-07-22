import 'package:bloc_test/bloc_test.dart';
import 'package:either_dart/either.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/usecases/usecase.dart';
import 'package:youtogether/core/router/app_router.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';
import 'package:youtogether/features/auth/domain/usecases/login_params.dart';
import 'package:youtogether/features/auth/domain/usecases/login_usecase.dart';
import 'package:youtogether/features/auth/domain/usecases/register_params.dart';
import 'package:youtogether/features/auth/domain/usecases/register_usecase.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_event.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_state.dart';
import 'package:youtogether/features/room/domain/usecases/create_room_usecase.dart';
import 'package:youtogether/features/room/domain/usecases/delete_room_usecase.dart';
import 'package:youtogether/features/room/domain/usecases/get_public_rooms_usecase.dart';
import 'package:youtogether/features/room/domain/usecases/get_room_by_id_usecase.dart';
import 'package:youtogether/features/room/domain/usecases/join_room_usecase.dart';
import 'package:youtogether/features/room/domain/usecases/update_room_usecase.dart';
import 'package:youtogether/l10n/generated/app_localizations.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockRegisterUseCase extends Mock implements RegisterUseCase {}

class MockGetPublicRoomsUseCase extends Mock implements GetPublicRoomsUseCase {}

class MockCreateRoomUseCase extends Mock implements CreateRoomUseCase {}

class MockDeleteRoomUseCase extends Mock implements DeleteRoomUseCase {}

class MockJoinRoomUseCase extends Mock implements JoinRoomUseCase {}

class MockGetRoomByIdUseCase extends Mock implements GetRoomByIdUseCase {}

class MockUpdateRoomUseCase extends Mock implements UpdateRoomUseCase {}

/// Regression test for the reported bug: following a
/// successful login (or registration), `HomePage` still appeared as an
/// unauthenticated/guest view (create button hidden) and `/profile`
/// redirected back to `/login`, because nothing ever notified
/// [AuthBloc] that a session now existed — `LoginCubit`/`RegisterCubit`
/// persist tokens via their own use cases directly, without touching
/// [AuthBloc] (this is `ADR-001` gap 8, previously only an open
/// architectural question, not yet a defect).
///
/// These tests verify that `onLoginSucceeded`/`onRegistrationSucceeded`
/// (wired in `buildAppRouter`) dispatch
/// `AuthEvent.checkStatusRequested()` on the shared [AuthBloc] — the
/// same event `App.initState` dispatches once at cold start — so that
/// `GoRouterRefreshStream` re-evaluates the guard immediately with a
/// freshly authenticated state.
///
/// @competency Unit/widget test harness, TDD cycle.
void main() {
  late MockAuthBloc authBloc;
  late MockLoginUseCase loginUseCase;
  late MockRegisterUseCase registerUseCase;
  late MockGetPublicRoomsUseCase getPublicRoomsUseCase;
  late MockCreateRoomUseCase createRoomUseCase;
  late MockGetRoomByIdUseCase getRoomByIdUseCase;
  late MockUpdateRoomUseCase updateRoomUseCase;
  late MockDeleteRoomUseCase deleteRoomUseCase;
  late MockJoinRoomUseCase joinRoomUseCase;

  final authenticatedUser = UserEntity(
    id: '550e8400-e29b-41d4-a716-446655440000',
    email: 'user@example.com',
    displayName: 'Test User',
    role: UserRole.registered,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(const AuthEvent.checkStatusRequested());
    registerFallbackValue(const NoParams());
    registerFallbackValue(
      LoginParams(email: 'fallback@example.com', password: 'fallback-password'),
    );
    registerFallbackValue(
      RegisterParams(
        email: 'fallback@example.com',
        password: 'fallback-password',
        username: 'fallback-user',
      ),
    );
  });

  setUp(() {
    authBloc = MockAuthBloc();
    loginUseCase = MockLoginUseCase();
    registerUseCase = MockRegisterUseCase();
    getPublicRoomsUseCase = MockGetPublicRoomsUseCase();
    createRoomUseCase = MockCreateRoomUseCase();
    getRoomByIdUseCase = MockGetRoomByIdUseCase();
    updateRoomUseCase = MockUpdateRoomUseCase();
    deleteRoomUseCase = MockDeleteRoomUseCase();
    joinRoomUseCase = MockJoinRoomUseCase();

    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthState.unauthenticated(),
    );
    when(() => authBloc.add(any())).thenReturn(null);

    when(
      () => getPublicRoomsUseCase(any()),
    ).thenAnswer((_) async => const Right([]));
  });

  Future<GoRouter> pumpRouterAt(WidgetTester tester, String location) async {
    final router = buildAppRouter(
      authBloc: authBloc,
      registerUseCase: registerUseCase,
      loginUseCase: loginUseCase,
      getPublicRoomsUseCase: getPublicRoomsUseCase,
      createRoomUseCase: createRoomUseCase,
      getRoomByIdUseCase: getRoomByIdUseCase,
      updateRoomUseCase: updateRoomUseCase,
      deleteRoomUseCase: deleteRoomUseCase,
      joinRoomUseCase: joinRoomUseCase,
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

    router.go(location);
    await tester.pumpAndSettle();

    return router;
  }

  testWidgets(
    'onLoginSucceeded dispatches AuthEvent.checkStatusRequested() on AuthBloc',
    (tester) async {
      when(
        () => loginUseCase(any()),
      ).thenAnswer((_) async => Right(authenticatedUser));

      await pumpRouterAt(tester, '/login');

      await tester.enterText(
        find.byKey(const Key('loginEmailField')),
        'user@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('loginPasswordField')),
        'password123',
      );
      await tester.tap(find.byKey(const Key('loginSubmitButton')));
      await tester.pumpAndSettle();

      verify(
        () => authBloc.add(const AuthEvent.checkStatusRequested()),
      ).called(1);
    },
  );

  testWidgets(
    'onRegistrationSucceeded dispatches AuthEvent.checkStatusRequested() on '
    'AuthBloc',
    (tester) async {
      when(
        () => registerUseCase(any()),
      ).thenAnswer((_) async => Right(authenticatedUser));

      await pumpRouterAt(tester, '/register');

      await tester.enterText(
        find.byKey(const Key('registerEmailField')),
        'user@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('registerPasswordField')),
        'password123',
      );
      await tester.enterText(
        find.byKey(const Key('registerUsernameField')),
        'newuser',
      );
      await tester.tap(find.byKey(const Key('registerSubmitButton')));
      await tester.pumpAndSettle();

      verify(
        () => authBloc.add(const AuthEvent.checkStatusRequested()),
      ).called(1);
    },
  );
}
