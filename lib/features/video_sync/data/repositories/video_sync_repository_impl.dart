import 'package:either_dart/either.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/video_session_entity.dart';
import '../../domain/repositories/i_video_sync_repository.dart';
import '../datasources/i_video_sync_remote_data_source.dart';

/// Data layer implementation of [IVideoSyncRepository].
///
/// Mirrors `RoomRepositoryImpl`'s exception-to-[Failure] mapping
/// pattern, but with a single exception type to map: every
/// [IVideoSyncRemoteDataSource] method throws only
/// `FirebaseException` (see that interface's own doc comment), so
/// every method here has exactly one `catch` clause, always producing
/// [FirebaseFailure].
///
/// [subscribeToPlaybackState] additionally converts a *stream* error
/// (e.g. Firebase connectivity lost mid-session, VS-SYN-06) into a
/// `Left(FirebaseFailure)` **event** on the returned stream, rather
/// than letting the stream itself close with an error — this is what
/// lets `VideoSyncBloc` (F-V03-T2) react with `VideoSyncState.failure`
/// and a retry option instead of the subscription dying silently.
///
/// @see IVideoSyncRepository — the domain port being implemented
class VideoSyncRepositoryImpl implements IVideoSyncRepository {
  VideoSyncRepositoryImpl({
    required IVideoSyncRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final IVideoSyncRemoteDataSource _remoteDataSource;

  Failure _toFailure(Object error) {
    if (error is FirebaseException) {
      return Failure.firebase(
        message: error.message ?? 'Unknown Firebase error',
      );
    }
    return Failure.firebase(message: error.toString());
  }

  @override
  Future<Either<Failure, void>> updatePlaybackState({
    required String roomId,
    required bool isPlaying,
    required Duration position,
  }) async {
    try {
      await _remoteDataSource.updatePlaybackState(
        roomId: roomId,
        isPlaying: isPlaying,
        position: position,
      );
      return const Right(null);
    } on FirebaseException catch (exception) {
      return Left(_toFailure(exception));
    }
  }

  @override
  Future<Either<Failure, VideoSessionEntity>> getCurrentPlaybackState({
    required String roomId,
  }) async {
    try {
      final model = await _remoteDataSource.getCurrentPlaybackState(
        roomId: roomId,
      );
      return Right(model.toDomain());
    } on FirebaseException catch (exception) {
      return Left(_toFailure(exception));
    }
  }

  @override
  Stream<Either<Failure, VideoSessionEntity>> subscribeToPlaybackState({
    required String roomId,
  }) async* {
    try {
      await for (final model in _remoteDataSource.subscribeToPlaybackState(
        roomId: roomId,
      )) {
        yield Right(model.toDomain());
      }
    } on FirebaseException catch (exception) {
      // A stream error (e.g. Firebase connectivity lost mid-session,
      // VS-SYN-06) surfaces here as a single Left(FirebaseFailure)
      // *event* rather than closing the stream with an error — this is
      // what lets VideoSyncBloc react with VideoSyncState.failure and a
      // retry option, instead of the subscription dying silently with
      // no onError handler in place to catch it.
      yield Left(_toFailure(exception));
    } catch (error) {
      yield Left(_toFailure(error));
    }
  }
}
