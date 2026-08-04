import 'package:flutter_test/flutter_test.dart';
import 'package:youtogether/features/video_sync/domain/entities/video_session_entity.dart';

/// Unit tests for the domain [VideoSessionEntity].
///
/// Mirrors `room_entity_test.dart`: construction, `copyWith`, and value
/// equality, since this entity is declared `@freezed` exactly like
/// `RoomEntity`.
///
/// @competency Unit test harness, TDD cycle.
void main() {
  group('VideoSessionEntity', () {
    final updatedAt = DateTime.utc(2026, 1, 5);

    VideoSessionEntity buildSession() => VideoSessionEntity(
      roomId: '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f',
      youtubeVideoId: 'dQw4w9WgXcQ',
      isPlaying: false,
      currentPosition: const Duration(seconds: 30),
      leaderId: '550e8400-e29b-41d4-a716-446655440000',
      updatedAt: updatedAt,
    );

    test('should construct with all required fields', () {
      final session = buildSession();

      expect(session.roomId, '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f');
      expect(session.youtubeVideoId, 'dQw4w9WgXcQ');
      expect(session.isPlaying, false);
      expect(session.currentPosition, const Duration(seconds: 30));
      expect(session.leaderId, '550e8400-e29b-41d4-a716-446655440000');
      expect(session.updatedAt, updatedAt);
    });

    test('should support value equality (freezed)', () {
      final a = buildSession();
      final b = buildSession();

      expect(a, b);
    });

    test('copyWith should not mutate the original instance', () {
      final original = buildSession();
      final playing = original.copyWith(isPlaying: true);

      expect(original.isPlaying, false);
      expect(playing.isPlaying, true);
    });

    test('copyWith should update currentPosition independently', () {
      final original = buildSession();
      final seeked = original.copyWith(
        currentPosition: const Duration(seconds: 90),
      );

      expect(original.currentPosition, const Duration(seconds: 30));
      expect(seeked.currentPosition, const Duration(seconds: 90));
    });
  });
}
