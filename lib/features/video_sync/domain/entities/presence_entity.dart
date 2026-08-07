import 'package:freezed_annotation/freezed_annotation.dart';

part 'presence_entity.freezed.dart';

/// Domain entity representing a single participant's presence in a
/// room, in the Video Synchronisation bounded context.
///
/// Declared `@freezed`, mirroring `VideoSessionEntity`. Field mapping
/// mirrors the Firebase `rooms/{room_id}/presence/{user_id}`:
/// - [userId] <-> the `{user_id}` path segment itself (not a value
///   stored inside the node — carried here as a field regardless, since
///   a `List<PresenceEntity>` returned by
///   `IPresenceRepository.subscribeToPresence` would otherwise lose it)
/// - [username] <-> `username`
/// - [isOnline] <-> `is_online`
/// - [lastSeen] <-> `last_seen`
///
/// [userId] deliberately covers both registered and anonymous viewers:
/// per `decision-anonymous-room-join.md`, presence is the mechanism by
/// which an anonymous viewer is counted at all, so this field is not
/// necessarily a `users.id` foreign key — it may be a client-generated
/// identifier for a session with no backing account. Combining this
/// list with the Postgres-sourced registered member count is
/// a presentation-layer concern, not something this entity resolves.
@freezed
sealed class PresenceEntity with _$PresenceEntity {
  const factory PresenceEntity({
    /// Identifier of the participant. May be a registered user's UUID or
    /// a client-generated anonymous session identifier.
    required String userId,

    /// Cached display name, avoiding a REST lookup purely for UI
    /// rendering.
    required String username,

    /// Whether this participant is currently connected to the room.
    required bool isOnline,

    /// Timestamp of the last keep-alive signal.
    required DateTime lastSeen,
  }) = _PresenceEntity;
}
