import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/room_entity.dart';

part 'room_detail_state.freezed.dart';

/// State hierarchy for [RoomDetailCubit].
///
/// Declared `@freezed` as a sealed union, mirroring `RoomState`.
@freezed
sealed class RoomDetailState with _$RoomDetailState {
  const factory RoomDetailState.initial() = RoomDetailInitial;
  const factory RoomDetailState.loading() = RoomDetailLoading;
  const factory RoomDetailState.loaded(RoomEntity room) = RoomDetailLoaded;
  const factory RoomDetailState.failure(Failure failure) = RoomDetailFailure;
}
