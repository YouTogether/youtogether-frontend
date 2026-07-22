import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/delete_room_usecase.dart';
import 'delete_room_state.dart';

/// Cubit orchestrating the room deletion request lifecycle.
///
/// No client-side validation here — unlike `CreateRoomCubit`/
/// `EditRoomCubit`, there is no user-editable input to validate before
/// deleting; the confirmation dialog (`RoomDetailView`) is the
/// deliberate friction point instead, per this ticket's Definition of
/// Done.
///
/// @see DeleteRoomUseCase — the delegated domain operation
class DeleteRoomCubit extends Cubit<DeleteRoomState> {
  DeleteRoomCubit(this._deleteRoomUseCase)
    : super(const DeleteRoomState.initial());

  final DeleteRoomUseCase _deleteRoomUseCase;

  /// Deletes the room identified by [roomId]. Called only after the
  /// owner confirms the `AlertDialog` in `RoomDetailView` — this cubit
  /// has no knowledge of that dialog and would delete unconditionally
  /// if called directly.
  Future<void> deleteRoom(String roomId) async {
    emit(const DeleteRoomState.loading());

    final result = await _deleteRoomUseCase(roomId);

    result.fold(
      (failure) => emit(DeleteRoomState.failure(failure)),
      (_) => emit(const DeleteRoomState.success()),
    );
  }
}
