import 'package:flutter_test/flutter_test.dart';
import 'package:youtogether/features/video_sync/domain/entities/presence_entity.dart';

/// Unit tests for the domain [PresenceEntity].
///
/// Mirrors `video_session_entity_test.dart`: construction and value
/// equality, since this entity is declared `@freezed` exactly like
/// `VideoSessionEntity`.
///
/// @competency Unit test harness, TDD cycle.
void main() {
  group('PresenceEntity', () {
    final lastSeen = DateTime.utc(2026, 1, 5, 12, 30);

    PresenceEntity buildPresence() => PresenceEntity(
      userId: '550e8400-e29b-41d4-a716-446655440000',
      username: 'Alice',
      isOnline: true,
      lastSeen: lastSeen,
      isAnonymous: false,
    );

    test('should construct with all required fields', () {
      final presence = buildPresence();

      expect(presence.userId, '550e8400-e29b-41d4-a716-446655440000');
      expect(presence.username, 'Alice');
      expect(presence.isOnline, true);
      expect(presence.lastSeen, lastSeen);
      expect(presence.isAnonymous, false);
    });

    test('should support value equality (freezed)', () {
      final a = buildPresence();
      final b = buildPresence();

      expect(a, b);
    });

    test('copyWith should not mutate the original instance', () {
      final original = buildPresence();
      final offline = original.copyWith(isOnline: false, isAnonymous: true);

      expect(original.isOnline, true);
      expect(original.isAnonymous, false);
      expect(offline.isOnline, false);
      expect(offline.isAnonymous, true);
    });
  });
}
