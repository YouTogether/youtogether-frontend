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
}
