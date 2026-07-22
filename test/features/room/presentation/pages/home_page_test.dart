import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/core/router/app_router.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_event.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_state.dart';
import 'package:youtogether/features/room/domain/entities/room_entity.dart';
import 'package:youtogether/features/room/presentation/bloc/room_bloc.dart';
import 'package:youtogether/features/room/presentation/bloc/room_event.dart';
import 'package:youtogether/features/room/presentation/bloc/room_state.dart';
import 'package:youtogether/features/room/presentation/cubit/join_room_cubit.dart';
import 'package:youtogether/features/room/presentation/cubit/join_room_state.dart';
import 'package:youtogether/features/room/presentation/pages/home_page.dart';
import 'package:youtogether/l10n/generated/app_localizations.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockRoomBloc extends MockBloc<RoomEvent, RoomState> implements RoomBloc {}

class MockJoinRoomCubit extends MockCubit<JoinRoomState>
    implements JoinRoomCubit {}

/// Widget tests for [HomePage] (F-R01-T3 — presentation layer).
///
/// @competency Unit/widget test harness, TDD cycle.
/// @competency Acceptance criteria: loading/loaded/empty/error states,
///   pull-to-refresh, create-button visibility tied to AuthBloc state.
void main() {
  late MockAuthBloc authBloc;
  late MockRoomBloc roomBloc;
  late MockJoinRoomCubit joinRoomCubit;

  setUpAll(() {
    // mocktail requires a registered fallback value for any type used
    // with `any()`/`captureAny()` — `roomBloc.add(any())` below needs
    // one for RoomEvent. This instance is never actually inspected or
    // invoked, only passed around by mocktail's matcher machinery.
    registerFallbackValue(const RoomEvent.fetchPublicRooms());
  });

  final registeredUser = UserEntity(
    id: '550e8400-e29b-41d4-a716-446655440000',
    email: 'owner@example.com',
    displayName: 'Room Owner',
    role: UserRole.registered,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  final guestUser = registeredUser.copyWith(role: UserRole.guest);

  final rooms = [
    RoomEntity(
      id: '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f',
      name: 'Friday Movie Night',
      description: 'Weekly watch party',
      ownerId: registeredUser.id,
      isPublic: true,
      memberCount: 3,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
  ];

  setUp(() {
    authBloc = MockAuthBloc();
    roomBloc = MockRoomBloc();
    joinRoomCubit = MockJoinRoomCubit();
  });

  Widget wrap(
    RoomState roomState,
    AuthState authState, {
    JoinRoomState joinRoomState = const JoinRoomState.initial(),
  }) {
    whenListen(
      roomBloc,
      const Stream<RoomState>.empty(),
      initialState: roomState,
    );
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: authState,
    );
    whenListen(
      joinRoomCubit,
      const Stream<JoinRoomState>.empty(),
      initialState: joinRoomState,
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<RoomBloc>.value(value: roomBloc),
        BlocProvider<JoinRoomCubit>.value(value: joinRoomCubit),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomePage()),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: '/rooms/create',
              builder: (context, state) =>
                  const SizedBox.shrink(key: Key('createRoomRouteReached')),
            ),
            GoRoute(
              path: AppRoutes.roomDetailPattern,
              builder: (context, state) => SizedBox.shrink(
                key: Key(
                  'roomDetailRouteReached_${state.pathParameters['id']}',
                ),
              ),
            ),
          ],
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  group('HomePage — loading state', () {
    testWidgets('shows a progress indicator for RoomState.initial', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const RoomState.initial(), const AuthState.unauthenticated()),
      );

      expect(find.byKey(const Key('homeLoadingIndicator')), findsOneWidget);
    });

    testWidgets('shows a progress indicator for RoomState.loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const RoomState.loading(), const AuthState.unauthenticated()),
      );

      expect(find.byKey(const Key('homeLoadingIndicator')), findsOneWidget);
    });
  });

  group('HomePage — loaded state', () {
    testWidgets('renders a RoomCard per room', (tester) async {
      await tester.pumpWidget(
        wrap(RoomState.loaded(rooms), const AuthState.unauthenticated()),
      );

      expect(find.byKey(const Key('homeRoomList')), findsOneWidget);
      expect(find.text('Friday Movie Night'), findsOneWidget);
    });

    testWidgets('shows an empty state when no rooms exist', (tester) async {
      await tester.pumpWidget(
        wrap(const RoomState.loaded([]), const AuthState.unauthenticated()),
      );

      expect(find.byKey(const Key('homeEmptyState')), findsOneWidget);
    });

    testWidgets('dispatches RoomEvent.refreshRooms() on pull-to-refresh', (
      tester,
    ) async {
      final controller = StreamController<RoomState>();
      addTearDown(controller.close);

      final homePage = wrap(
        RoomState.loaded(rooms),
        const AuthState.unauthenticated(),
      );
      // wrap() stubs roomBloc.stream to a Stream.empty(); override it
      // here with a controller-backed stream so this test's later
      // await on RoomBloc.stream.firstWhere(...) (inside HomePage's
      // onRefresh) can actually resolve instead of erroring out on an
      // already-closed empty stream.
      whenListen(
        roomBloc,
        controller.stream,
        initialState: RoomState.loaded(rooms),
      );
      when(() => roomBloc.add(any())).thenReturn(null);

      await tester.pumpWidget(homePage);

      await tester.fling(
        find.byKey(const Key('homeRoomList')),
        const Offset(0, 300),
        1000,
      );
      // A single bare pump() only processes the drag/release gesture
      // itself. RefreshIndicator's "armed" indicator animation runs on
      // its own AnimationController and only invokes onRefresh once
      // that animation completes — advancing the test clock is
      // required for that to actually happen.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(() => roomBloc.add(const RoomEvent.refreshRooms())).called(1);

      // Resolve the pending onRefresh await (RoomBloc.stream.firstWhere)
      // so RefreshIndicator can settle cleanly before the test ends.
      controller.add(RoomState.loaded(rooms));
      await tester.pumpAndSettle();
    });
  });

  group('HomePage — error state', () {
    testWidgets('shows an error message and a retry button', (tester) async {
      await tester.pumpWidget(
        wrap(
          const RoomState.failure(Failure.network()),
          const AuthState.unauthenticated(),
        ),
      );

      expect(find.byKey(const Key('homeErrorMessage')), findsOneWidget);
      expect(find.byKey(const Key('homeRetryButton')), findsOneWidget);
    });

    testWidgets(
      'dispatches RoomEvent.fetchPublicRooms() when retry is tapped',
      (tester) async {
        when(() => roomBloc.add(any())).thenReturn(null);

        await tester.pumpWidget(
          wrap(
            const RoomState.failure(Failure.network()),
            const AuthState.unauthenticated(),
          ),
        );

        await tester.tap(find.byKey(const Key('homeRetryButton')));
        await tester.pump();

        verify(
          () => roomBloc.add(const RoomEvent.fetchPublicRooms()),
        ).called(1);
      },
    );
  });

  group('HomePage — create room button visibility', () {
    testWidgets('hidden when unauthenticated', (tester) async {
      await tester.pumpWidget(
        wrap(const RoomState.loaded([]), const AuthState.unauthenticated()),
      );

      expect(find.byKey(const Key('homeCreateRoomButton')), findsNothing);
    });

    testWidgets('hidden for a guest user', (tester) async {
      await tester.pumpWidget(
        wrap(const RoomState.loaded([]), AuthState.authenticated(guestUser)),
      );

      expect(find.byKey(const Key('homeCreateRoomButton')), findsNothing);
    });

    testWidgets('visible for a registered, authenticated user', (tester) async {
      await tester.pumpWidget(
        wrap(
          const RoomState.loaded([]),
          AuthState.authenticated(registeredUser),
        ),
      );

      expect(find.byKey(const Key('homeCreateRoomButton')), findsOneWidget);
    });

    testWidgets('navigates to /rooms/create when tapped', (tester) async {
      await tester.pumpWidget(
        wrap(
          const RoomState.loaded([]),
          AuthState.authenticated(registeredUser),
        ),
      );

      await tester.tap(find.byKey(const Key('homeCreateRoomButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('createRoomRouteReached')), findsOneWidget);
    });
  });

  group('HomePage — join button visibility (F-R05-T3)', () {
    testWidgets('hidden when unauthenticated', (tester) async {
      await tester.pumpWidget(
        wrap(RoomState.loaded(rooms), const AuthState.unauthenticated()),
      );

      expect(
        find.byKey(Key('roomCardJoinButton_${rooms.first.id}')),
        findsNothing,
      );
    });

    testWidgets('visible for a registered, authenticated user', (tester) async {
      await tester.pumpWidget(
        wrap(RoomState.loaded(rooms), AuthState.authenticated(registeredUser)),
      );

      expect(
        find.byKey(Key('roomCardJoinButton_${rooms.first.id}')),
        findsOneWidget,
      );
    });

    testWidgets('visible for a guest-role authenticated user', (tester) async {
      // Unlike the create-room button, the backend places no
      // role-based restriction on joining (only JwtAuthGuard) — see
      // RoomController.join's own documentation.
      await tester.pumpWidget(
        wrap(RoomState.loaded(rooms), AuthState.authenticated(guestUser)),
      );

      expect(
        find.byKey(Key('roomCardJoinButton_${rooms.first.id}')),
        findsOneWidget,
      );
    });
  });

  group('HomePage — join action (F-R05-T3)', () {
    testWidgets(
      'calls JoinRoomCubit.joinRoom(roomId) when the join button is tapped',
      (tester) async {
        when(() => joinRoomCubit.joinRoom(any())).thenAnswer((_) async {});

        await tester.pumpWidget(
          wrap(
            RoomState.loaded(rooms),
            AuthState.authenticated(registeredUser),
          ),
        );

        await tester.tap(
          find.byKey(Key('roomCardJoinButton_${rooms.first.id}')),
        );
        await tester.pump();

        verify(() => joinRoomCubit.joinRoom(rooms.first.id)).called(1);
      },
    );

    testWidgets(
      'shows a per-card loading indicator only for the room being joined',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            RoomState.loaded(rooms),
            AuthState.authenticated(registeredUser),
            joinRoomState: JoinRoomState.loading(rooms.first.id),
          ),
        );

        expect(
          find.byKey(Key('roomCardJoinLoadingIndicator_${rooms.first.id}')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'navigates to the room detail view when JoinRoomState.success is '
      'emitted',
      (tester) async {
        final controller = StreamController<JoinRoomState>();
        addTearDown(controller.close);

        whenListen(
          roomBloc,
          const Stream<RoomState>.empty(),
          initialState: RoomState.loaded(rooms),
        );
        whenListen(
          authBloc,
          const Stream<AuthState>.empty(),
          initialState: AuthState.authenticated(registeredUser),
        );
        whenListen(
          joinRoomCubit,
          controller.stream,
          initialState: const JoinRoomState.initial(),
        );

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<RoomBloc>.value(value: roomBloc),
              BlocProvider<JoinRoomCubit>.value(value: joinRoomCubit),
            ],
            child: MaterialApp.router(
              routerConfig: GoRouter(
                initialLocation: '/',
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (context, state) => const HomePage(),
                  ),
                  GoRoute(
                    path: AppRoutes.roomDetailPattern,
                    builder: (context, state) => SizedBox.shrink(
                      key: Key(
                        'roomDetailRouteReached_${state.pathParameters['id']}',
                      ),
                    ),
                  ),
                ],
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );

        controller.add(JoinRoomState.success(rooms.first));
        await tester.pumpAndSettle();

        expect(
          find.byKey(Key('roomDetailRouteReached_${rooms.first.id}')),
          findsOneWidget,
        );
      },
    );
  });
}
