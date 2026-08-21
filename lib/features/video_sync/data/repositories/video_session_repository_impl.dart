import 'package:either_dart/either.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/video_session_metadata_entity.dart';
import '../../domain/repositories/i_video_session_repository.dart';
import '../datasources/i_video_session_remote_data_source.dart';

/// Data layer implementation of [IVideoSessionRepository].
///
/// Mirrors `RoomRepositoryImpl.getRoomById`'s exception-to-[Failure]
/// mapping exactly, including the 404 -> [NotFoundFailure] special case
/// (the backend's `VideoSessionExceptionFilter` maps both "room does
/// not exist" and "room exists but has no session yet" to the same
/// HTTP 404 — see `IVideoSessionRemoteDataSource.getByRoomId`'s own doc
/// comment).
class VideoSessionRepositoryImpl implements IVideoSessionRepository {
  VideoSessionRepositoryImpl({
    required IVideoSessionRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final IVideoSessionRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, VideoSessionMetadataEntity>> getByRoomId({
    required String roomId,
  }) async {
    try {
      final model = await _remoteDataSource.getByRoomId(roomId: roomId);

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
}
