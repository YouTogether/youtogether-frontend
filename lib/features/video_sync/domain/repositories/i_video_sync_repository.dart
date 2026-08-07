import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../entities/video_session_entity.dart';

/// Domain port for the Video Synchronisation bounded context's
/// ephemeral (Firebase Realtime Database) storage.
///
/// Mirrors `IRoomRepository` in spirit (an abstract class implemented by
/// a data-layer class, injected via `get_it`), but every method here
/// resolves against `rooms/{room_id}/playback_state` in Firebase rather
/// than the NestJS REST API — every failure this port can produce is a
/// [FirebaseFailure], not a [ServerFailure]/[NetworkFailure].
///
/// [subscribeToPlaybackState] returns a bare `Stream`, not
/// `Either<Failure, Stream<...>>`: there is nothing to fail
/// synchronously when merely opening a subscription (mirroring how
/// opening a `StreamController` cannot itself throw); failures surface
/// per-event on the stream itself, as `Left(FirebaseFailure)` values —
/// exactly the shape `SubscribeToPlaybackStateUseCase`'s own
/// `StreamUseCase` base class expects.
///
/// @see VideoSyncRepositoryImpl — the data-layer implementation
abstract class IVideoSyncRepository {
  /// Writes a new playback state (leader-only) to
  /// `rooms/{roomId}/playback_state`.
  Future<Either<Failure, void>> updatePlaybackState({
    required String roomId,
    required bool isPlaying,
    required Duration position,
  });

  /// Returns a live stream of playback state updates for [roomId].
  Stream<Either<Failure, VideoSessionEntity>> subscribeToPlaybackState({
    required String roomId,
  });

  /// Performs a single read of the current playback state for [roomId].
  Future<Either<Failure, VideoSessionEntity>> getCurrentPlaybackState({
    required String roomId,
  });
}
