import 'package:flutter_test/flutter_test.dart';

import 'package:youtogether/features/video_sync/data/models/presence_model.dart';
import 'package:youtogether/features/video_sync/domain/entities/presence_entity.dart';

/// Unit tests for [PresenceModel].
///
/// Mirrors `video_session_model_test.dart`: `fromSnapshot` parses a raw
/// Firebase `Map<Object?, Object?>`, `toJson` is exercised because this
/// model is written back to Firebase (unlike REST-only models), and
/// `toDomain` is a field-for-field mapping onto [PresenceEntity].
///
/// @competency Unit test harness, TDD cycle (C2.2.2).
void main() {
  const userId = '550e8400-e29b-41d4-a716-446655440000';

  Map<Object?, Object?> buildSnapshotValue() => {
    'username': 'Alice',
    'is_online': true,
    'last_seen': 1767571200000, // 2026-01-05T00:00:00.000Z
  };

  group('PresenceModel.fromSnapshot', () {
    test('should parse every field from a raw Firebase snapshot map', () {
      final model = PresenceModel.fromSnapshot(
        userId: userId,
        json: buildSnapshotValue(),
      );

      expect(model.userId, userId);
      expect(model.username, 'Alice');
      expect(model.isOnline, isTrue);
      expect(
        model.lastSeen,
        DateTime.fromMillisecondsSinceEpoch(1767571200000, isUtc: true),
      );
    });
  });

  group('PresenceModel.toJson', () {
    test('should serialise username, is_online, and last_seen', () {
      final model = PresenceModel.fromSnapshot(
        userId: userId,
        json: buildSnapshotValue(),
      );

      final json = model.toJson();

      expect(json['username'], 'Alice');
      expect(json['is_online'], true);
      expect(json['last_seen'], isA<int>());
      // userId is the node's own path segment, never a value inside the
      // node itself — see PresenceEntity's own doc comment on this same
      // point.
      expect(json.containsKey('userId'), isFalse);
      expect(json.containsKey('user_id'), isFalse);
    });
  });

  group('PresenceModel.toDomain', () {
    test('should map every field onto a PresenceEntity unchanged', () {
      final model = PresenceModel.fromSnapshot(
        userId: userId,
        json: buildSnapshotValue(),
      );

      final entity = model.toDomain();

      expect(entity, isA<PresenceEntity>());
      expect(entity.userId, model.userId);
      expect(entity.username, model.username);
      expect(entity.isOnline, model.isOnline);
      expect(entity.lastSeen, model.lastSeen);
    });
  });
}
