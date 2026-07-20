import 'package:freezed_annotation/freezed_annotation.dart';

part 'create_room_params.freezed.dart';

/// Value object encapsulating the input required to create a new room.
///
/// Declared `@freezed`, mirroring `RegisterParams`. Field names match
/// the backend's `CreateRoomDto` wire vocabulary exactly (`name`,
/// `description`, `isPublic`) — no aliasing applies here, unlike
/// `UserEntity.displayName`.
///
/// Unlike the backend's `CreateRoomParams` (which also carries
/// `ownerId`), this frontend value object has no such field: the owner
/// is always derived server-side from the authenticated request's JWT,
/// never sent by the client (see backend `RoomController.create`'s own
/// documentation of that same boundary).
///
/// `isPublic` carries no default here: whether an omitted value should
/// default to `true` is a presentation-layer decision (the room
/// creation form), not baked into this value object — this
/// task defines the shape only.
///
/// @see CreateRoomUseCase
/// @see IRoomRepository.createRoom
@freezed
sealed class CreateRoomParams with _$CreateRoomParams {
  const factory CreateRoomParams({
    required String name,
    required String? description,
    required bool isPublic,
  }) = _CreateRoomParams;
}
