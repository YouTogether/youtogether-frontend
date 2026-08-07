import '../models/video_session_model.dart';

/// Data source port for the Video Synchronisation bounded context's
/// Firebase Realtime Database access.
///
/// Mirrors `IRoomRemoteDataSource` in spirit (an abstract class
/// implemented by a single concrete class, injected via `get_it`), but
/// talks to `FirebaseDatabase` rather than `Dio`/the NestJS REST API.
///
/// Every method operates on a single room's `rooms/{roomId}/playback_state`
/// node. Methods throw on failure — `firebase_database`'s own
/// `FirebaseException` for any Firebase-side error — rather than
/// returning `Either`: that mapping to `Failure` is
/// `VideoSyncRepositoryImpl`'s responsibility, exactly mirroring how
/// `IRoomRemoteDataSource` throws `ServerException`/`NetworkException`
/// for `RoomRepositoryImpl` to map.
///
/// @see VideoSyncRemoteDataSourceImpl — the concrete implementation
/// @see VideoSyncRepositoryImpl — the repository mapping this port's
///   exceptions to [FirebaseFailure]
abstract class IVideoSyncRemoteDataSource {
  /// Writes a partial update to `rooms/{roomId}/playback_state`,
  /// covering only `is_playing`, `timestamp_seconds`, and
  /// `last_updated_at` — see [VideoSessionModel.toJson] for why
  /// `youtube_video_id`/`leader_id` are never touched by this call.
  Future<void> updatePlaybackState({
    required String roomId,
    required bool isPlaying,
    required Duration position,
  });

  /// Returns a live stream of [VideoSessionModel] updates for [roomId],
  /// backed by `DatabaseReference.onValue`.
  ///
  /// Emits nothing further once the returned `Stream` is cancelled by
  /// the caller (`VideoSyncBloc.sessionLeft` cancels its subscription) —
  /// Firebase's own listener is detached at that point, mirroring how a
  /// `StreamController` releases its resources once unsubscribed.
  Stream<VideoSessionModel> subscribeToPlaybackState({required String roomId});

  /// Performs a single read of `rooms/{roomId}/playback_state`.
  Future<VideoSessionModel> getCurrentPlaybackState({required String roomId});
}
