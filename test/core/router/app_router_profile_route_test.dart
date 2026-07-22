import 'package:bloc_test/bloc_test.dart';
import 'package:either_dart/either.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/router/app_router.dart';
import 'package:youtogether/core/usecases/usecase.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';
import 'package:youtogether/features/auth/domain/usecases/login_usecase.dart';
import 'package:youtogether/features/auth/domain/usecases/register_usecase.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_event.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_state.dart';
import 'package:youtogether/features/auth/presentation/pages/login_page.dart';
import 'package:youtogether/features/auth/presentation/pages/profile_page.dart';
import 'package:youtogether/features/room/domain/usecases/create_room_usecase.dart';
import 'package:youtogether/features/room/domain/usecases/get_public_rooms_usecase.dart';
import 'package:youtogether/features/room/domain/usecases/get_room_by_id_usecase.dart';
import 'package:youtogether/l10n/generated/app_localizations.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockRegisterUseCase extends Mock implements RegisterUseCase {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockGetPublicRoomsUseCase extends Mock implements GetPublicRoomsUseCase {}

class MockCreateRoomUseCase extends Mock implements CreateRoomUseCase {}

class MockGetRoomByIdUseCase extends Mock implements GetRoomByIdUseCase {}

/// Widget tests verifying that `/profile` is actually wired into the
/// route table built by [buildAppRouter] (closing the remaining part of
/// ADR-001 gap 3, discovered when F-INF-T1's completeness was audited:
/// `ProfilePage` existed and was fully unit-tested, but
/// no `GoRoute` ever pointed to it).
///
/// `resolveRedirect` itself already handles `/profile` correctly as a
/// generic protected route — see `app_router_test.dart` — so these
/// tests exist specifically to verify the *route table*, not the guard
/// logic a second time, and *not* `AuthBloc.checkStatusRequested`'s own
/// business logic (covered by `auth_bloc_test.dart`).
///
/// ## Why `MockAuthBloc`/`whenListen`, not a real `AuthBloc`
/// An earlier version of this file built a real `AuthBloc` from mocked
/// use cases, dispatched `AuthEvent.checkStatusRequested()`, and awaited
/// `authBloc.stream.firstWhere(...)` before pumping — reasoning that
/// this would avoid racing `ProfilePage`'s indeterminate
/// `CircularProgressIndicator` fallback (which animates forever and
/// hangs `pumpAndSettle()` if still on screen when called). It did avoid
/// that specific race, but introduced a worse one: a bare `await` on a
/// `Future` that never resolves has no timeout in Dart, so any mismatch
/// between the mocked use case's stubbed call signature and the
/// handler's actual invocation — or any additional use case the handler
/// also happens to call — left the test hanging indefinitely with no
/// diagnostic at all, rather than the previous version's at least
/// terminated (if unhelpful) `pumpAndSettle` timeout.
///
/// Driving `AuthBloc.state`/`.stream` directly via `bloc_test`'s
/// `MockBloc` and `whenListen` removes this entire class of failure:
/// the state is asserted synchronously, with no real event processing,
/// no asynchronous use case resolution, and nothing to race.
///
/// @competency Unit/widget test harness, TDD cycle.
/// @competency Route protection as part of the secure prototype.
void main() {
  late MockAuthBloc authBloc;
  late MockRegisterUseCase registerUseCase;
  late MockLoginUseCase loginUseCase;
  late MockGetPublicRoomsUseCase getPublicRoomsUseCase;
  late MockCreateRoomUseCase createRoomUseCase;
  late MockGetRoomByIdUseCase getRoomByIdUseCase;

  final user = UserEntity(
    id: '550e8400-e29b-41d4-a716-446655440000',
    email: 'test@example.com',
    displayName: 'Test User',
    role: UserRole.registered,
    createdAt: DateTime.utc(2025, 1, 1),
  );

  setUp(() {
    authBloc = MockAuthBloc();
    registerUseCase = MockRegisterUseCase();
    loginUseCase = MockLoginUseCase();
    getPublicRoomsUseCase = MockGetPublicRoomsUseCase();
    createRoomUseCase = MockCreateRoomUseCase();
    getRoomByIdUseCase = MockGetRoomByIdUseCase();

    // buildAppRouter always sets initialLocation to AppRoutes.home, so
    // the '/' route (and the RoomBloc it constructs, which immediately
    // dispatches RoomEvent.fetchPublicRooms) is built at least once
    // during the very first pump, regardless of which location a given
    // test subsequently navigates to via router.go(...). Without this
    // stub, that incidental call throws (mocktail returns null for an
    // unstubbed method, which isn't a valid Future<Either<...>>).
    when(
      () => getPublicRoomsUseCase(const NoParams()),
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

  group('AppRoutes.profile route wiring', () {
    testWidgets(
      'renders ProfilePage when navigating to /profile while authenticated',
      (tester) async {
        whenListen(
          authBloc,
          const Stream<AuthState>.empty(),
          initialState: AuthState.authenticated(user),
        );

        await pumpRouterAt(tester, AppRoutes.profile);

        expect(find.byType(ProfilePage), findsOneWidget);
      },
    );

    testWidgets('redirects away from /profile to /login when unauthenticated', (
      tester,
    ) async {
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const AuthState.unauthenticated(),
      );

      await pumpRouterAt(tester, AppRoutes.profile);

      expect(find.byType(ProfilePage), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
    });
  });
}
