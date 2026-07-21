import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/room_entity.dart';

part 'room_state.freezed.dart';

/// State hierarchy for [RoomBloc].
///
/// Declared `@freezed` as a sealed union, mirroring `AuthState`.
@freezed
sealed class RoomState with _$RoomState {
  /// No fetch has been attempted yet. Initial state of the bloc.
  const factory RoomState.initial() = RoomInitial;

  /// The initial fetch (`RoomEvent.fetchPublicRooms`) is in progress.
  /// The UI must show a loading indicator, since there is no previous
  /// list to keep displaying at this point.
  const factory RoomState.loading() = RoomLoading;

  /// Rooms were fetched successfully. `rooms` may be empty — the UI
  /// distinguishes that case (empty state) from this state's absence.
  const factory RoomState.loaded(List<RoomEntity> rooms) = RoomLoaded;

  /// The fetch or refresh failed. The UI shows an error message with a
  /// retry action.
  const factory RoomState.failure(Failure failure) = RoomFailure;
}
