import 'package:flutter_test/flutter_test.dart';

import 'package:youtogether/features/video_sync/data/models/video_session_model.dart';
import 'package:youtogether/features/video_sync/domain/entities/video_session_entity.dart';

/// Unit tests for [VideoSessionModel].
///
/// Mirrors `room_model_test.dart`, adapted to the Firebase Realtime
/// Database wire shape: [VideoSessionModel.fromSnapshot] parses a raw
/// `Map<Object?, Object?>` (what `DataSnapshot.value` actually returns —
/// not the `Map<String, dynamic>` a REST JSON body would give), and
/// [VideoSessionModel.toJson] is exercised here too, unlike `RoomModel`,
/// since this model *is* written back out to Firebase by
/// `VideoSyncRemoteDataSourceImpl.updatePlaybackState`.
///
/// @competency Unit test harness, TDD cycle.
void main() {
  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';

  Map<Object?, Object?> buildSnapshotValue() => {
    'youtube_video_id': 'dQw4w9WgXcQ',
    'is_playing': true,
    'timestamp_seconds': 42.5,
    'leader_id': '550e8400-e29b-41d4-a716-446655440000',
    'last_updated_at': 1767571200000, // 2026-01-05T00:00:00.000Z
  };

  group('VideoSessionModel.fromSnapshot', () {
    test('should parse every field from a raw Firebase snapshot map', () {
      final model = VideoSessionModel.fromSnapshot(
        roomId: roomId,
        json: buildSnapshotValue(),
      );

      expect(model.roomId, roomId);
      expect(model.youtubeVideoId, 'dQw4w9WgXcQ');
      expect(model.isPlaying, isTrue);
      expect(model.currentPositionSeconds, 42.5);
      expect(model.leaderId, '550e8400-e29b-41d4-a716-446655440000');
      expect(
        model.updatedAt,
        DateTime.fromMillisecondsSinceEpoch(1767571200000, isUtc: true),
      );
    });

    test(
      'should accept an integer timestamp_seconds (whole-second position)',
      () {
        final value = buildSnapshotValue();
        value['timestamp_seconds'] = 42;

        final model = VideoSessionModel.fromSnapshot(
          roomId: roomId,
          json: value,
        );

        expect(model.currentPositionSeconds, 42.0);
      },
    );
  });

  group('VideoSessionModel.toJson', () {
    test(
      'should serialise the playback-relevant fields for a partial Firebase update',
      () {
        final model = VideoSessionModel.fromSnapshot(
          roomId: roomId,
          json: buildSnapshotValue(),
        );

        final json = model.toJson();

        expect(json['is_playing'], true);
        expect(json['timestamp_seconds'], 42.5);
        // youtube_video_id and leader_id are intentionally NOT part of the
        // partial-update payload written by updatePlaybackState — see
        // VideoSyncRemoteDataSourceImpl's own doc comment on why a play/
        // pause/seek write never touches those two fields.
        expect(json.containsKey('youtube_video_id'), isFalse);
        expect(json.containsKey('leader_id'), isFalse);
        expect(json.containsKey('last_updated_at'), isTrue);
      },
    );
  });

  group('VideoSessionModel.toDomain', () {
    test(
      'should map every field onto a VideoSessionEntity, converting position to a Duration',
      () {
        final model = VideoSessionModel.fromSnapshot(
          roomId: roomId,
          json: buildSnapshotValue(),
        );

        final entity = model.toDomain();

        expect(entity, isA<VideoSessionEntity>());
        expect(entity.roomId, model.roomId);
        expect(entity.youtubeVideoId, model.youtubeVideoId);
        expect(entity.isPlaying, model.isPlaying);
        expect(entity.currentPosition, const Duration(milliseconds: 42500));
        expect(entity.leaderId, model.leaderId);
        expect(entity.updatedAt, model.updatedAt);
      },
    );
  });
}
