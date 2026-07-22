import 'package:bloc_test/bloc_test.dart';
import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/room/domain/entities/room_entity.dart';
import 'package:youtogether/features/room/domain/usecases/join_room_usecase.dart';
import 'package:youtogether/features/room/presentation/cubit/join_room_cubit.dart';
import 'package:youtogether/features/room/presentation/cubit/join_room_state.dart';

class MockJoinRoomUseCase extends Mock implements JoinRoomUseCase {}

/// Unit tests for [JoinRoomCubit].
///
/// Mirrors `leave_room_cubit_test.dart`/`DeleteRoomCubit` in structure.
/// [JoinRoomState.loading] carries the joining room's id — needed by
/// `HomePage`, which shares a single cubit across every `RoomCard` and
/// must know *which* card to show a per-item spinner on, unlike
/// `LeaveRoomCubit`/`DeleteRoomCubit`, each scoped to a single room
/// already known from context.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios R-JOI-01, R-JOI-03, R-JOI-04.
void main() {
  late MockJoinRoomUseCase joinRoomUseCase;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';

  final joinedRoom = RoomEntity(
    id: roomId,
    name: 'Friday Movie Night',
    description: 'Weekly watch party',
    ownerId: '550e8400-e29b-41d4-a716-446655440000',
    isPublic: true,
    memberCount: 2,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    joinRoomUseCase = MockJoinRoomUseCase();
  });

  JoinRoomCubit buildCubit() => JoinRoomCubit(joinRoomUseCase);

  group('joinRoom', () {
    blocTest<JoinRoomCubit, JoinRoomState>(
      'emits [loading(roomId), success(room)] on success (R-JOI-01)',
      build: () {
        when(
          () => joinRoomUseCase(roomId),
        ).thenAnswer((_) async => Right(joinedRoom));
        return buildCubit();
      },
      act: (cubit) => cubit.joinRoom(roomId),
      expect: () => [
        const JoinRoomState.loading(roomId),
        JoinRoomState.success(joinedRoom),
      ],
    );

    blocTest<JoinRoomCubit, JoinRoomState>(
      'emits [loading(roomId), failure] on a duplicate-membership '
      'conflict (R-JOI-03)',
      build: () {
        when(() => joinRoomUseCase(roomId)).thenAnswer(
          (_) async => const Left(
            Failure.server(
              statusCode: 409,
              message: 'already an active member',
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.joinRoom(roomId),
      expect: () => [
        const JoinRoomState.loading(roomId),
        isA<JoinRoomFailure>(),
      ],
    );

    blocTest<JoinRoomCubit, JoinRoomState>(
      'emits [loading(roomId), failure] on a not-found failure (R-JOI-04)',
      build: () {
        when(
          () => joinRoomUseCase(roomId),
        ).thenAnswer((_) async => const Left(Failure.notFound()));
        return buildCubit();
      },
      act: (cubit) => cubit.joinRoom(roomId),
      expect: () => [
        const JoinRoomState.loading(roomId),
        const JoinRoomState.failure(Failure.notFound()),
      ],
    );
  });
}
