import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/core/usecases/usecase.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';
import 'package:youtogether/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:youtogether/features/auth/domain/usecases/get_current_user_usecase.dart';

/// Mocktail mock for [IAuthRepository].
///
/// Declared locally, per the convention established across the auth
/// domain test suite (see `register_usecase_test.dart`,
/// `login_usecase_test.dart`).
class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late GetCurrentUserUseCase getCurrentUserUseCase;
  late MockAuthRepository authRepository;

  final mockUser = UserEntity(
    id: '550e8400-e29b-41d4-a716-446655440000',
    email: 'test@example.com',
    displayName: 'testuser',
    role: UserRole.registered,
    createdAt: DateTime.utc(2025, 1, 1),
  );

  setUp(() {
    authRepository = MockAuthRepository();
    getCurrentUserUseCase = GetCurrentUserUseCase(authRepository);
  });

  group('GetCurrentUserUseCase', () {
    test(
      'should call IAuthRepository.getCurrentUser with no arguments',
      () async {
        when(
          () => authRepository.getCurrentUser(),
        ).thenAnswer((_) async => Right(mockUser));

        await getCurrentUserUseCase(const NoParams());

        verify(() => authRepository.getCurrentUser()).called(1);
      },
    );

    test(
      'should return Right(UserEntity) when a valid session exists',
      () async {
        when(
          () => authRepository.getCurrentUser(),
        ).thenAnswer((_) async => Right(mockUser));

        final result = await getCurrentUserUseCase(const NoParams());

        expect(result.isRight, isTrue);
        expect(result.right, mockUser);
      },
    );

    test(
      'should propagate Left(AuthFailure) when no token is cached',
      () async {
        const failure = Failure.auth(message: 'No active session.');
        when(
          () => authRepository.getCurrentUser(),
        ).thenAnswer((_) async => const Left(failure));

        final result = await getCurrentUserUseCase(const NoParams());

        expect(result.isLeft, isTrue);
        expect(result.left, isA<AuthFailure>());
      },
    );

    test('should propagate Left(AuthFailure) when the cached token is expired '
        'or the account no longer exists', () async {
      const failure = Failure.auth(message: 'Invalid or expired session.');
      when(
        () => authRepository.getCurrentUser(),
      ).thenAnswer((_) async => const Left(failure));

      final result = await getCurrentUserUseCase(const NoParams());

      expect(result.isLeft, isTrue);
      expect(result.left, failure);
    });

    test('should propagate Left(NetworkFailure) unchanged', () async {
      when(
        () => authRepository.getCurrentUser(),
      ).thenAnswer((_) async => const Left(Failure.network()));

      final result = await getCurrentUserUseCase(const NoParams());

      expect(result.isLeft, isTrue);
      expect(result.left, isA<NetworkFailure>());
    });

    test('should call the repository exactly once per invocation', () async {
      when(
        () => authRepository.getCurrentUser(),
      ).thenAnswer((_) async => Right(mockUser));

      await getCurrentUserUseCase(const NoParams());

      verify(() => authRepository.getCurrentUser()).called(1);
    });
  });
}
