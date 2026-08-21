import 'package:freezed_annotation/freezed_annotation.dart';

part 'video_session_metadata_entity.freezed.dart';

/// Domain entity for the video session metadata cached in PostgreSQL at
/// creation time and read back via `B-V02`
/// (`GET /rooms/:id/video-session`).
///
/// Deliberately kept separate from `VideoSessionEntity`
/// (`lib/features/video_sync/domain/entities/video_session_entity.dart`),
/// which models the *live* Firebase playback state: this entity is the
/// REST-sourced counterpart, carrying exactly the fields Firebase does
/// not have — most importantly `durationSeconds`, needed by
/// `PlaybackTimestamp` to bound seek targets, and cached `title`/
/// `thumbnailUrl` for display. `youtubeVideoId` appears on both
/// entities; `VideoSyncBloc.sessionJoined` treats Firebase's
/// copy as the live source of truth once the session has been fetched
/// once here, since only Firebase updates in real time.
@freezed
sealed class VideoSessionMetadataEntity with _$VideoSessionMetadataEntity {
  const factory VideoSessionMetadataEntity({
    required String id,
    required String roomId,
    required String youtubeVideoId,
    required String title,
    required String? thumbnailUrl,
    required int durationSeconds,
    required String addedBy,
    required DateTime createdAt,
  }) = _VideoSessionMetadataEntity;
}
