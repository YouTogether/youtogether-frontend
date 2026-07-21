import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/room_entity.dart';

part 'create_room_state.freezed.dart';

/// State hierarchy for [CreateRoomCubit].
///
/// Declared `@freezed` as a sealed union, mirroring `RegisterState`.
@freezed
sealed class CreateRoomState with _$CreateRoomState {
  const factory CreateRoomState.initial() = CreateRoomInitial;
  const factory CreateRoomState.loading() = CreateRoomLoading;
  const factory CreateRoomState.success(RoomEntity room) = CreateRoomSuccess;
  const factory CreateRoomState.failure(Failure failure) = CreateRoomFailure;
}
