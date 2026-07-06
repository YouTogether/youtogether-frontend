import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/core/usecases/usecase.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';
import 'package:youtogether/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:youtogether/features/auth/domain/usecases/refresh_token_usecase.dart';

/// Mocktail mock for [IAuthRepository].
///
/// Declared locally, per the convention established across the auth
/// domain test suite (see `register_usecase_test.dart`,
/// `login_usecase_test.dart`).
class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late RefreshTokenUseCase refreshTokenUseCase;
  late MockAuthRepository authRepository;

  final renewedUser = UserEntity(
    id: '550e8400-e29b-41d4-a716-446655440000',
    email: 'test@example.com',
    displayName: 'testuser',
    role: UserRole.registered,
    createdAt: DateTime.utc(2025, 1, 1),
  );

  setUp(() {
    authRepository = MockAuthRepository();
    refreshTokenUseCase = RefreshTokenUseCase(authRepository);
  });

  group('RefreshTokenUseCase', () {
    test(
      'should call IAuthRepository.refreshToken with no arguments',
      () async {
        when(
          () => authRepository.refreshToken(),
        ).thenAnswer((_) async => Right(renewedUser));

        await refreshTokenUseCase(const NoParams());

        verify(() => authRepository.refreshToken()).called(1);
      },
    );

    test(
      'should return Right(UserEntity) with the renewed profile on success',
      () async {
        when(
          () => authRepository.refreshToken(),
        ).thenAnswer((_) async => Right(renewedUser));

        final result = await refreshTokenUseCase(const NoParams());

        expect(result.isRight, isTrue);
        expect(result.right, renewedUser);
      },
    );

    test(
      'should propagate Left(AuthFailure) when no refresh token is cached',
      () async {
        const failure = Failure.auth(message: 'No refresh token cached.');
        when(
          () => authRepository.refreshToken(),
        ).thenAnswer((_) async => const Left(failure));

        final result = await refreshTokenUseCase(const NoParams());

        expect(result.isLeft, isTrue);
        expect(result.left, isA<AuthFailure>());
      },
    );

    test('should propagate Left(AuthFailure) when the refresh token is '
        'expired or has already been used (rotation/replay)', () async {
      const failure = Failure.auth(
        message: 'Invalid or expired refresh token.',
      );
      when(
        () => authRepository.refreshToken(),
      ).thenAnswer((_) async => const Left(failure));

      final result = await refreshTokenUseCase(const NoParams());

      expect(result.isLeft, isTrue);
      expect(result.left, failure);
    });

    test('should propagate Left(NetworkFailure) unchanged', () async {
      when(
        () => authRepository.refreshToken(),
      ).thenAnswer((_) async => const Left(Failure.network()));

      final result = await refreshTokenUseCase(const NoParams());

      expect(result.isLeft, isTrue);
      expect(result.left, isA<NetworkFailure>());
    });

    test('should call the repository exactly once per invocation', () async {
      when(
        () => authRepository.refreshToken(),
      ).thenAnswer((_) async => Right(renewedUser));

      await refreshTokenUseCase(const NoParams());

      verify(() => authRepository.refreshToken()).called(1);
    });
  });
}
