import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/room_entity.dart';
import '../repositories/i_room_repository.dart';

/// Use case for joining a room.
///
/// Extends `UseCase<RoomEntity, String>`: the input is simply the room's
/// id, mirroring `DeleteRoomUseCase` — no dedicated Params wrapper. The
/// joining user's identity is derived server-side from the
/// authenticated request, so there is no second field to carry here
/// (contrast the backend's own `JoinRoomParams`, which does carry
/// `userId` because the backend has no other way to obtain it at that
/// layer).
///
/// Contains no business logic beyond delegating to
/// `IRoomRepository.joinRoom()` and returning its result unchanged —
/// mirroring `DeleteRoomUseCase` and the backend's own
/// `JoinRoomUseCase`.
///
/// The returned `RoomEntity` (with its refreshed `memberCount`) is what
/// the room listing UI (`F-R05-T3`) uses to reflect the increment
/// without a second round trip, and what the room detail view
/// navigates to on success.
///
/// @see IRoomRepository.joinRoom — the delegated port method
class JoinRoomUseCase extends UseCase<RoomEntity, String> {
  JoinRoomUseCase(this._roomRepository);

  final IRoomRepository _roomRepository;

  @override
  Future<Either<Failure, RoomEntity>> call(String roomId) {
    return _roomRepository.joinRoom(roomId: roomId);
  }
}
