import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failures.dart';

part 'leave_room_state.freezed.dart';

/// State hierarchy for [LeaveRoomCubit].
///
/// Declared `@freezed` as a sealed union, mirroring `DeleteRoomState`.
/// [success] carries no payload, for the same reason as
/// `DeleteRoomState.success` — the caller is no longer a member, there
/// is nothing to hand back.
@freezed
sealed class LeaveRoomState with _$LeaveRoomState {
  const factory LeaveRoomState.initial() = LeaveRoomInitial;
  const factory LeaveRoomState.loading() = LeaveRoomLoading;
  const factory LeaveRoomState.success() = LeaveRoomSuccess;
  const factory LeaveRoomState.failure(Failure failure) = LeaveRoomFailure;
}
