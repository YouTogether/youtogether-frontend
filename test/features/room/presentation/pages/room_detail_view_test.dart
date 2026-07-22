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
import 'package:youtogether/features/room/presentation/cubit/delete_room_cubit.dart';
import 'package:youtogether/features/room/presentation/cubit/delete_room_state.dart';
import 'package:youtogether/features/room/presentation/cubit/join_room_cubit.dart';
import 'package:youtogether/features/room/presentation/cubit/join_room_state.dart';
import 'package:youtogether/features/room/presentation/cubit/leave_room_cubit.dart';
import 'package:youtogether/features/room/presentation/cubit/leave_room_state.dart';
import 'package:youtogether/features/room/presentation/cubit/room_detail_cubit.dart';
import 'package:youtogether/features/room/presentation/cubit/room_detail_state.dart';
import 'package:youtogether/features/room/presentation/pages/room_detail_view.dart';
import 'package:youtogether/l10n/generated/app_localizations.dart';

class MockRoomDetailCubit extends MockCubit<RoomDetailState>
    implements RoomDetailCubit {}

class MockDeleteRoomCubit extends MockCubit<DeleteRoomState>
    implements DeleteRoomCubit {}

class MockJoinRoomCubit extends MockCubit<JoinRoomState>
    implements JoinRoomCubit {}

class MockLeaveRoomCubit extends MockCubit<LeaveRoomState>
    implements LeaveRoomCubit {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

/// Widget tests for [RoomDetailView].
///
/// @competency Unit/widget test harness, TDD cycle.
/// @competency Acceptance criteria: rendering for owner and non-owner
///   viewers.
void main() {
  late MockRoomDetailCubit roomDetailCubit;
  late MockDeleteRoomCubit deleteRoomCubit;
  late MockJoinRoomCubit joinRoomCubit;
  late MockLeaveRoomCubit leaveRoomCubit;
  late MockAuthBloc authBloc;

  final ownerUser = UserEntity(
    id: '550e8400-e29b-41d4-a716-446655440000',
    email: 'owner@example.com',
    displayName: 'Room Owner',
    role: UserRole.registered,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  final visitorUser = ownerUser.copyWith(
    id: '660e8400-e29b-41d4-a716-446655440001',
    displayName: 'Visitor',
  );

  final room = RoomEntity(
    id: '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f',
    name: 'Friday Movie Night',
    description: 'Weekly watch party',
    ownerId: ownerUser.id,
    isPublic: true,
    memberCount: 2,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    roomDetailCubit = MockRoomDetailCubit();
    deleteRoomCubit = MockDeleteRoomCubit();
    joinRoomCubit = MockJoinRoomCubit();
    leaveRoomCubit = MockLeaveRoomCubit();
    authBloc = MockAuthBloc();
  });

  Widget wrap(RoomDetailState roomState, AuthState authState) {
    whenListen(
      roomDetailCubit,
      const Stream<RoomDetailState>.empty(),
      initialState: roomState,
    );
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: authState,
    );
    whenListen(
      deleteRoomCubit,
      const Stream<DeleteRoomState>.empty(),
      initialState: const DeleteRoomState.initial(),
    );
    whenListen(
      joinRoomCubit,
      const Stream<JoinRoomState>.empty(),
      initialState: const JoinRoomState.initial(),
    );
    whenListen(
      leaveRoomCubit,
      const Stream<LeaveRoomState>.empty(),
      initialState: const LeaveRoomState.initial(),
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<RoomDetailCubit>.value(value: roomDetailCubit),
        BlocProvider<DeleteRoomCubit>.value(value: deleteRoomCubit),
        BlocProvider<JoinRoomCubit>.value(value: joinRoomCubit),
        BlocProvider<LeaveRoomCubit>.value(value: leaveRoomCubit),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: AppRoutes.roomDetail(room.id),
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) =>
                  const SizedBox.shrink(key: Key('homeRouteReached')),
            ),
            GoRoute(
              path: AppRoutes.roomDetailPattern,
              builder: (context, state) => RoomDetailView(roomId: room.id),
            ),
          ],
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  group('RoomDetailView — loading state', () {
    testWidgets('shows a progress indicator', (tester) async {
      await tester.pumpWidget(
        wrap(
          const RoomDetailState.loading(),
          const AuthState.unauthenticated(),
        ),
      );

      expect(
        find.byKey(const Key('roomDetailLoadingIndicator')),
        findsOneWidget,
      );
    });
  });

  group('RoomDetailView — loaded state', () {
    testWidgets('renders name, description, and member count', (tester) async {
      await tester.pumpWidget(
        wrap(
          RoomDetailState.loaded(room),
          AuthState.authenticated(visitorUser),
        ),
      );

      expect(find.text('Friday Movie Night'), findsWidgets);
      expect(find.text('Weekly watch party'), findsOneWidget);
    });

    testWidgets('shows the owner badge when the viewer owns the room', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(RoomDetailState.loaded(room), AuthState.authenticated(ownerUser)),
      );

      expect(find.byKey(const Key('roomDetailOwnerBadge')), findsOneWidget);
    });

    testWidgets('hides the owner badge for a non-owner viewer', (tester) async {
      await tester.pumpWidget(
        wrap(
          RoomDetailState.loaded(room),
          AuthState.authenticated(visitorUser),
        ),
      );

      expect(find.byKey(const Key('roomDetailOwnerBadge')), findsNothing);
    });

    testWidgets('hides the owner badge for an unauthenticated viewer', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(RoomDetailState.loaded(room), const AuthState.unauthenticated()),
      );

      expect(find.byKey(const Key('roomDetailOwnerBadge')), findsNothing);
    });
  });

  group('RoomDetailView — edit button visibility (F-R03-T3)', () {
    testWidgets('visible when the viewer owns the room', (tester) async {
      await tester.pumpWidget(
        wrap(RoomDetailState.loaded(room), AuthState.authenticated(ownerUser)),
      );

      expect(find.byKey(const Key('roomDetailEditButton')), findsOneWidget);
    });

    testWidgets('hidden for a non-owner viewer', (tester) async {
      await tester.pumpWidget(
        wrap(
          RoomDetailState.loaded(room),
          AuthState.authenticated(visitorUser),
        ),
      );

      expect(find.byKey(const Key('roomDetailEditButton')), findsNothing);
    });

    testWidgets('hidden for an unauthenticated viewer', (tester) async {
      await tester.pumpWidget(
        wrap(RoomDetailState.loaded(room), const AuthState.unauthenticated()),
      );

      expect(find.byKey(const Key('roomDetailEditButton')), findsNothing);
    });
  });

  group('RoomDetailView — error state', () {
    testWidgets('shows an error message and a retry button', (tester) async {
      await tester.pumpWidget(
        wrap(
          const RoomDetailState.failure(Failure.notFound()),
          const AuthState.unauthenticated(),
        ),
      );

      expect(find.byKey(const Key('roomDetailErrorMessage')), findsOneWidget);
      expect(find.byKey(const Key('roomDetailRetryButton')), findsOneWidget);
    });

    testWidgets('retry button calls RoomDetailCubit.fetchRoom(roomId)', (
      tester,
    ) async {
      when(() => roomDetailCubit.fetchRoom(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        wrap(
          const RoomDetailState.failure(Failure.notFound()),
          const AuthState.unauthenticated(),
        ),
      );

      await tester.tap(find.byKey(const Key('roomDetailRetryButton')));
      await tester.pump();

      verify(() => roomDetailCubit.fetchRoom(room.id)).called(1);
    });
  });

  group('RoomDetailView — back navigation', () {
    testWidgets(
      'renders a back button that navigates to HomePage, in every state',
      (tester) async {
        await tester.pumpWidget(
          wrap(RoomDetailState.loaded(room), const AuthState.unauthenticated()),
        );

        expect(find.byKey(const Key('roomDetailBackButton')), findsOneWidget);

        await tester.tap(find.byKey(const Key('roomDetailBackButton')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('homeRouteReached')), findsOneWidget);
      },
    );

    testWidgets('shows the back button while loading', (tester) async {
      await tester.pumpWidget(
        wrap(
          const RoomDetailState.loading(),
          const AuthState.unauthenticated(),
        ),
      );

      expect(find.byKey(const Key('roomDetailBackButton')), findsOneWidget);
    });

    testWidgets('shows the back button on failure', (tester) async {
      await tester.pumpWidget(
        wrap(
          const RoomDetailState.failure(Failure.notFound()),
          const AuthState.unauthenticated(),
        ),
      );

      expect(find.byKey(const Key('roomDetailBackButton')), findsOneWidget);
    });
  });

  group('RoomDetailView — delete button visibility (F-R04-T3)', () {
    testWidgets('visible when the viewer owns the room', (tester) async {
      await tester.pumpWidget(
        wrap(RoomDetailState.loaded(room), AuthState.authenticated(ownerUser)),
      );

      expect(find.byKey(const Key('roomDetailDeleteButton')), findsOneWidget);
    });

    testWidgets('hidden for a non-owner viewer', (tester) async {
      await tester.pumpWidget(
        wrap(
          RoomDetailState.loaded(room),
          AuthState.authenticated(visitorUser),
        ),
      );

      expect(find.byKey(const Key('roomDetailDeleteButton')), findsNothing);
    });

    testWidgets('hidden for an unauthenticated viewer', (tester) async {
      await tester.pumpWidget(
        wrap(RoomDetailState.loaded(room), const AuthState.unauthenticated()),
      );

      expect(find.byKey(const Key('roomDetailDeleteButton')), findsNothing);
    });
  });

  group('RoomDetailView — deletion confirmation dialog (F-R04-T3)', () {
    testWidgets(
      'shows a confirmation dialog when the delete button is tapped',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            RoomDetailState.loaded(room),
            AuthState.authenticated(ownerUser),
          ),
        );

        await tester.tap(find.byKey(const Key('roomDetailDeleteButton')));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        verifyNever(() => deleteRoomCubit.deleteRoom(any()));
      },
    );

    testWidgets('does not call DeleteRoomCubit.deleteRoom when cancelled', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(RoomDetailState.loaded(room), AuthState.authenticated(ownerUser)),
      );

      await tester.tap(find.byKey(const Key('roomDetailDeleteButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('roomDetailDeleteCancelButton')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => deleteRoomCubit.deleteRoom(any()));
    });

    testWidgets('calls DeleteRoomCubit.deleteRoom(roomId) when confirmed', (
      tester,
    ) async {
      when(() => deleteRoomCubit.deleteRoom(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        wrap(RoomDetailState.loaded(room), AuthState.authenticated(ownerUser)),
      );

      await tester.tap(find.byKey(const Key('roomDetailDeleteButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('roomDetailDeleteConfirmButton')));
      await tester.pumpAndSettle();

      verify(() => deleteRoomCubit.deleteRoom(room.id)).called(1);
    });
  });

  group('RoomDetailView — deletion success navigates home (F-R04-T3)', () {
    testWidgets(
      'navigates to HomePage when DeleteRoomState.success is emitted',
      (tester) async {
        final controller = StreamController<DeleteRoomState>();
        addTearDown(controller.close);

        whenListen(
          roomDetailCubit,
          const Stream<RoomDetailState>.empty(),
          initialState: RoomDetailState.loaded(room),
        );
        whenListen(
          authBloc,
          const Stream<AuthState>.empty(),
          initialState: AuthState.authenticated(ownerUser),
        );
        whenListen(
          deleteRoomCubit,
          controller.stream,
          initialState: const DeleteRoomState.initial(),
        );
        whenListen(
          joinRoomCubit,
          const Stream<JoinRoomState>.empty(),
          initialState: const JoinRoomState.initial(),
        );
        whenListen(
          leaveRoomCubit,
          const Stream<LeaveRoomState>.empty(),
          initialState: const LeaveRoomState.initial(),
        );

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<RoomDetailCubit>.value(value: roomDetailCubit),
              BlocProvider<DeleteRoomCubit>.value(value: deleteRoomCubit),
              BlocProvider<JoinRoomCubit>.value(value: joinRoomCubit),
              BlocProvider<LeaveRoomCubit>.value(value: leaveRoomCubit),
            ],
            child: MaterialApp.router(
              routerConfig: GoRouter(
                initialLocation: AppRoutes.roomDetail(room.id),
                routes: [
                  GoRoute(
                    path: AppRoutes.home,
                    builder: (context, state) =>
                        const SizedBox.shrink(key: Key('homeRouteReached')),
                  ),
                  GoRoute(
                    path: AppRoutes.roomDetailPattern,
                    builder: (context, state) =>
                        RoomDetailView(roomId: room.id),
                  ),
                ],
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );

        controller.add(const DeleteRoomState.success());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('homeRouteReached')), findsOneWidget);
      },
    );
  });

  group('RoomDetailView — join button', () {
    testWidgets('visible for a non-owner authenticated viewer', (tester) async {
      await tester.pumpWidget(
        wrap(
          RoomDetailState.loaded(room),
          AuthState.authenticated(visitorUser),
        ),
      );

      expect(find.byKey(const Key('roomDetailJoinButton')), findsOneWidget);
    });

    testWidgets('hidden for the room owner', (tester) async {
      await tester.pumpWidget(
        wrap(RoomDetailState.loaded(room), AuthState.authenticated(ownerUser)),
      );

      expect(find.byKey(const Key('roomDetailJoinButton')), findsNothing);
    });

    testWidgets('hidden for an unauthenticated viewer', (tester) async {
      await tester.pumpWidget(
        wrap(RoomDetailState.loaded(room), const AuthState.unauthenticated()),
      );

      expect(find.byKey(const Key('roomDetailJoinButton')), findsNothing);
    });

    testWidgets('calls JoinRoomCubit.joinRoom(roomId) when tapped', (
      tester,
    ) async {
      when(() => joinRoomCubit.joinRoom(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        wrap(
          RoomDetailState.loaded(room),
          AuthState.authenticated(visitorUser),
        ),
      );

      await tester.tap(find.byKey(const Key('roomDetailJoinButton')));
      await tester.pump();

      verify(() => joinRoomCubit.joinRoom(room.id)).called(1);
    });

    testWidgets('shows a loading indicator while joining this room', (
      tester,
    ) async {
      whenListen(
        joinRoomCubit,
        const Stream<JoinRoomState>.empty(),
        initialState: JoinRoomState.loading(room.id),
      );
      whenListen(
        roomDetailCubit,
        const Stream<RoomDetailState>.empty(),
        initialState: RoomDetailState.loaded(room),
      );
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: AuthState.authenticated(visitorUser),
      );
      whenListen(
        deleteRoomCubit,
        const Stream<DeleteRoomState>.empty(),
        initialState: const DeleteRoomState.initial(),
      );

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<RoomDetailCubit>.value(value: roomDetailCubit),
            BlocProvider<DeleteRoomCubit>.value(value: deleteRoomCubit),
            BlocProvider<JoinRoomCubit>.value(value: joinRoomCubit),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RoomDetailView(roomId: room.id),
          ),
        ),
      );

      expect(
        find.byKey(const Key('roomDetailJoinLoadingIndicator')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('roomDetailJoinButton')), findsNothing);
    });

    testWidgets('refetches the room and shows a confirmation when '
        'JoinRoomState.success is emitted', (tester) async {
      final controller = StreamController<JoinRoomState>();
      addTearDown(controller.close);

      when(() => roomDetailCubit.fetchRoom(any())).thenAnswer((_) async {});

      whenListen(
        roomDetailCubit,
        const Stream<RoomDetailState>.empty(),
        initialState: RoomDetailState.loaded(room),
      );
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: AuthState.authenticated(visitorUser),
      );
      whenListen(
        deleteRoomCubit,
        const Stream<DeleteRoomState>.empty(),
        initialState: const DeleteRoomState.initial(),
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
            BlocProvider<RoomDetailCubit>.value(value: roomDetailCubit),
            BlocProvider<DeleteRoomCubit>.value(value: deleteRoomCubit),
            BlocProvider<JoinRoomCubit>.value(value: joinRoomCubit),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RoomDetailView(roomId: room.id),
          ),
        ),
      );

      controller.add(JoinRoomState.success(room));
      await tester.pump();

      verify(() => roomDetailCubit.fetchRoom(room.id)).called(1);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('RoomDetailView — leave button visibility (F-R06-T3)', () {
    testWidgets('hidden for the room owner', (tester) async {
      await tester.pumpWidget(
        wrap(RoomDetailState.loaded(room), AuthState.authenticated(ownerUser)),
      );

      expect(find.byKey(const Key('roomDetailLeaveButton')), findsNothing);
    });

    testWidgets('visible for an authenticated non-owner viewer', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          RoomDetailState.loaded(room),
          AuthState.authenticated(visitorUser),
        ),
      );

      expect(find.byKey(const Key('roomDetailLeaveButton')), findsOneWidget);
    });

    testWidgets('hidden for an unauthenticated viewer', (tester) async {
      await tester.pumpWidget(
        wrap(RoomDetailState.loaded(room), const AuthState.unauthenticated()),
      );

      expect(find.byKey(const Key('roomDetailLeaveButton')), findsNothing);
    });
  });

  group('RoomDetailView — leave action (F-R06-T3)', () {
    testWidgets(
      'calls LeaveRoomCubit.leaveRoom(roomId) when tapped, no confirmation '
      'dialog',
      (tester) async {
        when(() => leaveRoomCubit.leaveRoom(any())).thenAnswer((_) async {});

        await tester.pumpWidget(
          wrap(
            RoomDetailState.loaded(room),
            AuthState.authenticated(visitorUser),
          ),
        );

        await tester.tap(find.byKey(const Key('roomDetailLeaveButton')));
        await tester.pump();

        expect(find.byType(AlertDialog), findsNothing);
        verify(() => leaveRoomCubit.leaveRoom(room.id)).called(1);
      },
    );

    testWidgets(
      'navigates to HomePage when LeaveRoomState.success is emitted',
      (tester) async {
        final controller = StreamController<LeaveRoomState>();
        addTearDown(controller.close);

        whenListen(
          roomDetailCubit,
          const Stream<RoomDetailState>.empty(),
          initialState: RoomDetailState.loaded(room),
        );
        whenListen(
          authBloc,
          const Stream<AuthState>.empty(),
          initialState: AuthState.authenticated(visitorUser),
        );
        whenListen(
          deleteRoomCubit,
          const Stream<DeleteRoomState>.empty(),
          initialState: const DeleteRoomState.initial(),
        );
        whenListen(
          leaveRoomCubit,
          controller.stream,
          initialState: const LeaveRoomState.initial(),
        );

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<RoomDetailCubit>.value(value: roomDetailCubit),
              BlocProvider<DeleteRoomCubit>.value(value: deleteRoomCubit),
              BlocProvider<LeaveRoomCubit>.value(value: leaveRoomCubit),
            ],
            child: MaterialApp.router(
              routerConfig: GoRouter(
                initialLocation: AppRoutes.roomDetail(room.id),
                routes: [
                  GoRoute(
                    path: AppRoutes.home,
                    builder: (context, state) =>
                        const SizedBox.shrink(key: Key('homeRouteReached')),
                  ),
                  GoRoute(
                    path: AppRoutes.roomDetailPattern,
                    builder: (context, state) =>
                        RoomDetailView(roomId: room.id),
                  ),
                ],
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );

        controller.add(const LeaveRoomState.success());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('homeRouteReached')), findsOneWidget);
      },
    );
  });
}
