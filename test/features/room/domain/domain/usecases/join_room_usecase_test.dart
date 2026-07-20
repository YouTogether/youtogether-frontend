import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/room/domain/entities/room_entity.dart';
import 'package:youtogether/features/room/domain/repositories/i_room_repository.dart';
import 'package:youtogether/features/room/domain/usecases/join_room_usecase.dart';

class MockIRoomRepository extends Mock implements IRoomRepository {}

/// Unit tests for [JoinRoomUseCase].
///
/// The use case is a thin orchestrator; these tests verify delegation to
/// [IRoomRepository.joinRoom], mirroring `delete_room_usecase_test.dart`
/// and the backend's own `join-room.usecase.spec.ts`.
///
/// No dedicated `JoinRoomParams` value object, for the same reason as
/// `DeleteRoomUseCase`: this task's Definition of Done describes the
/// use case as taking a room ID directly — the joining user's identity
/// is derived server-side from the authenticated request, never
/// supplied by the caller (unlike the backend's own `JoinRoomParams`,
/// which does carry `userId` because the backend has no other way to
/// know it at that layer).
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios R-JOI-01, R-JOI-03, R-JOI-04.
void main() {
  late MockIRoomRepository roomRepository;
  late JoinRoomUseCase joinRoomUseCase;

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
    roomRepository = MockIRoomRepository();
    joinRoomUseCase = JoinRoomUseCase(roomRepository);
  });

  group('JoinRoomUseCase', () {
    test(
      'should delegate to IRoomRepository.joinRoom with the room id',
      () async {
        when(
          () => roomRepository.joinRoom(roomId: any(named: 'roomId')),
        ).thenAnswer((_) async => Right(joinedRoom));

        await joinRoomUseCase(roomId);

        verify(() => roomRepository.joinRoom(roomId: roomId)).called(1);
      },
    );

    test(
      'should return Right(room) with the refreshed member count on success (R-JOI-01)',
      () async {
        when(
          () => roomRepository.joinRoom(roomId: any(named: 'roomId')),
        ).thenAnswer((_) async => Right(joinedRoom));

        final result = await joinRoomUseCase(roomId);

        expect(result.isRight, isTrue);
        expect(result.right.memberCount, 2);
      },
    );

    test(
      'should propagate a duplicate-membership failure unchanged (R-JOI-03)',
      () async {
        when(
          () => roomRepository.joinRoom(roomId: any(named: 'roomId')),
        ).thenAnswer(
          (_) async => const Left(
            Failure.server(
              statusCode: 409,
              message: 'already an active member',
            ),
          ),
        );

        final result = await joinRoomUseCase(roomId);

        expect(result.isLeft, isTrue);
        expect((result.left as ServerFailure).statusCode, 409);
      },
    );

    test('should propagate a not-found failure unchanged (R-JOI-04)', () async {
      when(
        () => roomRepository.joinRoom(roomId: any(named: 'roomId')),
      ).thenAnswer((_) async => const Left(Failure.notFound()));

      final result = await joinRoomUseCase(roomId);

      expect(result.left, const Failure.notFound());
    });
  });
}
