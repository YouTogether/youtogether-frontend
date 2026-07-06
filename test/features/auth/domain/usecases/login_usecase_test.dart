import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';
import 'package:youtogether/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:youtogether/features/auth/domain/usecases/login_params.dart';
import 'package:youtogether/features/auth/domain/usecases/login_usecase.dart';

/// Mocktail mock for [IAuthRepository].
///
/// Declared locally rather than imported from a shared mocks file, per the
/// convention established in `register_usecase_test.dart`: `IAuthRepository`
/// is still growing one method per task, so each test file that needs it
/// declares its own mock class implementing the interface as it stands at
/// that point. Because mocktail's `Mock` satisfies the abstract contract
/// via `noSuchMethod`, this does not require re-stubbing methods unrelated
/// to the use case under test.
class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late LoginUseCase loginUseCase;
  late MockAuthRepository authRepository;

  const validParams = LoginParams(
    email: 'test@example.com',
    password: 'securepassword',
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
    loginUseCase = LoginUseCase(authRepository);
  });

  group('LoginUseCase', () {
    test(
      'should call IAuthRepository.login with the fields unpacked from LoginParams',
      () async {
        when(
          () => authRepository.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => Right(mockUser));

        await loginUseCase(validParams);

        verify(
          () => authRepository.login(
            email: validParams.email,
            password: validParams.password,
          ),
        ).called(1);
      },
    );

    test('should return Right(UserEntity) on success', () async {
      when(
        () => authRepository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => Right(mockUser));

      final result = await loginUseCase(validParams);

      expect(result.isRight, isTrue);
      expect(result.right, mockUser);
    });

    test(
      'should propagate Left(AuthFailure) on invalid credentials (401) unchanged',
      () async {
        const failure = Failure.auth(message: 'Invalid email or password.');
        when(
          () => authRepository.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => const Left(failure));

        final result = await loginUseCase(validParams);

        expect(result.isLeft, isTrue);
        expect(result.left, isA<AuthFailure>());
        expect(result.left, failure);
      },
    );

    test('should return the identical AuthFailure message for an unknown '
        'email and for a wrong password (no user-enumeration leak)', () async {
      // The use case must not transform, branch on, or otherwise
      // distinguish the two cases — it simply forwards whatever the
      // repository returns. This test asserts that forwarding, not the
      // repository's own logic.
      const genericFailure = Failure.auth(
        message: 'Invalid email or password.',
      );

      when(
        () => authRepository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => const Left(genericFailure));

      final unknownEmailResult = await loginUseCase(
        const LoginParams(email: 'nobody@example.com', password: 'x'),
      );
      final wrongPasswordResult = await loginUseCase(
        const LoginParams(email: 'test@example.com', password: 'wrong'),
      );

      expect(
        (unknownEmailResult.left as AuthFailure).message,
        (wrongPasswordResult.left as AuthFailure).message,
      );
    });

    test('should propagate Left(NetworkFailure) unchanged', () async {
      when(
        () => authRepository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => const Left(Failure.network()));

      final result = await loginUseCase(validParams);

      expect(result.isLeft, isTrue);
      expect(result.left, isA<NetworkFailure>());
    });

    test('should call the repository exactly once per invocation', () async {
      when(
        () => authRepository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => Right(mockUser));

      await loginUseCase(validParams);

      verify(
        () => authRepository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).called(1);
    });
  });

  group('LoginParams', () {
    test('should hold email and password', () {
      const params = LoginParams(email: 'a@b.com', password: 'p4ssw0rd!');

      expect(params.email, 'a@b.com');
      expect(params.password, 'p4ssw0rd!');
    });

    test('should support value equality (freezed)', () {
      const a = LoginParams(email: 'a@b.com', password: 'pass1234');
      const b = LoginParams(email: 'a@b.com', password: 'pass1234');

      expect(a, b);
    });
  });
}
