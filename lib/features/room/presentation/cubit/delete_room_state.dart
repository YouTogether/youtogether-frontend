import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failures.dart';

part 'delete_room_state.freezed.dart';

/// State hierarchy for [DeleteRoomCubit].
///
/// Declared `@freezed` as a sealed union, mirroring `EditRoomState`.
/// [success] carries no payload — unlike [EditRoomState.success], there
/// is no updated resource to hand back: the room no longer exists.
@freezed
sealed class DeleteRoomState with _$DeleteRoomState {
  const factory DeleteRoomState.initial() = DeleteRoomInitial;
  const factory DeleteRoomState.loading() = DeleteRoomLoading;
  const factory DeleteRoomState.success() = DeleteRoomSuccess;
  const factory DeleteRoomState.failure(Failure failure) = DeleteRoomFailure;
}
