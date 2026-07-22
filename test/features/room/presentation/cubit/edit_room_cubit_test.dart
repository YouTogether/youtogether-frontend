import 'package:bloc_test/bloc_test.dart';
import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/room/domain/entities/room_entity.dart';
import 'package:youtogether/features/room/domain/usecases/update_room_params.dart';
import 'package:youtogether/features/room/domain/usecases/update_room_usecase.dart';
import 'package:youtogether/features/room/presentation/cubit/edit_room_cubit.dart';
import 'package:youtogether/features/room/presentation/cubit/edit_room_state.dart';

class MockUpdateRoomUseCase extends Mock implements UpdateRoomUseCase {}

/// Unit tests for [EditRoomCubit].
///
/// Mirrors `create_room_cubit_test.dart`: client-side validation rejects
/// before any network call, mirroring the backend's constraints.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios R-UPD-01, R-UPD-02, R-UPD-04.
void main() {
  late MockUpdateRoomUseCase updateRoomUseCase;

  setUpAll(() {
    registerFallbackValue(UpdateRoomParams(roomId: 'fallback'));
  });

  setUp(() {
    updateRoomUseCase = MockUpdateRoomUseCase();
  });

  EditRoomCubit buildCubit() => EditRoomCubit(updateRoomUseCase);

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';

  final updatedRoom = RoomEntity(
    id: roomId,
    name: 'Renamed Movie Night',
    description: 'Updated description',
    ownerId: '550e8400-e29b-41d4-a716-446655440000',
    isPublic: true,
    memberCount: 2,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 5),
  );

  group('updateRoom — validation', () {
    blocTest<EditRoomCubit, EditRoomState>(
      'emits failure(ValidationFailure) for an empty name, without calling '
      'the use case (R-UPD-04)',
      build: buildCubit,
      act: (cubit) => cubit.updateRoom(roomId: roomId, name: ''),
      expect: () => [
        isA<EditRoomFailure>().having(
          (s) => s.failure,
          'failure',
          isA<ValidationFailure>(),
        ),
      ],
      verify: (_) {
        verifyNever(() => updateRoomUseCase(any()));
      },
    );

    blocTest<EditRoomCubit, EditRoomState>(
      'emits failure(ValidationFailure) for a name exceeding 100 characters',
      build: buildCubit,
      act: (cubit) =>
          cubit.updateRoom(roomId: roomId, name: List.filled(101, 'a').join()),
      expect: () => [isA<EditRoomFailure>()],
    );
  });

  group('updateRoom — success', () {
    blocTest<EditRoomCubit, EditRoomState>(
      'emits [loading, success(room)] for a valid submission (R-UPD-01)',
      build: () {
        when(
          () => updateRoomUseCase(any()),
        ).thenAnswer((_) async => Right(updatedRoom));
        return buildCubit();
      },
      act: (cubit) => cubit.updateRoom(
        roomId: roomId,
        name: 'Renamed Movie Night',
        description: 'Updated description',
      ),
      expect: () => [
        const EditRoomState.loading(),
        EditRoomState.success(updatedRoom),
      ],
    );

    blocTest<EditRoomCubit, EditRoomState>(
      'supports a partial update (description only) (R-UPD-02)',
      build: () {
        when(
          () => updateRoomUseCase(any()),
        ).thenAnswer((_) async => Right(updatedRoom));
        return buildCubit();
      },
      act: (cubit) => cubit.updateRoom(
        roomId: roomId,
        name: 'Renamed Movie Night',
        description: 'Only description changes',
      ),
      verify: (_) {
        verify(
          () => updateRoomUseCase(
            UpdateRoomParams(
              roomId: roomId,
              name: 'Renamed Movie Night',
              description: 'Only description changes',
            ),
          ),
        ).called(1);
      },
    );
  });

  group('updateRoom — server failure', () {
    blocTest<EditRoomCubit, EditRoomState>(
      'emits [loading, failure] on a 403 (non-owner)',
      build: () {
        when(() => updateRoomUseCase(any())).thenAnswer(
          (_) async => const Left(
            Failure.auth(
              message: 'Only the owner of this room may perform this action.',
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.updateRoom(roomId: roomId, name: 'New Name'),
      expect: () => [
        const EditRoomState.loading(),
        isA<EditRoomFailure>().having(
          (s) => s.failure,
          'failure',
          isA<AuthFailure>(),
        ),
      ],
    );
  });

  group('reset', () {
    blocTest<EditRoomCubit, EditRoomState>(
      'emits EditRoomState.initial when called after a success',
      build: () {
        when(
          () => updateRoomUseCase(any()),
        ).thenAnswer((_) async => Right(updatedRoom));
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.updateRoom(roomId: roomId, name: 'Renamed Movie Night');
        cubit.reset();
      },
      expect: () => [
        const EditRoomState.loading(),
        EditRoomState.success(updatedRoom),
        const EditRoomState.initial(),
      ],
    );
  });
}
