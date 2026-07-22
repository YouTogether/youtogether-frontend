import '../models/room_model.dart';

/// Contract for the Room bounded context's remote (HTTP) data source.
///
/// Mirrors `IAuthRemoteDataSource`: grows one method per task,
/// implemented by `RoomRemoteDataSourceImpl`. `getPublicRooms()`,
/// `createRoom()`, and `updateRoom()`
/// are defined so far; subsequent tasks
/// will add `deleteRoom()`, `joinRoom()`,
/// and `leaveRoom()`.
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

  /// Updates a room's name and/or description via `PATCH /rooms/:id`.
  ///
  /// Unlike [createRoom], a `null` field here must be **omitted from
  /// the request body entirely**, not sent as JSON `null`: the backend's
  /// `UpdateRoomParams` distinguishes an omitted (`undefined`) field
  /// ("leave unchanged") from an explicit `null` — which the
  /// implementation would apply as an actual write, and `rooms.name` is
  /// a non-nullable column. See `RoomRemoteDataSourceImpl.updateRoom`'s
  /// own doc for how this is enforced.
  Future<RoomModel> updateRoom({
    required String roomId,
    String? name,
    String? description,
  });

  /// Fetches a single room's details via `GET /rooms/:id`.
  ///
  /// No authentication required — mirrors the backend controller's own
  /// documentation of that route. Throws [ServerException] with
  /// `statusCode: 404` for a non-existent or soft-deleted room.
  Future<RoomModel> getRoomById({required String roomId});

  /// Soft-deletes a room via `DELETE /rooms/:id`. No request body.
  ///
  /// Throws [ServerException] with `statusCode: 403` for a non-owner
  /// request, or `statusCode: 404` for a non-existent or
  /// already-deleted room.
  Future<void> deleteRoom({required String roomId});

  /// Joins a room via `POST /rooms/:id/join`. No request body — the
  /// joining user is derived server-side from the authenticated
  /// request.
  ///
  /// Throws [ServerException] with `statusCode: 409` for a duplicate
  /// active membership, or `statusCode: 404` for a non-existent or
  /// soft-deleted room.
  Future<RoomModel> joinRoom({required String roomId});

  /// Ends the caller's active membership in a room via
  /// `POST /rooms/:id/leave`. No request body.
  ///
  /// Throws [ServerException] with `statusCode: 403` if the caller is
  /// the room's owner (an owner must delete the room instead), or
  /// `statusCode: 404` if the caller holds no active membership in
  /// this room.
  Future<void> leaveRoom({required String roomId});
}
