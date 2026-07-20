import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/i_room_repository.dart';

/// Use case for leaving a room.
///
/// Extends `UseCase<void, String>`: the input is simply the room's id,
/// mirroring `DeleteRoomUseCase` and `JoinRoomUseCase` — no dedicated
/// Params wrapper, since the leaving user's identity is derived
/// server-side from the authenticated request.
///
/// Contains no business logic beyond delegating to
/// `IRoomRepository.leaveRoom()` and returning its result unchanged.
/// The owner-cannot-leave invariant is enforced server-side and
/// resolves to `Left(AuthFailure)`; the client additionally hides the
/// leave action for the owner as defence in depth, not as
/// the source of truth — the same pattern already established for
/// `UpdateRoomUseCase` and `DeleteRoomUseCase`'s ownership checks.).
///
/// @see IRoomRepository.leaveRoom — the delegated port method
class LeaveRoomUseCase extends UseCase<void, String> {
  LeaveRoomUseCase(this._roomRepository);

  final IRoomRepository _roomRepository;

  @override
  Future<Either<Failure, void>> call(String roomId) {
    return _roomRepository.leaveRoom(roomId: roomId);
  }
}
