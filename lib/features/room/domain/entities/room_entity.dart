import 'package:freezed_annotation/freezed_annotation.dart';

part 'room_entity.freezed.dart';

/// Domain entity representing a Room in the Room bounded context.
///
/// Declared `@freezed`, exactly like `UserEntity`: immutable, no
/// `fromJson`/`toJson` (that belongs to `RoomModel` in the data layer).
///
/// Field mapping mirrors the backend's `RoomResponseDto` exactly — no
/// renaming applies here (unlike `UserEntity.displayName`, which
/// diverges from the backend's `username` wire term), since every field
/// name below already reads naturally on the frontend as-is.
///
/// [description] is nullable: the backend's `rooms.description` column
/// is `TEXT DEFAULT NULL`, and
/// `RoomResponseDto.description` is typed `string | null` — this entity
/// mirrors that exactly rather than coercing a missing description to
/// an empty string.
///
/// [memberCount] is a computed, read-only projection (the count of
/// currently active `room_memberships` rows for this room), not a
/// column the frontend ever sends back — it is only ever populated from
/// a server response, never constructed by the frontend itself for an
/// outbound request (see `CreateRoomParams`/`UpdateRoomParams`, which
/// carry no such field).
///
/// @see Room Aggregate
/// @see RoomEntity
@freezed
sealed class RoomEntity with _$RoomEntity {
  const factory RoomEntity({
    /// Unique room identifier (UUID v4).
    required String id,

    /// Room display name (max 100 characters).
    required String name,

    /// Room description, or `null` if none was provided.
    required String? description,

    /// User ID of the room's creator and owner.
    required String ownerId,

    /// Whether the room appears in the public listing.
    required bool isPublic,

    /// Number of currently active members (computed by the backend).
    required int memberCount,

    /// Room creation timestamp (UTC).
    required DateTime createdAt,

    /// Last modification timestamp (UTC).
    required DateTime updatedAt,
  }) = _RoomEntity;
}
