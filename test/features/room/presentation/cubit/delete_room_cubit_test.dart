import 'package:bloc_test/bloc_test.dart';
import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/room/domain/usecases/delete_room_usecase.dart';
import 'package:youtogether/features/room/presentation/cubit/delete_room_cubit.dart';
import 'package:youtogether/features/room/presentation/cubit/delete_room_state.dart';

class MockDeleteRoomUseCase extends Mock implements DeleteRoomUseCase {}

/// Unit tests for [DeleteRoomCubit] (F-R04-T3 — presentation layer).
///
/// Mirrors `edit_room_cubit_test.dart`, simplified: [DeleteRoomUseCase]
/// returns `void` on success, so [DeleteRoomState.success] carries no
/// payload, unlike `EditRoomState.success(room)`.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios R-DEL-01, R-DEL-04.
void main() {
  late MockDeleteRoomUseCase deleteRoomUseCase;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';

  setUp(() {
    deleteRoomUseCase = MockDeleteRoomUseCase();
  });

  DeleteRoomCubit buildCubit() => DeleteRoomCubit(deleteRoomUseCase);

  group('deleteRoom', () {
    blocTest<DeleteRoomCubit, DeleteRoomState>(
      'emits [loading, success] on success (R-DEL-01)',
      build: () {
        when(
          () => deleteRoomUseCase(roomId),
        ).thenAnswer((_) async => const Right(null));
        return buildCubit();
      },
      act: (cubit) => cubit.deleteRoom(roomId),
      expect: () => [
        const DeleteRoomState.loading(),
        const DeleteRoomState.success(),
      ],
    );

    blocTest<DeleteRoomCubit, DeleteRoomState>(
      'emits [loading, failure] on a 403 (non-owner) (R-DEL-04)',
      build: () {
        when(() => deleteRoomUseCase(roomId)).thenAnswer(
          (_) async => const Left(
            Failure.auth(
              message: 'Only the owner of this room may perform this action.',
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.deleteRoom(roomId),
      expect: () => [
        const DeleteRoomState.loading(),
        isA<DeleteRoomFailure>().having(
          (s) => s.failure,
          'failure',
          isA<AuthFailure>(),
        ),
      ],
    );

    blocTest<DeleteRoomCubit, DeleteRoomState>(
      'emits [loading, failure] on a network failure',
      build: () {
        when(
          () => deleteRoomUseCase(roomId),
        ).thenAnswer((_) async => const Left(Failure.network()));
        return buildCubit();
      },
      act: (cubit) => cubit.deleteRoom(roomId),
      expect: () => [
        const DeleteRoomState.loading(),
        const DeleteRoomState.failure(Failure.network()),
      ],
    );
  });
}
