import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/core/usecases/usecase.dart';
import 'package:youtogether/features/room/domain/entities/room_entity.dart';
import 'package:youtogether/features/room/domain/repositories/i_room_repository.dart';
import 'package:youtogether/features/room/domain/usecases/get_public_rooms_usecase.dart';

class MockIRoomRepository extends Mock implements IRoomRepository {}

/// Unit tests for [GetPublicRoomsUseCase].
///
/// The use case is a thin orchestrator; these tests verify delegation to
/// [IRoomRepository.getPublicRooms], mirroring
/// `get_current_user_usecase_test.dart`.
///
/// @competency Unit test harness, TDD cycle.
void main() {
  late MockIRoomRepository roomRepository;
  late GetPublicRoomsUseCase getPublicRoomsUseCase;

  final rooms = [
    RoomEntity(
      id: '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f',
      name: 'Friday Movie Night',
      description: 'Weekly watch party',
      ownerId: '550e8400-e29b-41d4-a716-446655440000',
      isPublic: true,
      memberCount: 3,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
    RoomEntity(
      id: '8c3f7c1b-3f3b-5c7b-9f3b-2b3c4d5e6f70',
      name: 'Saturday Anime Marathon',
      description: null,
      ownerId: '660e8400-e29b-41d4-a716-446655440001',
      isPublic: true,
      memberCount: 1,
      createdAt: DateTime.utc(2026, 1, 2),
      updatedAt: DateTime.utc(2026, 1, 2),
    ),
  ];

  setUp(() {
    roomRepository = MockIRoomRepository();
    getPublicRoomsUseCase = GetPublicRoomsUseCase(roomRepository);
  });

  group('GetPublicRoomsUseCase', () {
    test('should delegate to IRoomRepository.getPublicRooms', () async {
      when(
        () => roomRepository.getPublicRooms(),
      ).thenAnswer((_) async => Right(rooms));

      await getPublicRoomsUseCase(const NoParams());

      verify(() => roomRepository.getPublicRooms()).called(1);
    });

    test('should return Right(rooms) on success', () async {
      when(
        () => roomRepository.getPublicRooms(),
      ).thenAnswer((_) async => Right(rooms));

      final result = await getPublicRoomsUseCase(const NoParams());

      expect(result.isRight, isTrue);
      expect(result.right, rooms);
    });

    test('should return an empty list when no public rooms exist', () async {
      when(
        () => roomRepository.getPublicRooms(),
      ).thenAnswer((_) async => const Right([]));

      final result = await getPublicRoomsUseCase(const NoParams());

      expect(result.right, isEmpty);
    });

    test(
      'should propagate Left(Failure) unchanged on repository failure',
      () async {
        when(
          () => roomRepository.getPublicRooms(),
        ).thenAnswer((_) async => const Left(Failure.network()));

        final result = await getPublicRoomsUseCase(const NoParams());

        expect(result.isLeft, isTrue);
        expect(result.left, const Failure.network());
      },
    );
  });
}
