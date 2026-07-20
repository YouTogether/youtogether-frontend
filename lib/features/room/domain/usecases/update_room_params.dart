import 'package:freezed_annotation/freezed_annotation.dart';

part 'update_room_params.freezed.dart';

/// Value object encapsulating the input required to update a room's
/// name and/or description.
///
/// Declared `@freezed`, mirroring `CreateRoomParams`. `name` and
/// `description` are both optional (nullable, no `required`) to support
/// partial updates: a field left unset defaults to `null` and is
/// interpreted as "leave unchanged" — mirroring the backend's
/// `UpdateRoomParams`, where an `undefined` field carries the identical
/// meaning.
///
/// This is a plain Dart optional/nullable distinction, not a
/// three-state sentinel: there is no way to distinguish "omitted" from
/// "explicitly set to null" here. That is a deliberate simplification —
/// clearing a description to empty is expressed by passing an empty
/// string, not `null`; the data layer only includes a
/// field in the outgoing `PATCH` body when it is non-null.
///
/// `roomId` always comes from the room the user is currently viewing,
/// already gated behind the owner-only edit action.
///
/// @see UpdateRoomUseCase
/// @see IRoomRepository.updateRoom
@freezed
sealed class UpdateRoomParams with _$UpdateRoomParams {
  const factory UpdateRoomParams({
    required String roomId,
    String? name,
    String? description,
  }) = _UpdateRoomParams;
}
