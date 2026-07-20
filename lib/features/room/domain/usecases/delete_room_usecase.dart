import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/i_room_repository.dart';

/// Use case for deleting (soft-deleting) a room.
///
/// Extends `UseCase<void, String>`: the input is simply the room's id,
/// with no dedicated Params wrapper class — this task's Definition of
/// Done describes the use case as taking a room ID directly, and a
/// single-field wrapper would add no value over the `String` itself
/// (contrast `UpdateRoomParams`, which genuinely groups three fields).
///
/// Contains no business logic beyond delegating to
/// `IRoomRepository.deleteRoom()` and returning its result unchanged —
/// mirroring `UpdateRoomUseCase` and the backend's own
/// `DeleteRoomUseCase`.
///
/// Ownership authorization is deliberately **not** this use case's
/// concern: enforcement is server-side, and the client additionally
/// hides the delete action from non-owners as defence in
/// depth, not as the source of truth. A confirmation dialog is a
/// presentation-layer concern shown *before* this use case
/// is ever invoked, not something this layer models.
///
/// @see IRoomRepository.deleteRoom — the delegated port method
class DeleteRoomUseCase extends UseCase<void, String> {
  DeleteRoomUseCase(this._roomRepository);

  final IRoomRepository _roomRepository;

  @override
  Future<Either<Failure, void>> call(String roomId) {
    return _roomRepository.deleteRoom(roomId: roomId);
  }
}
