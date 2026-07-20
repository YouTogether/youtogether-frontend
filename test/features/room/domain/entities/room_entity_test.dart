import 'package:flutter_test/flutter_test.dart';
import 'package:youtogether/features/room/domain/entities/room_entity.dart';

/// Unit tests for the domain [RoomEntity] (F-R01-T1 — domain layer).
///
/// Mirrors `user_entity_test.dart`: construction, `copyWith`, and value
/// equality, since [RoomEntity] is declared `@freezed` exactly like
/// `UserEntity`.
///
/// @competency Unit test harness, TDD cycle.
void main() {
  group('RoomEntity', () {
    final createdAt = DateTime.utc(2026, 1, 1);
    final updatedAt = DateTime.utc(2026, 1, 2);

    RoomEntity buildRoom() => RoomEntity(
      id: '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f',
      name: 'Friday Movie Night',
      description: 'Weekly watch party',
      ownerId: '550e8400-e29b-41d4-a716-446655440000',
      isPublic: true,
      memberCount: 3,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    test('should construct with all required fields', () {
      final room = buildRoom();

      expect(room.id, '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f');
      expect(room.name, 'Friday Movie Night');
      expect(room.description, 'Weekly watch party');
      expect(room.ownerId, '550e8400-e29b-41d4-a716-446655440000');
      expect(room.isPublic, true);
      expect(room.memberCount, 3);
      expect(room.createdAt, createdAt);
      expect(room.updatedAt, updatedAt);
    });

    test('should accept a null description', () {
      final room = buildRoom().copyWith(description: null);

      expect(room.description, isNull);
    });

    test('should support value equality (freezed)', () {
      final a = buildRoom();
      final b = buildRoom();

      expect(a, b);
    });

    test('copyWith should not mutate the original instance', () {
      final original = buildRoom();
      final renamed = original.copyWith(name: 'Renamed Room');

      expect(original.name, 'Friday Movie Night');
      expect(renamed.name, 'Renamed Room');
    });
  });
}
