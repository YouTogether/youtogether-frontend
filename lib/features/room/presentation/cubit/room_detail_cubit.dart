import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_room_by_id_usecase.dart';
import 'room_detail_state.dart';

/// Cubit orchestrating `RoomDetailPage`'s fetch lifecycle.
///
/// Mirrors `RoomBloc`'s `fetchPublicRooms` handler in structure, adapted
/// to a `Cubit` (a single caller-driven method, not a Bloc event) since
/// there is only one meaningful trigger here — no separate
/// "refresh without a loading flash" variant is needed, unlike
/// `RoomBloc.refreshRooms()`, because this page has no pull-to-refresh
/// requirement in its Definition of Done.
///
/// @see GetRoomByIdUseCase — the delegated domain operation
class RoomDetailCubit extends Cubit<RoomDetailState> {
  RoomDetailCubit(this._getRoomByIdUseCase)
    : super(const RoomDetailState.initial());

  final GetRoomByIdUseCase _getRoomByIdUseCase;

  /// Fetches the room identified by [roomId] and emits the resulting
  /// state. Called once from `RoomDetailPage`'s `BlocProvider.create`,
  /// mirroring how `AppRouter`'s `/` route dispatches
  /// `RoomEvent.fetchPublicRooms()` on `RoomBloc` construction.
  Future<void> fetchRoom(String roomId) async {
    emit(const RoomDetailState.loading());

    final result = await _getRoomByIdUseCase(roomId);

    result.fold(
      (failure) => emit(RoomDetailState.failure(failure)),
      (room) => emit(RoomDetailState.loaded(room)),
    );
  }
}
