import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/video_session_metadata_entity.dart';

part 'video_session_metadata_model.freezed.dart';

/// Data layer model for the `GET /rooms/:id/video-session`
/// response body — mirrors `VideoSessionResponseDto` on the backend
/// field-for-field.
///
/// Hand-written `fromJson`/`toDomain`, no `toJson()` — see this class's
/// own test file for why a write-back path is not needed here.
@freezed
sealed class VideoSessionMetadataModel with _$VideoSessionMetadataModel {
  const VideoSessionMetadataModel._();

  const factory VideoSessionMetadataModel({
    required String id,
    required String roomId,
    required String youtubeVideoId,
    required String title,
    required String? thumbnailUrl,
    required int durationSeconds,
    required String addedBy,
    required DateTime createdAt,
  }) = _VideoSessionMetadataModel;

  factory VideoSessionMetadataModel.fromJson(Map<String, dynamic> json) {
    return VideoSessionMetadataModel(
      id: json['id'] as String,
      roomId: json['roomId'] as String,
      youtubeVideoId: json['youtubeVideoId'] as String,
      title: json['title'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      durationSeconds: json['durationSeconds'] as int,
      addedBy: json['addedBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  VideoSessionMetadataEntity toDomain() {
    return VideoSessionMetadataEntity(
      id: id,
      roomId: roomId,
      youtubeVideoId: youtubeVideoId,
      title: title,
      thumbnailUrl: thumbnailUrl,
      durationSeconds: durationSeconds,
      addedBy: addedBy,
      createdAt: createdAt,
    );
  }
}
