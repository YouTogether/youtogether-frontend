import 'package:either_dart/either.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/room_entity.dart';
import '../../domain/repositories/i_room_repository.dart';
import '../datasources/i_room_remote_data_source.dart';

/// Data layer implementation of [IRoomRepository].
///
/// Mirrors `AuthRepositoryImpl`'s exception-to-[Failure] mapping:
/// [ServerException] becomes [ServerFailure] (carrying the original
/// status code and message), [NetworkException] becomes
/// [NetworkFailure]. No other exception type is expected from
/// [IRoomRemoteDataSource] at this stage; anything else propagates
/// unhandled rather than being silently swallowed.
///
/// All six [IRoomRepository] methods are now fully implemented:
/// `getPublicRooms`, `createRoom`, `updateRoom`,
/// `getRoomById`, `joinRoom`, `deleteRoom`, and `leaveRoom`
///
/// @see IRoomRepository — the domain port being implemented
class RoomRepositoryImpl implements IRoomRepository {
  RoomRepositoryImpl({required IRoomRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final IRoomRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, List<RoomEntity>>> getPublicRooms() async {
    try {
      final models = await _remoteDataSource.getPublicRooms();

      return Right(models.map((model) => model.toDomain()).toList());
    } on ServerException catch (exception) {
      return Left(
        Failure.server(
          statusCode: exception.statusCode,
          message: exception.message,
        ),
      );
    } on NetworkException {
      return const Left(Failure.network());
    }
  }

  @override
  Future<Either<Failure, RoomEntity>> createRoom({
    required String name,
    required String? description,
    required bool isPublic,
  }) async {
    try {
      final model = await _remoteDataSource.createRoom(
        name: name,
        description: description,
        isPublic: isPublic,
      );

      return Right(model.toDomain());
    } on ServerException catch (exception) {
      return Left(
        Failure.server(
          statusCode: exception.statusCode,
          message: exception.message,
        ),
      );
    } on NetworkException {
      return const Left(Failure.network());
    }
  }

  @override
  Future<Either<Failure, RoomEntity>> getRoomById({
    required String roomId,
  }) async {
    try {
      final model = await _remoteDataSource.getRoomById(roomId: roomId);

      return Right(model.toDomain());
    } on ServerException catch (exception) {
      if (exception.statusCode == 404) {
        return const Left(Failure.notFound());
      }
      return Left(
        Failure.server(
          statusCode: exception.statusCode,
          message: exception.message,
        ),
      );
    } on NetworkException {
      return const Left(Failure.network());
    }
  }

  @override
  Future<Either<Failure, RoomEntity>> updateRoom({
    required String roomId,
    String? name,
    String? description,
  }) async {
    try {
      final model = await _remoteDataSource.updateRoom(
        roomId: roomId,
        name: name,
        description: description,
      );

      return Right(model.toDomain());
    } on ServerException catch (exception) {
      if (exception.statusCode == 403) {
        return const Left(
          Failure.auth(
            message: 'Only the owner of this room may perform this action.',
          ),
        );
      }
      if (exception.statusCode == 404) {
        return const Left(Failure.notFound());
      }
      return Left(
        Failure.server(
          statusCode: exception.statusCode,
          message: exception.message,
        ),
      );
    } on NetworkException {
      return const Left(Failure.network());
    }
  }

  @override
  Future<Either<Failure, void>> deleteRoom({required String roomId}) async {
    try {
      await _remoteDataSource.deleteRoom(roomId: roomId);

      return const Right(null);
    } on ServerException catch (exception) {
      if (exception.statusCode == 403) {
        return const Left(
          Failure.auth(
            message: 'Only the owner of this room may perform this action.',
          ),
        );
      }
      if (exception.statusCode == 404) {
        return const Left(Failure.notFound());
      }
      return Left(
        Failure.server(
          statusCode: exception.statusCode,
          message: exception.message,
        ),
      );
    } on NetworkException {
      return const Left(Failure.network());
    }
  }

  @override
  Future<Either<Failure, RoomEntity>> joinRoom({required String roomId}) async {
    try {
      final model = await _remoteDataSource.joinRoom(roomId: roomId);

      return Right(model.toDomain());
    } on ServerException catch (exception) {
      if (exception.statusCode == 404) {
        return const Left(Failure.notFound());
      }
      // Includes the 409 duplicate-active-membership case: no dedicated
      // Failure variant exists for it (only seven variants total — see
      // core/error/failures.dart), so it surfaces as a generic
      // ServerFailure carrying statusCode: 409, exactly like the
      // backend integration test suite's own expectation.
      return Left(
        Failure.server(
          statusCode: exception.statusCode,
          message: exception.message,
        ),
      );
    } on NetworkException {
      return const Left(Failure.network());
    }
  }

  @override
  Future<Either<Failure, void>> leaveRoom({required String roomId}) async {
    try {
      await _remoteDataSource.leaveRoom(roomId: roomId);

      return const Right(null);
    } on ServerException catch (exception) {
      if (exception.statusCode == 403) {
        return const Left(
          Failure.auth(
            message:
                'The owner of this room cannot leave it; delete the room '
                'instead.',
          ),
        );
      }
      if (exception.statusCode == 404) {
        return const Left(Failure.notFound());
      }
      return Left(
        Failure.server(
          statusCode: exception.statusCode,
          message: exception.message,
        ),
      );
    } on NetworkException {
      return const Left(Failure.network());
    }
  }
}
