import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_event.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_state.dart';
import 'package:youtogether/features/room/domain/entities/room_entity.dart';
import 'package:youtogether/features/room/presentation/bloc/room_bloc.dart';
import 'package:youtogether/features/room/presentation/bloc/room_event.dart';
import 'package:youtogether/features/room/presentation/bloc/room_state.dart';
import 'package:youtogether/features/room/presentation/pages/home_page.dart';
import 'package:youtogether/l10n/generated/app_localizations.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockRoomBloc extends MockBloc<RoomEvent, RoomState> implements RoomBloc {}

/// Widget tests for [HomePage] (F-R01-T3 — presentation layer).
///
/// @competency Unit/widget test harness, TDD cycle.
/// @competency Acceptance criteria: loading/loaded/empty/error states,
///   pull-to-refresh, create-button visibility tied to AuthBloc state.
void main() {
  late MockAuthBloc authBloc;
  late MockRoomBloc roomBloc;

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
  });

  Widget wrap(RoomState roomState, AuthState authState) {
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

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<RoomBloc>.value(value: roomBloc),
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
      when(() => roomBloc.add(any())).thenReturn(null);

      await tester.pumpWidget(
        wrap(RoomState.loaded(rooms), const AuthState.unauthenticated()),
      );

      await tester.fling(
        find.byKey(const Key('homeRoomList')),
        const Offset(0, 300),
        1000,
      );
      await tester.pump();

      verify(() => roomBloc.add(const RoomEvent.refreshRooms())).called(1);
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
  });
}
