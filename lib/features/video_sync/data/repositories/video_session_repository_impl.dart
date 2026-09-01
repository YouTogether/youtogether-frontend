import 'package:either_dart/either.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/video_session_metadata_entity.dart';
import '../../domain/repositories/i_video_session_repository.dart';
import '../datasources/i_video_session_remote_data_source.dart';

/// Data layer implementation of [IVideoSessionRepository].
///
/// Mirrors `RoomRepositoryImpl`'s exception-to-[Failure] mapping
/// exactly, including the 404 -> [NotFoundFailure] special case (the
/// backend's `VideoSessionExceptionFilter` maps both "room does not
/// exist" and "room exists but has no session yet" to the same HTTP 404
/// — see `IVideoSessionRemoteDataSource.getByRoomId`'s own doc comment)
/// and, for [create], the 403 -> [AuthFailure] case `updateRoom`,
/// `deleteRoom` and `leaveRoom` already establish for a non-owner.
///
/// The two methods map the same status codes differently in exactly one
/// respect, and deliberately: [getByRoomId] has no 403 branch because
/// reading a session is open to every authenticated participant
/// (`JwtAuthGuard` only), while creating one is owner-only
/// (`JwtAuthGuard` and `OwnershipGuard`).
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

  @override
  Future<Either<Failure, VideoSessionMetadataEntity>> create({
    required String roomId,
    required String youtubeVideoId,
  }) async {
    try {
      final model = await _remoteDataSource.create(
        roomId: roomId,
        youtubeVideoId: youtubeVideoId,
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
      // 400 (malformed id, or YouTube reports no such video) and 502
      // (YouTube unreachable, or the Realtime Database write failed)
      // both surface as ServerFailure carrying their status code. No
      // dedicated Failure variant exists for either — only seven exist
      // in total, see core/error/failures.dart — and the status code is
      // what the form needs to tell "this video does not exist" apart
      // from "try again shortly", so it must survive the mapping.
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
