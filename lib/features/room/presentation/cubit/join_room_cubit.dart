import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/join_room_usecase.dart';
import 'join_room_state.dart';

/// Cubit orchestrating the room join request lifecycle.
///
/// Mirrors `LeaveRoomCubit` in structure. Shared across two contexts —
/// `HomePage` (one cubit for the whole listing, provided alongside
/// `RoomBloc`) and `RoomDetailPage` (one cubit for that single room) —
/// each wiring its own `BlocListener` for navigation/refresh on
/// success, per this ticket's requirement to support joining from both
/// screens.
///
/// @see JoinRoomUseCase — the delegated domain operation
class JoinRoomCubit extends Cubit<JoinRoomState> {
  JoinRoomCubit(this._joinRoomUseCase) : super(const JoinRoomState.initial());

  final JoinRoomUseCase _joinRoomUseCase;

  /// Joins the room identified by [roomId].
  Future<void> joinRoom(String roomId) async {
    emit(JoinRoomState.loading(roomId));

    final result = await _joinRoomUseCase(roomId);

    result.fold(
      (failure) => emit(JoinRoomState.failure(failure)),
      (room) => emit(JoinRoomState.success(room)),
    );
  }
}
