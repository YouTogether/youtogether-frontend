import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/room/domain/entities/room_entity.dart';
import 'package:youtogether/features/room/domain/repositories/i_room_repository.dart';
import 'package:youtogether/features/room/domain/usecases/get_room_by_id_usecase.dart';

class MockIRoomRepository extends Mock implements IRoomRepository {}

/// Unit tests for [GetRoomByIdUseCase] (frontend prerequisite for
/// `RoomDetailPage`, identified as a backlog gap during `F-R02-T3` and
/// recorded in `sprint-2-room-planning.md` §5 — mirrors the backend's
/// `B-R03-T1`).
///
/// No dedicated `GetRoomByIdParams` value object, for the same reason
/// as `DeleteRoomUseCase`/`JoinRoomUseCase`/`LeaveRoomUseCase`: the
/// input is simply the room's id, and a single-field wrapper would add
/// no value over the `String` itself.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios R-DET-01, R-DET-02, R-DET-03.
void main() {
  late MockIRoomRepository roomRepository;
  late GetRoomByIdUseCase getRoomByIdUseCase;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';

  final room = RoomEntity(
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
    getRoomByIdUseCase = GetRoomByIdUseCase(roomRepository);
  });

  group('GetRoomByIdUseCase', () {
    test(
      'should delegate to IRoomRepository.getRoomById with the room id',
      () async {
        when(
          () => roomRepository.getRoomById(roomId: any(named: 'roomId')),
        ).thenAnswer((_) async => Right(room));

        await getRoomByIdUseCase(roomId);

        verify(() => roomRepository.getRoomById(roomId: roomId)).called(1);
      },
    );

    test('should return Right(room) on success (R-DET-01)', () async {
      when(
        () => roomRepository.getRoomById(roomId: any(named: 'roomId')),
      ).thenAnswer((_) async => Right(room));

      final result = await getRoomByIdUseCase(roomId);

      expect(result.isRight, isTrue);
      expect(result.right, room);
    });

    test('should propagate a not-found failure unchanged (missing or deleted '
        'room, R-DET-02/R-DET-03)', () async {
      when(
        () => roomRepository.getRoomById(roomId: any(named: 'roomId')),
      ).thenAnswer((_) async => const Left(Failure.notFound()));

      final result = await getRoomByIdUseCase(roomId);

      expect(result.isLeft, isTrue);
      expect(result.left, const Failure.notFound());
    });

    test(
      'should propagate Left(Failure) unchanged on network failure',
      () async {
        when(
          () => roomRepository.getRoomById(roomId: any(named: 'roomId')),
        ).thenAnswer((_) async => const Left(Failure.network()));

        final result = await getRoomByIdUseCase(roomId);

        expect(result.left, isA<NetworkFailure>());
      },
    );
  });
}
