import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/room/domain/entities/room_entity.dart';
import 'package:youtogether/features/room/presentation/cubit/create_room_cubit.dart';
import 'package:youtogether/features/room/presentation/cubit/create_room_state.dart';
import 'package:youtogether/features/room/presentation/pages/create_room_view.dart';
import 'package:youtogether/l10n/generated/app_localizations.dart';

class MockCreateRoomCubit extends MockCubit<CreateRoomState>
    implements CreateRoomCubit {}

/// Widget tests for [CreateRoomView].
///
/// Mirrors `register_view_test.dart`: an already-built (mocked) cubit
/// supplied via `BlocProvider.value`, exercised through
/// `whenListen`/state transitions rather than a real use case.
///
/// @competency Unit/widget test harness, TDD cycle.
void main() {
  late MockCreateRoomCubit createRoomCubit;
  late RoomEntity? createdRoom;

  final room = RoomEntity(
    id: '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f',
    name: 'Friday Movie Night',
    description: 'Weekly watch party',
    ownerId: '550e8400-e29b-41d4-a716-446655440000',
    isPublic: true,
    memberCount: 1,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    createRoomCubit = MockCreateRoomCubit();
    createdRoom = null;
    when(() => createRoomCubit.reset()).thenReturn(null);
    when(
      () => createRoomCubit.createRoom(
        name: any(named: 'name'),
        description: any(named: 'description'),
        isPublic: any(named: 'isPublic'),
      ),
    ).thenAnswer((_) async {});
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<CreateRoomCubit>.value(
        value: createRoomCubit,
        child: child,
      ),
    );
  }

  Future<void> pumpCreateRoomView(
    WidgetTester tester, {
    required CreateRoomState initialState,
  }) async {
    whenListen(
      createRoomCubit,
      const Stream<CreateRoomState>.empty(),
      initialState: initialState,
    );

    await tester.pumpWidget(
      wrap(CreateRoomView(onRoomCreated: (room) => createdRoom = room)),
    );
  }

  group('CreateRoomView — rendering', () {
    testWidgets('renders name, description fields and submit button', (
      tester,
    ) async {
      await pumpCreateRoomView(
        tester,
        initialState: const CreateRoomState.initial(),
      );

      expect(find.byKey(const Key('createRoomNameField')), findsOneWidget);
      expect(
        find.byKey(const Key('createRoomDescriptionField')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('createRoomIsPublicSwitch')), findsOneWidget);
      expect(find.byKey(const Key('createRoomSubmitButton')), findsOneWidget);
    });

    testWidgets('isPublic switch defaults to true', (tester) async {
      await pumpCreateRoomView(
        tester,
        initialState: const CreateRoomState.initial(),
      );

      final switchWidget = tester.widget<SwitchListTile>(
        find.byKey(const Key('createRoomIsPublicSwitch')),
      );
      expect(switchWidget.value, isTrue);
    });
  });

  group('CreateRoomView — submission', () {
    testWidgets('calls CreateRoomCubit.createRoom with the entered fields', (
      tester,
    ) async {
      await pumpCreateRoomView(
        tester,
        initialState: const CreateRoomState.initial(),
      );

      await tester.enterText(
        find.byKey(const Key('createRoomNameField')),
        'Friday Movie Night',
      );
      await tester.enterText(
        find.byKey(const Key('createRoomDescriptionField')),
        'Weekly watch party',
      );
      await tester.tap(find.byKey(const Key('createRoomSubmitButton')));
      await tester.pump();

      verify(
        () => createRoomCubit.createRoom(
          name: 'Friday Movie Night',
          description: 'Weekly watch party',
          isPublic: true,
        ),
      ).called(1);
    });
  });

  group('CreateRoomView — loading state', () {
    testWidgets('disables fields and shows a progress indicator', (
      tester,
    ) async {
      await pumpCreateRoomView(
        tester,
        initialState: const CreateRoomState.loading(),
      );

      final nameField = tester.widget<TextFormField>(
        find.byKey(const Key('createRoomNameField')),
      );
      expect(nameField.enabled, isFalse);
      expect(
        find.byKey(const Key('createRoomLoadingIndicator')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('createRoomSubmitButton')), findsNothing);
    });
  });

  group('CreateRoomView — validation failure (inline)', () {
    testWidgets('shows the name field error inline, no SnackBar', (
      tester,
    ) async {
      await pumpCreateRoomView(
        tester,
        initialState: const CreateRoomState.failure(
          Failure.validation(errors: {'name': 'Room name must not be empty.'}),
        ),
      );

      expect(find.text('Room name must not be empty.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('CreateRoomView — server failure (SnackBar)', () {
    testWidgets('shows a SnackBar for a non-validation failure', (
      tester,
    ) async {
      final controller = StreamController<CreateRoomState>();
      addTearDown(controller.close);

      whenListen(
        createRoomCubit,
        controller.stream,
        initialState: const CreateRoomState.initial(),
      );

      await tester.pumpWidget(
        wrap(CreateRoomView(onRoomCreated: (room) => createdRoom = room)),
      );

      controller.add(const CreateRoomState.failure(Failure.network()));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('CreateRoomView — success', () {
    testWidgets('invokes onRoomCreated with the created room', (tester) async {
      final controller = StreamController<CreateRoomState>();
      addTearDown(controller.close);

      whenListen(
        createRoomCubit,
        controller.stream,
        initialState: const CreateRoomState.initial(),
      );

      await tester.pumpWidget(
        wrap(CreateRoomView(onRoomCreated: (room) => createdRoom = room)),
      );

      controller.add(CreateRoomState.success(room));
      await tester.pump();

      expect(createdRoom, room);
    });
  });

  group('CreateRoomView — dispose', () {
    testWidgets('calls CreateRoomCubit.reset() when the widget is disposed', (
      tester,
    ) async {
      await pumpCreateRoomView(
        tester,
        initialState: const CreateRoomState.initial(),
      );

      await tester.pumpWidget(const SizedBox.shrink());

      verify(() => createRoomCubit.reset()).called(1);
    });
  });
}
