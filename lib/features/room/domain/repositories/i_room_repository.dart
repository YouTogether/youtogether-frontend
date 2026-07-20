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
}
