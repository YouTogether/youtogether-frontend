import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/room/domain/entities/room_entity.dart';
import 'package:youtogether/features/room/domain/repositories/i_room_repository.dart';
import 'package:youtogether/features/room/domain/usecases/create_room_params.dart';
import 'package:youtogether/features/room/domain/usecases/create_room_usecase.dart';

class MockIRoomRepository extends Mock implements IRoomRepository {}

/// Unit tests for [CreateRoomUseCase] and [CreateRoomParams].
///
/// The use case is a thin orchestrator; these tests verify delegation to
/// [IRoomRepository.createRoom], mirroring
/// `get_public_rooms_usecase_test.dart` and the backend's
/// `create-room.usecase.spec.ts`.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenario R-CRE-01 (creation delegation).
void main() {
  late MockIRoomRepository roomRepository;
  late CreateRoomUseCase createRoomUseCase;

  final validParams = CreateRoomParams(
    name: 'Friday Movie Night',
    description: 'Weekly watch party',
    isPublic: true,
  );

  final createdRoom = RoomEntity(
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
    roomRepository = MockIRoomRepository();
    createRoomUseCase = CreateRoomUseCase(roomRepository);
  });

  group('CreateRoomUseCase', () {
    test(
      'should delegate to IRoomRepository.createRoom with the unpacked params',
      () async {
        when(
          () => roomRepository.createRoom(
            name: any(named: 'name'),
            description: any(named: 'description'),
            isPublic: any(named: 'isPublic'),
          ),
        ).thenAnswer((_) async => Right(createdRoom));

        await createRoomUseCase(validParams);

        verify(
          () => roomRepository.createRoom(
            name: 'Friday Movie Night',
            description: 'Weekly watch party',
            isPublic: true,
          ),
        ).called(1);
      },
    );

    test('should return Right(room) on success', () async {
      when(
        () => roomRepository.createRoom(
          name: any(named: 'name'),
          description: any(named: 'description'),
          isPublic: any(named: 'isPublic'),
        ),
      ).thenAnswer((_) async => Right(createdRoom));

      final result = await createRoomUseCase(validParams);

      expect(result.isRight, isTrue);
      expect(result.right, createdRoom);
    });

    test(
      'should propagate Left(Failure) unchanged on repository failure',
      () async {
        when(
          () => roomRepository.createRoom(
            name: any(named: 'name'),
            description: any(named: 'description'),
            isPublic: any(named: 'isPublic'),
          ),
        ).thenAnswer(
          (_) async => const Left(
            Failure.validation(
              errors: {'name': 'name must not exceed 100 characters'},
            ),
          ),
        );

        final result = await createRoomUseCase(validParams);

        expect(result.isLeft, isTrue);
        expect(result.left, isA<ValidationFailure>());
      },
    );

    test('should forward a null description unchanged', () async {
      final paramsWithoutDescription = CreateRoomParams(
        name: 'Friday Movie Night',
        description: null,
        isPublic: true,
      );
      when(
        () => roomRepository.createRoom(
          name: any(named: 'name'),
          description: any(named: 'description'),
          isPublic: any(named: 'isPublic'),
        ),
      ).thenAnswer((_) async => Right(createdRoom));

      await createRoomUseCase(paramsWithoutDescription);

      verify(
        () => roomRepository.createRoom(
          name: 'Friday Movie Night',
          description: null,
          isPublic: true,
        ),
      ).called(1);
    });
  });

  group('CreateRoomParams', () {
    test('should store name, description, and isPublic as fields', () {
      final params = CreateRoomParams(
        name: 'Room Name',
        description: 'Some description',
        isPublic: false,
      );

      expect(params.name, 'Room Name');
      expect(params.description, 'Some description');
      expect(params.isPublic, false);
    });

    test('should support a null description', () {
      final params = CreateRoomParams(
        name: 'Room Name',
        description: null,
        isPublic: true,
      );

      expect(params.description, isNull);
    });

    test('should support value equality (freezed)', () {
      final a = CreateRoomParams(
        name: 'Room Name',
        description: 'Description',
        isPublic: true,
      );
      final b = CreateRoomParams(
        name: 'Room Name',
        description: 'Description',
        isPublic: true,
      );

      expect(a, b);
    });
  });
}
