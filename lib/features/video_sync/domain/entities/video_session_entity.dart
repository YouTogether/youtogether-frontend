import 'package:freezed_annotation/freezed_annotation.dart';

part 'video_session_entity.freezed.dart';

/// Domain entity representing the ephemeral playback state of a video
/// session, in the Video Synchronisation bounded context.
///
/// Declared `@freezed`, mirroring `RoomEntity`. Unlike the backend's own
/// `VideoSessionEntity` (which models only the persistent, PostgreSQL
/// side — id, title, thumbnail, duration), this frontend entity mirrors
/// the *Firebase* `rooms/{room_id}/playback_state` node exactly: it
/// carries no cached YouTube metadata (title, thumbnail, duration) at
/// all, since that data is fetched once via the REST API at session
/// creation and never re-read from Firebase. Conflating the two would
/// blur the same persistent/ephemeral boundary the data model
/// deliberately draws (see the backend `VideoSessionEntity`'s own doc
/// comment for the mirror-image statement of this same boundary).
///
/// Field mapping mirrors the Firebase schema exactly:
/// - [isPlaying] <-> `is_playing`
/// - [currentPosition] <-> `timestamp_seconds` (represented as a [Duration]
///   rather than a raw `double` of seconds, so call sites work with the
///   same [Duration] type used throughout Flutter's own player APIs)
/// - [leaderId] <-> `leader_id`
/// - [updatedAt] <-> `last_updated_at`
@freezed
sealed class VideoSessionEntity with _$VideoSessionEntity {
  const factory VideoSessionEntity({
    /// Room this playback state belongs to.
    required String roomId,

    /// YouTube video identifier currently being diffused.
    required String youtubeVideoId,

    /// Whether the video is currently playing.
    required bool isPlaying,

    /// Current playback position.
    required Duration currentPosition,

    /// UUID of the room owner — only this user may write playback
    /// commands (enforced by Firebase security rules and a client-side
    /// guard in `VideoSyncBloc`).
    required String leaderId,

    /// Timestamp of the last state update, as reported by Firebase.
    required DateTime updatedAt,
  }) = _VideoSessionEntity;
}
