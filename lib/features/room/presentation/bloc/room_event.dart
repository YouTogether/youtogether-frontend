import 'package:freezed_annotation/freezed_annotation.dart';

part 'room_event.freezed.dart';

/// Event hierarchy for [RoomBloc].
///
/// Declared `@freezed` as a sealed union, mirroring `AuthEvent`.
@freezed
sealed class RoomEvent with _$RoomEvent {
  /// Fetches the public room listing from scratch. Dispatched once when
  /// `HomePage` first mounts (see the `/` `GoRoute` builder in
  /// `AppRouter`). Triggers a [RoomState.loading] emission first — see
  /// `RoomBloc`'s own doc for why this differs from [refreshRooms].
  const factory RoomEvent.fetchPublicRooms() = RoomFetchPublicRoomsRequested;

  /// Re-fetches the public room listing without emitting
  /// [RoomState.loading] first, so the existing list stays visible while
  /// `RefreshIndicator` shows its own spinner. Dispatched by
  /// `HomePage`'s pull-to-refresh gesture.
  const factory RoomEvent.refreshRooms() = RoomRefreshRoomsRequested;
}
