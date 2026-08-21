import 'package:flutter_test/flutter_test.dart';

import 'package:youtogether/features/video_sync/data/models/video_session_metadata_model.dart';
import 'package:youtogether/features/video_sync/domain/entities/video_session_metadata_entity.dart';

/// Unit tests for [VideoSessionMetadataModel].
///
/// Mirrors `room_model_test.dart`'s `fromJson`/`toDomain` convention —
/// this REST model, unlike the Firebase-sourced `VideoSessionModel`,
/// has no `toJson()`: nothing in this bounded context ever writes this
/// metadata back to the backend from the frontend (creation is
/// owner-only, via a dedicated `CreateVideoSessionDto`-shaped call not
/// yet implemented on the frontend).
///
/// @competency Unit test harness.
void main() {
  Map<String, dynamic> buildJson() => {
    'id': 'session-uuid',
    'roomId': '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f',
    'youtubeVideoId': 'dQw4w9WgXcQ',
    'title': 'Never Gonna Give You Up',
    'thumbnailUrl': 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
    'durationSeconds': 213,
    'addedBy': '550e8400-e29b-41d4-a716-446655440000',
    'createdAt': '2026-01-05T00:00:00.000Z',
  };

  group('VideoSessionMetadataModel.fromJson', () {
    test('should parse every field from the backend response body', () {
      final model = VideoSessionMetadataModel.fromJson(buildJson());

      expect(model.id, 'session-uuid');
      expect(model.youtubeVideoId, 'dQw4w9WgXcQ');
      expect(model.title, 'Never Gonna Give You Up');
      expect(model.durationSeconds, 213);
      expect(model.createdAt, DateTime.parse('2026-01-05T00:00:00.000Z'));
    });

    test('should accept a null thumbnailUrl', () {
      final json = buildJson()..['thumbnailUrl'] = null;

      final model = VideoSessionMetadataModel.fromJson(json);

      expect(model.thumbnailUrl, isNull);
    });
  });

  group('VideoSessionMetadataModel.toDomain', () {
    test(
      'should map every field onto a VideoSessionMetadataEntity unchanged',
      () {
        final model = VideoSessionMetadataModel.fromJson(buildJson());

        final entity = model.toDomain();

        expect(entity, isA<VideoSessionMetadataEntity>());
        expect(entity.id, model.id);
        expect(entity.durationSeconds, model.durationSeconds);
        expect(entity.youtubeVideoId, model.youtubeVideoId);
      },
    );
  });
}
