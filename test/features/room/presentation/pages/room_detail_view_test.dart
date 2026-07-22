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
import 'package:youtogether/features/room/presentation/cubit/room_detail_cubit.dart';
import 'package:youtogether/features/room/presentation/cubit/room_detail_state.dart';
import 'package:youtogether/features/room/presentation/pages/room_detail_view.dart';
import 'package:youtogether/l10n/generated/app_localizations.dart';

class MockRoomDetailCubit extends MockCubit<RoomDetailState>
    implements RoomDetailCubit {}

class MockDeleteRoomCubit extends MockCubit<DeleteRoomState>
    implements DeleteRoomCubit {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

/// Widget tests for [RoomDetailView].
///
/// @competency Unit/widget test harness, TDD cycle.
/// @competency Acceptance criteria: rendering for owner and non-owner
///   viewers.
void main() {
  late MockRoomDetailCubit roomDetailCubit;
  late MockDeleteRoomCubit deleteRoomCubit;
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

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<RoomDetailCubit>.value(value: roomDetailCubit),
        BlocProvider<DeleteRoomCubit>.value(value: deleteRoomCubit),
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

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<RoomDetailCubit>.value(value: roomDetailCubit),
              BlocProvider<DeleteRoomCubit>.value(value: deleteRoomCubit),
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
}
