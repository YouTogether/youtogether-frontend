import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/video_session_entity.dart';

part 'video_session_model.freezed.dart';

/// Data layer model for the Firebase `rooms/{room_id}/playback_state`
/// node.
///
/// Mirrors `RoomModel` in spirit (`@freezed` with a private constructor
/// enabling extra methods, hand-written parsing rather than
/// `json_serializable` codegen), but with two differences forced by the
/// Firebase Realtime Database SDK rather than a REST/Dio response body:
///
/// - [fromSnapshot] takes a raw `Map<Object?, Object?>` — what
///   `DataSnapshot.value` actually returns — not the `Map<String,
///   dynamic>` a decoded JSON HTTP body would give. Firebase's SDK does
///   not guarantee `String` keys at the type level, even though every
///   key written by this application is in practice always a string.
/// - Unlike every REST-backed model so far (`RoomModel`, `UserModel`),
///   this model has a real [toJson]: `VideoSyncRemoteDataSourceImpl`
///   writes it back out to Firebase, whereas REST models are only ever
///   parsed from server responses. Only the fields playback controls
///   ever change are included, deliberately excluding
///   `youtube_video_id` and `leader_id` — see [toJson]'s own comment.
///
/// Field names mirror the Firebase schema exactly: `youtube_video_id`,
/// `is_playing`, `timestamp_seconds`, `leader_id`, `last_updated_at`.
///
/// [currentPositionSeconds] is kept as a `double` (Firebase's native
/// numeric wire type) at the model layer rather than a `Duration`; the
/// domain entity is where the conversion to `Duration` happens
/// (see [toDomain]), matching how `RoomModel` also keeps its own wire
/// types (`String` timestamps) and only converts to richer domain types
/// (`DateTime`) at the `toDomain()` boundary.
@freezed
sealed class VideoSessionModel with _$VideoSessionModel {
  const VideoSessionModel._();

  const factory VideoSessionModel({
    required String roomId,
    required String youtubeVideoId,
    required bool isPlaying,
    required double currentPositionSeconds,
    required String leaderId,
    required DateTime updatedAt,
  }) = _VideoSessionModel;

  /// Parses a `rooms/{roomId}/playback_state` node value, as returned by
  /// `DataSnapshot.value`.
  ///
  /// [roomId] is passed in explicitly rather than read from [json]: the
  /// Firebase node itself carries no `room_id` field (it is implicit in
  /// the node's own path), mirroring how [VideoSessionEntity.roomId] is
  /// likewise not part of the Firebase wire shape.
  factory VideoSessionModel.fromSnapshot({
    required String roomId,
    required Map<Object?, Object?> json,
  }) {
    return VideoSessionModel(
      roomId: roomId,
      youtubeVideoId: json['youtube_video_id'] as String,
      isPlaying: json['is_playing'] as bool,
      currentPositionSeconds: (json['timestamp_seconds'] as num).toDouble(),
      leaderId: json['leader_id'] as String,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        json['last_updated_at'] as int,
        isUtc: true,
      ),
    );
  }

  /// Serialises this model for a **partial** Firebase update
  /// (`DatabaseReference.update`, not `.set`) covering only the fields a
  /// play/pause/seek action ever changes.
  ///
  /// `youtube_video_id` and `leader_id` are deliberately excluded: they
  /// are written once, elsewhere (session creation / a future
  /// `SetVideoIdUseCase`), and a play/pause/seek write must never
  /// clobber them — using `.update()` with this narrower payload rather
  /// than `.set()` with the full model is what makes that guarantee
  /// hold at the data-source level rather than relying on every caller
  /// remembering to pass the unchanged values back in.
  Map<String, Object?> toJson() {
    return {
      'is_playing': isPlaying,
      'timestamp_seconds': currentPositionSeconds,
      'last_updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Converts this data-layer model to the domain's
  /// [VideoSessionEntity], converting the wire's `double` seconds into a
  /// [Duration].
  VideoSessionEntity toDomain() {
    return VideoSessionEntity(
      roomId: roomId,
      youtubeVideoId: youtubeVideoId,
      isPlaying: isPlaying,
      currentPosition: Duration(
        milliseconds: (currentPositionSeconds * 1000).round(),
      ),
      leaderId: leaderId,
      updatedAt: updatedAt,
    );
  }
}
