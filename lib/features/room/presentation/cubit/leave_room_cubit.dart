import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/leave_room_usecase.dart';
import 'leave_room_state.dart';

/// Cubit orchestrating the room departure request lifecycle.
///
/// Mirrors `DeleteRoomCubit` in structure. No confirmation dialog is
/// involved on the presentation side (unlike `DeleteRoomCubit`'s
/// pairing with `RoomDetailView`'s `AlertDialog`) — this ticket's
/// Definition of Done describes a direct action; leaving is reversible
/// (the user can simply rejoin), unlike deleting a room.
///
/// The owner-cannot-leave invariant is enforced server-side
/// (`Left(AuthFailure)`); the client additionally hides this action for
/// the owner (`RoomDetailView`) as defence in depth, not as the source
/// of truth — the same pattern already established for
/// `UpdateRoomUseCase`/`DeleteRoomUseCase`'s ownership checks.
///
/// @see LeaveRoomUseCase — the delegated domain operation
class LeaveRoomCubit extends Cubit<LeaveRoomState> {
  LeaveRoomCubit(this._leaveRoomUseCase)
    : super(const LeaveRoomState.initial());

  final LeaveRoomUseCase _leaveRoomUseCase;

  /// Ends the caller's membership in the room identified by [roomId].
  Future<void> leaveRoom(String roomId) async {
    emit(const LeaveRoomState.loading());

    final result = await _leaveRoomUseCase(roomId);

    result.fold(
      (failure) => emit(LeaveRoomState.failure(failure)),
      (_) => emit(const LeaveRoomState.success()),
    );
  }
}
