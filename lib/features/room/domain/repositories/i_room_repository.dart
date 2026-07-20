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
/// @see GetPublicRoomsUseCase — primary consumer of this port
abstract class IRoomRepository {
  /// Returns every active, public room, each annotated with its current
  /// active member count.
  ///
  /// @see GetPublicRoomsUseCase
  Future<Either<Failure, List<RoomEntity>>> getPublicRooms();
}
