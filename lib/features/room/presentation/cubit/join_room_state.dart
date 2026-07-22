import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/room_entity.dart';

part 'join_room_state.freezed.dart';

/// State hierarchy for [JoinRoomCubit].
///
/// Declared `@freezed` as a sealed union, mirroring `LeaveRoomState`,
/// with one addition: [loading] carries the joining room's id.
/// `HomePage` shares a single [JoinRoomCubit] across every `RoomCard`
/// in the listing and needs to know *which* card to show a per-item
/// spinner on while a request is in flight — unlike `LeaveRoomCubit`/
/// `DeleteRoomCubit`, each scoped to a single already-known room via
/// `RoomDetailPage`.
@freezed
sealed class JoinRoomState with _$JoinRoomState {
  const factory JoinRoomState.initial() = JoinRoomInitial;
  const factory JoinRoomState.loading(String roomId) = JoinRoomLoading;
  const factory JoinRoomState.success(RoomEntity room) = JoinRoomSuccess;
  const factory JoinRoomState.failure(Failure failure) = JoinRoomFailure;
}
