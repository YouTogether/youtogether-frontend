import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/exceptions.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/room/data/datasources/i_room_remote_data_source.dart';
import 'package:youtogether/features/room/data/models/room_model.dart';
import 'package:youtogether/features/room/data/repositories/room_repository_impl.dart';

class MockIRoomRemoteDataSource extends Mock implements IRoomRemoteDataSource {}

/// Unit tests for [RoomRepositoryImpl.getPublicRooms]
/// (F-R01-T2 — data layer).
///
/// Mirrors `auth_repository_impl_test.dart`: a mocked remote data
/// source, verifying the exception-to-[Failure] mapping.
///
/// The other four [IRoomRepository] methods on this class are
/// intentionally stubbed with [UnimplementedError] at this stage — see
/// [RoomRepositoryImpl]'s own class doc — and are therefore not
/// exercised here; each will get its own test coverage when its
/// corresponding task (F-R02-T2 through F-R06-T2) implements it for
/// real.
///
/// @competency Unit test harness, TDD cycle.
void main() {
  late MockIRoomRemoteDataSource remoteDataSource;
  late RoomRepositoryImpl roomRepository;

  final roomModels = [
    RoomModel.fromJson({
      'id': '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f',
      'name': 'Friday Movie Night',
      'description': 'Weekly watch party',
      'ownerId': '550e8400-e29b-41d4-a716-446655440000',
      'isPublic': true,
      'memberCount': 3,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-01T00:00:00.000Z',
    }),
  ];

  setUp(() {
    remoteDataSource = MockIRoomRemoteDataSource();
    roomRepository = RoomRepositoryImpl(remoteDataSource: remoteDataSource);
  });

  group('RoomRepositoryImpl.getPublicRooms', () {
    test('should return Right(List<RoomEntity>) on success', () async {
      when(
        () => remoteDataSource.getPublicRooms(),
      ).thenAnswer((_) async => roomModels);

      final result = await roomRepository.getPublicRooms();

      expect(result.isRight, isTrue);
      expect(result.right, hasLength(1));
      expect(result.right.first.name, 'Friday Movie Night');
    });

    test('should map a ServerException to Left(ServerFailure)', () async {
      when(() => remoteDataSource.getPublicRooms()).thenThrow(
        const ServerException(statusCode: 500, message: 'Internal error'),
      );

      final result = await roomRepository.getPublicRooms();

      expect(result.isLeft, isTrue);
      expect(
        result.left,
        const Failure.server(statusCode: 500, message: 'Internal error'),
      );
    });

    test('should map a NetworkException to Left(NetworkFailure)', () async {
      when(
        () => remoteDataSource.getPublicRooms(),
      ).thenThrow(const NetworkException());

      final result = await roomRepository.getPublicRooms();

      expect(result.isLeft, isTrue);
      expect(result.left, isA<NetworkFailure>());
    });
  });

  group('RoomRepositoryImpl.createRoom', () {
    test('should return Right(RoomEntity) on success', () async {
      when(
        () => remoteDataSource.createRoom(
          name: any(named: 'name'),
          description: any(named: 'description'),
          isPublic: any(named: 'isPublic'),
        ),
      ).thenAnswer((_) async => roomModels.first);

      final result = await roomRepository.createRoom(
        name: 'Friday Movie Night',
        description: 'Weekly watch party',
        isPublic: true,
      );

      expect(result.isRight, isTrue);
      expect(result.right.name, 'Friday Movie Night');
    });

    test(
      'should delegate to the remote data source with the given fields',
      () async {
        when(
          () => remoteDataSource.createRoom(
            name: any(named: 'name'),
            description: any(named: 'description'),
            isPublic: any(named: 'isPublic'),
          ),
        ).thenAnswer((_) async => roomModels.first);

        await roomRepository.createRoom(
          name: 'Friday Movie Night',
          description: 'Weekly watch party',
          isPublic: true,
        );

        verify(
          () => remoteDataSource.createRoom(
            name: 'Friday Movie Night',
            description: 'Weekly watch party',
            isPublic: true,
          ),
        ).called(1);
      },
    );

    test('should map a ServerException to Left(ServerFailure)', () async {
      when(
        () => remoteDataSource.createRoom(
          name: any(named: 'name'),
          description: any(named: 'description'),
          isPublic: any(named: 'isPublic'),
        ),
      ).thenThrow(
        const ServerException(
          statusCode: 400,
          message: 'name must not exceed 100 characters',
        ),
      );

      final result = await roomRepository.createRoom(
        name: 'Friday Movie Night',
        description: null,
        isPublic: true,
      );

      expect(result.isLeft, isTrue);
      expect((result.left as ServerFailure).statusCode, 400);
    });

    test('should map a NetworkException to Left(NetworkFailure)', () async {
      when(
        () => remoteDataSource.createRoom(
          name: any(named: 'name'),
          description: any(named: 'description'),
          isPublic: any(named: 'isPublic'),
        ),
      ).thenThrow(const NetworkException());

      final result = await roomRepository.createRoom(
        name: 'Friday Movie Night',
        description: null,
        isPublic: true,
      );

      expect(result.isLeft, isTrue);
      expect(result.left, isA<NetworkFailure>());
    });
  });
}
