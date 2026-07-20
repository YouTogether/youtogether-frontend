import '../models/room_model.dart';

/// Contract for the Room bounded context's remote (HTTP) data source.
///
/// Mirrors `IAuthRemoteDataSource`: grows one method per task,
/// implemented by `RoomRemoteDataSourceImpl`. `getPublicRooms()`
/// is the only method defined so far; Further
/// tasks will add `createRoom()`,
/// `updateRoom()`, `deleteRoom()`, `joinRoom()`, and `leaveRoom()`.
///
/// @see RoomRemoteDataSourceImpl — the Dio-based implementation
abstract class IRoomRemoteDataSource {
  /// Fetches every active, public room via `GET /rooms`.
  ///
  /// The backend's `GET /rooms` accepts no query parameter and always
  /// returns only public, non-deleted rooms — filtering happens
  /// unconditionally server-side (`RoomRepositoryImpl.getPublicRooms`,
  /// backend), not via a client-supplied flag. No request body or
  /// parameter is needed here.
  Future<List<RoomModel>> getPublicRooms();

  /// Creates a new room via `POST /rooms`.
  ///
  /// `description` is sent as-is, including `null` — the backend's
  /// `CreateRoomDto.description` is `@IsOptional()`, so a `null` JSON
  /// value is accepted identically to an omitted field.
  Future<RoomModel> createRoom({
    required String name,
    required String? description,
    required bool isPublic,
  });
}
