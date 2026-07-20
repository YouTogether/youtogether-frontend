import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../entities/room_entity.dart';

/// Repository port for the Room bounded context.
///
/// Mirrors `IAuthRepository`: an abstract class defining the contract
/// the domain layer depends on, implemented by `RoomRepositoryImpl` in
/// the data layer.
///
/// Grows incrementally, one method per task — `getPublicRooms()` is the
/// only method required. Further tasks will add `createRoom()`,
/// `getRoomById()`, `updateRoom()`, `deleteRoom()`, `joinRoom()`, and `leaveRoom()`,
/// mirroring the backend's `IRoomRepository`'s own incremental growth.
///
/// @see RoomRepositoryImpl — data layer implementation
/// @see GetPublicRoomsUseCase — primary consumer of getPublicRooms()
/// @see CreateRoomUseCase — primary consumer of createRoom()
/// @see UpdateRoomUseCase — primary consumer of updateRoom()
/// @see DeleteRoomUseCase — primary consumer of deleteRoom()
/// @see JoinRoomUseCase — primary consumer of joinRoom()
/// @see LeaveRoomUseCase — primary consumer of leaveRoom()
abstract class IRoomRepository {
  /// Returns every active, public room, each annotated with its current
  /// active member count.
  ///
  /// @see GetPublicRoomsUseCase
  Future<Either<Failure, List<RoomEntity>>> getPublicRooms();

  /// Creates a new room with the caller as owner, and auto-joins that
  /// owner as the first active member.
  ///
  /// `name` and `isPublic` are always required by the wire contract
  /// (`CreateRoomDto`); `description` may be `null`. The owner is never
  /// passed here — it is derived server-side from the authenticated
  /// request, exactly mirroring `CreateRoomParams`'s own documentation
  /// of that boundary.
  ///
  /// @see CreateRoomUseCase
  Future<Either<Failure, RoomEntity>> createRoom({
    required String name,
    required String? description,
    required bool isPublic,
  });

  /// Updates a room's name and/or description.
  ///
  /// `name`/`description` left `null` mean "leave unchanged" — see
  /// `UpdateRoomParams`'s own documentation of that convention.
  /// Ownership is not this method's concern: by the time it is called,
  /// the edit action was only reachable because the caller already
  /// owns the room (server-side `OwnershipGuard` is the actual
  /// enforcement; the client-side hidden edit button is defence in
  /// depth, not the source of truth).
  ///
  /// A non-owner request that somehow still reaches this method
  /// surfaces as `Left(AuthFailure)` (403), per this feature's
  /// acceptance criteria.
  ///
  /// @see UpdateRoomUseCase
  Future<Either<Failure, RoomEntity>> updateRoom({
    required String roomId,
    String? name,
    String? description,
  });

  /// Soft-deletes a room. Only the owner may succeed — a non-owner
  /// request surfaces as `Left(AuthFailure)` (403), a non-existent or
  /// already-deleted room as `Left(NotFoundFailure)` (404). Room
  /// memberships are preserved server-side for audit purposes; this
  /// method's caller has no need to know that detail.
  ///
  /// @see DeleteRoomUseCase
  Future<Either<Failure, void>> deleteRoom({required String roomId});

  /// Creates an active membership for the caller in the given room, and
  /// returns the room with its refreshed active member count.
  ///
  /// No user id parameter: the joining user is derived server-side from
  /// the authenticated request, exactly like `createRoom()`'s owner.
  ///
  /// - `Left(NotFoundFailure)` — the room does not exist or is
  ///   soft-deleted (404).
  /// - `Left(ServerFailure(statusCode: 409))` — the caller already
  ///   holds an active membership in this room.
  ///
  /// @see JoinRoomUseCase
  Future<Either<Failure, RoomEntity>> joinRoom({required String roomId});

  /// Ends the caller's active membership in the given room.
  ///
  /// No user id parameter, for the same reason as `joinRoom()`: the
  /// leaving user is derived server-side from the authenticated
  /// request.
  ///
  /// - `Left(AuthFailure)` — the caller is the room's owner; an owner
  ///   must delete the room (`deleteRoom()`) rather than leave it.
  /// - `Left(NotFoundFailure)` — the caller holds no active membership
  ///   in this room.
  ///
  /// @see LeaveRoomUseCase
  Future<Either<Failure, void>> leaveRoom({required String roomId});
}
