import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/room/domain/entities/room_entity.dart';
import 'package:youtogether/features/room/domain/repositories/i_room_repository.dart';
import 'package:youtogether/features/room/domain/usecases/update_room_params.dart';
import 'package:youtogether/features/room/domain/usecases/update_room_usecase.dart';

class MockIRoomRepository extends Mock implements IRoomRepository {}

/// Unit tests for [UpdateRoomUseCase] and [UpdateRoomParams].
///
/// The use case is a thin orchestrator; these tests verify delegation to
/// [IRoomRepository.updateRoom], mirroring
/// `create_room_usecase_test.dart` and the backend's
/// `update-room.usecase.spec.ts`. Ownership authorization is NOT this
/// use case's concern — it is enforced server-side (`OwnershipGuard`)
/// and, on the client, by hiding the edit action for non-owners,
/// not by this layer.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios R-UPD-01, R-UPD-02 (partial update).
void main() {
  late MockIRoomRepository roomRepository;
  late UpdateRoomUseCase updateRoomUseCase;

  final validParams = UpdateRoomParams(
    roomId: '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f',
    name: 'Renamed Movie Night',
    description: 'Updated description',
  );

  final updatedRoom = RoomEntity(
    id: validParams.roomId,
    name: 'Renamed Movie Night',
    description: 'Updated description',
    ownerId: '550e8400-e29b-41d4-a716-446655440000',
    isPublic: true,
    memberCount: 2,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 5),
  );

  setUp(() {
    roomRepository = MockIRoomRepository();
    updateRoomUseCase = UpdateRoomUseCase(roomRepository);
  });

  group('UpdateRoomUseCase', () {
    test(
      'should delegate to IRoomRepository.updateRoom with the unpacked params',
      () async {
        when(
          () => roomRepository.updateRoom(
            roomId: any(named: 'roomId'),
            name: any(named: 'name'),
            description: any(named: 'description'),
          ),
        ).thenAnswer((_) async => Right(updatedRoom));

        await updateRoomUseCase(validParams);

        verify(
          () => roomRepository.updateRoom(
            roomId: validParams.roomId,
            name: 'Renamed Movie Night',
            description: 'Updated description',
          ),
        ).called(1);
      },
    );

    test('should return Right(room) on success', () async {
      when(
        () => roomRepository.updateRoom(
          roomId: any(named: 'roomId'),
          name: any(named: 'name'),
          description: any(named: 'description'),
        ),
      ).thenAnswer((_) async => Right(updatedRoom));

      final result = await updateRoomUseCase(validParams);

      expect(result.isRight, isTrue);
      expect(result.right, updatedRoom);
    });

    test(
      'should support a partial update (description only, name omitted) (R-UPD-02)',
      () async {
        final partialParams = UpdateRoomParams(
          roomId: validParams.roomId,
          description: 'Only description changes',
        );
        when(
          () => roomRepository.updateRoom(
            roomId: any(named: 'roomId'),
            name: any(named: 'name'),
            description: any(named: 'description'),
          ),
        ).thenAnswer((_) async => Right(updatedRoom));

        await updateRoomUseCase(partialParams);

        verify(
          () => roomRepository.updateRoom(
            roomId: validParams.roomId,
            name: null,
            description: 'Only description changes',
          ),
        ).called(1);
      },
    );

    test(
      'should propagate Left(Failure) unchanged on repository failure',
      () async {
        when(
          () => roomRepository.updateRoom(
            roomId: any(named: 'roomId'),
            name: any(named: 'name'),
            description: any(named: 'description'),
          ),
        ).thenAnswer(
          (_) async => const Left(Failure.auth(message: 'not the owner')),
        );

        final result = await updateRoomUseCase(validParams);

        expect(result.isLeft, isTrue);
        expect(result.left, isA<AuthFailure>());
      },
    );
  });

  group('UpdateRoomParams', () {
    test('should store roomId, name, and description as fields', () {
      final params = UpdateRoomParams(
        roomId: 'room-id-value',
        name: 'New Name',
        description: 'New description',
      );

      expect(params.roomId, 'room-id-value');
      expect(params.name, 'New Name');
      expect(params.description, 'New description');
    });

    test(
      'should default name and description to null when omitted (partial update)',
      () {
        final params = UpdateRoomParams(roomId: 'room-id-value');

        expect(params.name, isNull);
        expect(params.description, isNull);
      },
    );

    test('should support value equality (freezed)', () {
      final a = UpdateRoomParams(roomId: 'room-id-value', name: 'Name');
      final b = UpdateRoomParams(roomId: 'room-id-value', name: 'Name');

      expect(a, b);
    });
  });
}
