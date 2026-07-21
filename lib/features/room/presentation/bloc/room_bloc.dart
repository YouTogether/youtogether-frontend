import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/get_public_rooms_usecase.dart';
import 'room_event.dart';
import 'room_state.dart';

/// Bloc managing the public room listing shown on `HomePage`.
///
/// Mirrors `AuthBloc` structurally (a `Bloc<Event, State>` wrapping a
/// single use case per handled event), but is deliberately **not**
/// registered as an application-wide singleton in `injection_container.dart`
/// the way `AuthBloc` is: `AuthBloc` holds global session truth consumed
/// from many places (the router's redirect, the interceptor, any
/// profile menu), whereas this bloc's state is relevant to exactly one
/// screen. It is constructed fresh, scoped to the `/` route, in
/// `AppRouter`'s `GoRoute` builder.
///
/// ## Why `refreshRooms` does not emit `RoomState.loading`
/// `fetchPublicRooms` (the initial load) emits [RoomState.loading]
/// first because there is nothing to show yet. `refreshRooms`
/// (pull-to-refresh) deliberately skips that emission: `RefreshIndicator`
/// already renders its own spinner overlay while its `onRefresh` future
/// is pending, and re-emitting [RoomState.loading] here would replace
/// the entire list with a bare progress indicator for the whole
/// duration of the refresh — hiding content the user can already see,
/// for no benefit.
class RoomBloc extends Bloc<RoomEvent, RoomState> {
  RoomBloc({required GetPublicRoomsUseCase getPublicRoomsUseCase})
    : _getPublicRoomsUseCase = getPublicRoomsUseCase,
      super(const RoomState.initial()) {
    on<RoomFetchPublicRoomsRequested>(_onFetchPublicRoomsRequested);
    on<RoomRefreshRoomsRequested>(_onRefreshRoomsRequested);
  }

  final GetPublicRoomsUseCase _getPublicRoomsUseCase;

  Future<void> _onFetchPublicRoomsRequested(
    RoomFetchPublicRoomsRequested event,
    Emitter<RoomState> emit,
  ) async {
    emit(const RoomState.loading());
    await _fetchAndEmit(emit);
  }

  Future<void> _onRefreshRoomsRequested(
    RoomRefreshRoomsRequested event,
    Emitter<RoomState> emit,
  ) async {
    await _fetchAndEmit(emit);
  }

  Future<void> _fetchAndEmit(Emitter<RoomState> emit) async {
    final result = await _getPublicRoomsUseCase(const NoParams());

    result.fold(
      (failure) => emit(RoomState.failure(failure)),
      (rooms) => emit(RoomState.loaded(rooms)),
    );
  }
}
