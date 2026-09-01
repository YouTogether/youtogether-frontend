import '../models/video_session_metadata_model.dart';

/// Contract for the Video Synchronisation bounded context's REST
/// (HTTP) data source — the metadata side, backed by `B-V02`.
///
/// Mirrors `IRoomRemoteDataSource`.
///
/// @see VideoSessionRemoteDataSourceImpl — the Dio-based implementation
abstract class IVideoSessionRemoteDataSource {
  /// Fetches a room's video session metadata via
  /// `GET /rooms/:id/video-session`.
  ///
  /// Throws [ServerException] with `statusCode: 404` for a non-existent
  /// room, or a room that exists but has no video session yet — the
  /// backend's `VideoSessionExceptionFilter` maps both cases to the
  /// same HTTP status, so this data source (like
  /// `RoomRemoteDataSourceImpl.getRoomById`) does not attempt to
  /// distinguish them either.
  Future<VideoSessionMetadataModel> getByRoomId({required String roomId});

  /// Creates a room's video session via
  /// `POST /rooms/:id/video-session`, returning the metadata the
  /// backend resolved from the YouTube Data API and cached.
  ///
  /// The request body carries `youtubeVideoId` and nothing else. The
  /// creator is resolved server-side from the bearer token, and the
  /// room's leader from its persisted `ownerId` — sending either from
  /// the client would be the access-control mistake
  /// `RoomController.create` documents avoiding, and the backend's
  /// `ValidationPipe` would strip the extra field anyway.
  ///
  /// Status codes the backend can return, each surfacing here as a
  /// [ServerException] carrying that code:
  /// - `400` — the id is malformed, or YouTube reports no such video.
  /// - `403` — the authenticated user is not the room's owner.
  /// - `404` — the room does not exist or was deleted.
  /// - `502` — the YouTube Data API could not be reached, or the
  ///   Realtime Database write failed. The session row exists
  ///   in that second case; retrying the same call converges rather
  ///   than duplicating anything meaningful.
  ///
  /// Throws [NetworkException] if the request never reached the
  /// backend.
  Future<VideoSessionMetadataModel> create({
    required String roomId,
    required String youtubeVideoId,
  });
}
