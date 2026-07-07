import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';
import 'package:youtogether/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:youtogether/features/auth/domain/usecases/register_params.dart';
import 'package:youtogether/features/auth/domain/usecases/register_usecase.dart';

/// Mocktail mock for [IAuthRepository].
///
/// Location matches (Testing Contracts):
/// `MockAuthRepository`, defined alongside the test that consumes it
/// rather than in a separate shared mocks file, since this is the
/// first task to need it. Later tasks reuse this same
/// class as the interface grows.
class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late RegisterUseCase registerUseCase;
  late MockAuthRepository authRepository;

  const validParams = RegisterParams(
    email: 'test@example.com',
    password: 'securepassword',
    username: 'testuser',
  );

  final mockUser = UserEntity(
    id: '550e8400-e29b-41d4-a716-446655440000',
    email: 'test@example.com',
    displayName: 'testuser',
    role: UserRole.registered,
    createdAt: DateTime.utc(2025, 1, 1),
  );

  setUp(() {
    authRepository = MockAuthRepository();
    registerUseCase = RegisterUseCase(authRepository);
  });

  group('RegisterUseCase', () {
    test(
      'should call IAuthRepository.register with the fields unpacked from RegisterParams',
      () async {
        when(
          () => authRepository.register(
            email: any(named: 'email'),
            password: any(named: 'password'),
            username: any(named: 'username'),
          ),
        ).thenAnswer((_) async => Right(mockUser));

        await registerUseCase(validParams);

        verify(
          () => authRepository.register(
            email: validParams.email,
            password: validParams.password,
            username: validParams.username,
          ),
        ).called(1);
      },
    );

    test('should return Right(UserEntity) on success', () async {
      when(
        () => authRepository.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
          username: any(named: 'username'),
        ),
      ).thenAnswer((_) async => Right(mockUser));

      final result = await registerUseCase(validParams);

      expect(result.isRight, isTrue);
      expect(result.right, mockUser);
    });

    test(
      'should propagate Left(ServerFailure) on duplicate email (409)',
      () async {
        const failure = Failure.server(
          statusCode: 409,
          message: 'Email already in use',
        );
        when(
          () => authRepository.register(
            email: any(named: 'email'),
            password: any(named: 'password'),
            username: any(named: 'username'),
          ),
        ).thenAnswer((_) async => const Left(failure));

        final result = await registerUseCase(validParams);

        expect(result.isLeft, isTrue);
        expect(result.left, isA<ServerFailure>());
      },
    );

    test('should propagate Left(ValidationFailure) unchanged', () async {
      const failure = Failure.validation(
        errors: {'password': 'password must be at least 8 characters'},
      );
      when(
        () => authRepository.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
          username: any(named: 'username'),
        ),
      ).thenAnswer((_) async => const Left(failure));

      final result = await registerUseCase(validParams);

      expect(result.isLeft, isTrue);
      expect(result.left, failure);
    });

    test('should propagate Left(NetworkFailure) unchanged', () async {
      when(
        () => authRepository.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
          username: any(named: 'username'),
        ),
      ).thenAnswer((_) async => const Left(Failure.network()));

      final result = await registerUseCase(validParams);

      expect(result.isLeft, isTrue);
      expect(result.left, isA<NetworkFailure>());
    });

    test('should call the repository exactly once per invocation', () async {
      when(
        () => authRepository.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
          username: any(named: 'username'),
        ),
      ).thenAnswer((_) async => Right(mockUser));

      await registerUseCase(validParams);

      verify(
        () => authRepository.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
          username: any(named: 'username'),
        ),
      ).called(1);
    });
  });

  group('RegisterParams', () {
    test('should hold email, password, and username', () {
      const params = RegisterParams(
        email: 'a@b.com',
        password: 'p4ssw0rd!',
        username: 'myuser',
      );

      expect(params.email, 'a@b.com');
      expect(params.password, 'p4ssw0rd!');
      expect(params.username, 'myuser');
    });

    test('should support value equality (freezed)', () {
      const a = RegisterParams(
        email: 'a@b.com',
        password: 'pass1234',
        username: 'user',
      );
      const b = RegisterParams(
        email: 'a@b.com',
        password: 'pass1234',
        username: 'user',
      );

      expect(a, b);
    });
  });
}
