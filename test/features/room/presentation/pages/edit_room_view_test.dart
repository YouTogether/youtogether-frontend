import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/room/domain/entities/room_entity.dart';
import 'package:youtogether/features/room/presentation/cubit/edit_room_cubit.dart';
import 'package:youtogether/features/room/presentation/cubit/edit_room_state.dart';
import 'package:youtogether/features/room/presentation/pages/edit_room_view.dart';
import 'package:youtogether/l10n/generated/app_localizations.dart';

class MockEditRoomCubit extends MockCubit<EditRoomState>
    implements EditRoomCubit {}

/// Widget tests for [EditRoomView].
///
/// Mirrors `create_room_view_test.dart`.
///
/// @competency Unit/widget test harness, TDD cycle.
/// @competency Test scenarios R-UPD-01, R-UPD-02 (pre-population).
void main() {
  late MockEditRoomCubit editRoomCubit;
  late RoomEntity? updatedRoom;

  final initialRoom = RoomEntity(
    id: '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f',
    name: 'Friday Movie Night',
    description: 'Weekly watch party',
    ownerId: '550e8400-e29b-41d4-a716-446655440000',
    isPublic: true,
    memberCount: 2,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    editRoomCubit = MockEditRoomCubit();
    updatedRoom = null;
    when(() => editRoomCubit.reset()).thenReturn(null);
    when(
      () => editRoomCubit.updateRoom(
        roomId: any(named: 'roomId'),
        name: any(named: 'name'),
        description: any(named: 'description'),
      ),
    ).thenAnswer((_) async {});
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<EditRoomCubit>.value(
        value: editRoomCubit,
        child: child,
      ),
    );
  }

  Future<void> pumpEditRoomView(
    WidgetTester tester, {
    required EditRoomState initialState,
  }) async {
    whenListen(
      editRoomCubit,
      const Stream<EditRoomState>.empty(),
      initialState: initialState,
    );

    await tester.pumpWidget(
      wrap(
        EditRoomView(
          initialRoom: initialRoom,
          onRoomUpdated: (room) => updatedRoom = room,
        ),
      ),
    );
  }

  group('EditRoomView — pre-population', () {
    testWidgets('pre-fills the name and description fields', (tester) async {
      await pumpEditRoomView(
        tester,
        initialState: const EditRoomState.initial(),
      );

      final nameField = tester.widget<TextFormField>(
        find.byKey(const Key('editRoomNameField')),
      );
      final descriptionField = tester.widget<TextFormField>(
        find.byKey(const Key('editRoomDescriptionField')),
      );

      expect(nameField.controller!.text, 'Friday Movie Night');
      expect(descriptionField.controller!.text, 'Weekly watch party');
    });
  });

  group('EditRoomView — submission', () {
    testWidgets('calls EditRoomCubit.updateRoom with the edited fields', (
      tester,
    ) async {
      await pumpEditRoomView(
        tester,
        initialState: const EditRoomState.initial(),
      );

      await tester.enterText(
        find.byKey(const Key('editRoomNameField')),
        'Renamed Movie Night',
      );
      await tester.tap(find.byKey(const Key('editRoomSubmitButton')));
      await tester.pump();

      verify(
        () => editRoomCubit.updateRoom(
          roomId: initialRoom.id,
          name: 'Renamed Movie Night',
          description: 'Weekly watch party',
        ),
      ).called(1);
    });
  });

  group('EditRoomView — loading state', () {
    testWidgets('disables fields and shows a progress indicator', (
      tester,
    ) async {
      await pumpEditRoomView(
        tester,
        initialState: const EditRoomState.loading(),
      );

      final nameField = tester.widget<TextFormField>(
        find.byKey(const Key('editRoomNameField')),
      );
      expect(nameField.enabled, isFalse);
      expect(find.byKey(const Key('editRoomLoadingIndicator')), findsOneWidget);
    });
  });

  group('EditRoomView — validation failure (inline)', () {
    testWidgets('shows the name field error inline, no SnackBar', (
      tester,
    ) async {
      await pumpEditRoomView(
        tester,
        initialState: const EditRoomState.failure(
          Failure.validation(errors: {'name': 'Room name must not be empty.'}),
        ),
      );

      expect(find.text('Room name must not be empty.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('EditRoomView — server failure (SnackBar)', () {
    testWidgets('shows a SnackBar for a non-validation failure', (
      tester,
    ) async {
      final controller = StreamController<EditRoomState>();
      addTearDown(controller.close);

      whenListen(
        editRoomCubit,
        controller.stream,
        initialState: const EditRoomState.initial(),
      );

      await tester.pumpWidget(
        wrap(
          EditRoomView(
            initialRoom: initialRoom,
            onRoomUpdated: (room) => updatedRoom = room,
          ),
        ),
      );

      controller.add(const EditRoomState.failure(Failure.network()));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('EditRoomView — success', () {
    testWidgets('invokes onRoomUpdated with the updated room', (tester) async {
      final controller = StreamController<EditRoomState>();
      addTearDown(controller.close);

      whenListen(
        editRoomCubit,
        controller.stream,
        initialState: const EditRoomState.initial(),
      );

      await tester.pumpWidget(
        wrap(
          EditRoomView(
            initialRoom: initialRoom,
            onRoomUpdated: (room) => updatedRoom = room,
          ),
        ),
      );

      controller.add(EditRoomState.success(initialRoom));
      await tester.pump();

      expect(updatedRoom, initialRoom);
    });
  });

  group('EditRoomView — dispose', () {
    testWidgets('calls EditRoomCubit.reset() when the widget is disposed', (
      tester,
    ) async {
      await pumpEditRoomView(
        tester,
        initialState: const EditRoomState.initial(),
      );

      await tester.pumpWidget(const SizedBox.shrink());

      verify(() => editRoomCubit.reset()).called(1);
    });
  });
}
