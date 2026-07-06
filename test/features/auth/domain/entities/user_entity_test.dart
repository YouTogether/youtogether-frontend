import 'package:flutter_test/flutter_test.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';

void main() {
  group('UserEntity', () {
    final createdAt = DateTime.utc(2025, 1, 1);

    UserEntity buildUser() => UserEntity(
      id: '550e8400-e29b-41d4-a716-446655440000',
      email: 'test@example.com',
      displayName: 'testuser',
      role: UserRole.registered,
      createdAt: createdAt,
    );

    test('should construct with all required fields', () {
      final user = buildUser();

      expect(user.id, '550e8400-e29b-41d4-a716-446655440000');
      expect(user.email, 'test@example.com');
      expect(user.displayName, 'testuser');
      expect(user.role, UserRole.registered);
      expect(user.createdAt, createdAt);
    });

    test('should accept the guest role', () {
      final user = buildUser().copyWith(role: UserRole.guest);

      expect(user.role, UserRole.guest);
    });

    test('should support value equality (freezed)', () {
      final a = buildUser();
      final b = buildUser();

      expect(a, b);
    });

    test('copyWith should not mutate the original instance', () {
      final original = buildUser();
      final renamed = original.copyWith(displayName: 'renamed');

      expect(original.displayName, 'testuser');
      expect(renamed.displayName, 'renamed');
    });
  });

  group('UserRole', () {
    test('should contain exactly two values: registered and guest', () {
      expect(UserRole.values, hasLength(2));
      expect(UserRole.values, contains(UserRole.registered));
      expect(UserRole.values, contains(UserRole.guest));
    });
  });
}
