import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/room_entity.dart';

part 'edit_room_state.freezed.dart';

/// State hierarchy for [EditRoomCubit].
///
/// Declared `@freezed` as a sealed union, mirroring `CreateRoomState`.
@freezed
sealed class EditRoomState with _$EditRoomState {
  const factory EditRoomState.initial() = EditRoomInitial;
  const factory EditRoomState.loading() = EditRoomLoading;
  const factory EditRoomState.success(RoomEntity room) = EditRoomSuccess;
  const factory EditRoomState.failure(Failure failure) = EditRoomFailure;
}
