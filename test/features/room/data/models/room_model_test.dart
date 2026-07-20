import 'package:flutter_test/flutter_test.dart';
import 'package:youtogether/features/room/data/models/room_model.dart';
import 'package:youtogether/features/room/domain/entities/room_entity.dart';

/// Unit tests for [RoomModel].
///
/// Mirrors `user_model_test.dart`/`user_profile_model_test.dart`:
/// hand-written `fromJson` parsing and the `toDomain()` mapper.
///
/// @competency Unit test harness, TDD cycle.
void main() {
  Map<String, dynamic> buildJson({String? description}) => {
    'id': '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f',
    'name': 'Friday Movie Night',
    'description': description,
    'ownerId': '550e8400-e29b-41d4-a716-446655440000',
    'isPublic': true,
    'memberCount': 3,
    'createdAt': '2026-01-01T00:00:00.000Z',
    'updatedAt': '2026-01-02T00:00:00.000Z',
  };

  group('RoomModel.fromJson', () {
    test('should parse a complete JSON response body', () {
      final model = RoomModel.fromJson(
        buildJson(description: 'Weekly watch party'),
      );

      expect(model.id, '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f');
      expect(model.name, 'Friday Movie Night');
      expect(model.description, 'Weekly watch party');
      expect(model.ownerId, '550e8400-e29b-41d4-a716-446655440000');
      expect(model.isPublic, true);
      expect(model.memberCount, 3);
      expect(model.createdAt, DateTime.parse('2026-01-01T00:00:00.000Z'));
      expect(model.updatedAt, DateTime.parse('2026-01-02T00:00:00.000Z'));
    });

    test('should parse a null description', () {
      final model = RoomModel.fromJson(buildJson());

      expect(model.description, isNull);
    });
  });

  group('RoomModel.toDomain', () {
    test('should map every field onto a RoomEntity unchanged', () {
      final model = RoomModel.fromJson(
        buildJson(description: 'Weekly watch party'),
      );

      final entity = model.toDomain();

      expect(entity, isA<RoomEntity>());
      expect(entity.id, model.id);
      expect(entity.name, model.name);
      expect(entity.description, model.description);
      expect(entity.ownerId, model.ownerId);
      expect(entity.isPublic, model.isPublic);
      expect(entity.memberCount, model.memberCount);
      expect(entity.createdAt, model.createdAt);
      expect(entity.updatedAt, model.updatedAt);
    });
  });
}
