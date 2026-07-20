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
/// ## Incremental implementation status
/// [IRoomRepository] was completed in full across the domain-layer
/// tasks before any data-layer task began —
/// unlike the backend, where the repository interface and its
/// implementation grew in lockstep, one method per task. Dart requires
/// every abstract method of an implemented interface to have a body to
/// compile at all, so this class must already declare all six methods
/// today even though only [getPublicRooms] is in scope.
///
/// [createRoom], [updateRoom], [deleteRoom], [joinRoom], and [leaveRoom]
/// therefore throw [UnimplementedError] for now, each annotated with
/// the task that will replace it with a real implementation.
/// This is a deliberate, visible placeholder — not a silently swallowed
/// gap — and is called out explicitly here rather than discovered later.
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
  }) {
    throw UnimplementedError(
      'RoomRepositoryImpl.createRoom will be implemented later.',
    );
  }

  @override
  Future<Either<Failure, RoomEntity>> updateRoom({
    required String roomId,
    String? name,
    String? description,
  }) {
    throw UnimplementedError(
      'RoomRepositoryImpl.updateRoom will be implemented later.',
    );
  }

  @override
  Future<Either<Failure, void>> deleteRoom({required String roomId}) {
    throw UnimplementedError(
      'RoomRepositoryImpl.deleteRoom will be implemented later.',
    );
  }

  @override
  Future<Either<Failure, RoomEntity>> joinRoom({required String roomId}) {
    throw UnimplementedError(
      'RoomRepositoryImpl.joinRoom will be implemented later.',
    );
  }

  @override
  Future<Either<Failure, void>> leaveRoom({required String roomId}) {
    throw UnimplementedError(
      'RoomRepositoryImpl.leaveRoom will be implemented later.',
    );
  }
}
