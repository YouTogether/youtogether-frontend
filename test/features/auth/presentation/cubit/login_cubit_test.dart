import 'package:bloc_test/bloc_test.dart';
import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';
import 'package:youtogether/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:youtogether/features/auth/domain/usecases/login_usecase.dart';
import 'package:youtogether/features/auth/presentation/cubit/login_cubit.dart';
import 'package:youtogether/features/auth/presentation/cubit/login_state.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late LoginUseCase loginUseCase;
  late MockAuthRepository authRepository;

  const validEmail = 'test@example.com';
  const validPassword = 'securepassword';

  final mockUser = UserEntity(
    id: '550e8400-e29b-41d4-a716-446655440000',
    email: validEmail,
    displayName: 'testuser',
    role: UserRole.registered,
    createdAt: DateTime.utc(2025, 1, 1),
  );

  setUp(() {
    authRepository = MockAuthRepository();
    // LoginUseCase is a thin wrapper; exercising it through a real
    // instance (backed by a mocked repository) keeps this suite focused
    // on LoginCubit's own behaviour — validation and state emission —
    // without re-mocking a use case whose delegation is already verified
    // by login_usecase_test.dart.
    loginUseCase = LoginUseCase(authRepository);
  });

  LoginCubit buildCubit() => LoginCubit(loginUseCase);

  group('LoginCubit', () {
    test('initial state is LoginState.initial', () {
      expect(buildCubit().state, const LoginState.initial());
    });

    group('valid input', () {
      blocTest<LoginCubit, LoginState>(
        'emits [loading, success] when the use case succeeds',
        setUp: () {
          when(
            () => authRepository.login(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ),
          ).thenAnswer((_) async => Right(mockUser));
        },
        build: buildCubit,
        act: (cubit) => cubit.login(email: validEmail, password: validPassword),
        expect: () => [const LoginState.loading(), const LoginState.success()],
      );

      blocTest<LoginCubit, LoginState>(
        'emits [loading, failure(AuthFailure)] on invalid credentials',
        setUp: () {
          when(
            () => authRepository.login(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ),
          ).thenAnswer(
            (_) async =>
                const Left(Failure.auth(message: 'Invalid email or password.')),
          );
        },
        build: buildCubit,
        act: (cubit) => cubit.login(email: validEmail, password: validPassword),
        expect: () => [
          const LoginState.loading(),
          const LoginState.failure(
            Failure.auth(message: 'Invalid email or password.'),
          ),
        ],
      );

      blocTest<LoginCubit, LoginState>(
        'emits [loading, failure(NetworkFailure)] when there is no '
        'connectivity',
        setUp: () {
          when(
            () => authRepository.login(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ),
          ).thenAnswer((_) async => const Left(Failure.network()));
        },
        build: buildCubit,
        act: (cubit) => cubit.login(email: validEmail, password: validPassword),
        expect: () => [
          const LoginState.loading(),
          const LoginState.failure(Failure.network()),
        ],
      );

      blocTest<LoginCubit, LoginState>(
        'calls the use case exactly once with the submitted values',
        setUp: () {
          when(
            () => authRepository.login(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ),
          ).thenAnswer((_) async => Right(mockUser));
        },
        build: buildCubit,
        act: (cubit) => cubit.login(email: validEmail, password: validPassword),
        verify: (_) {
          verify(
            () => authRepository.login(
              email: validEmail,
              password: validPassword,
            ),
          ).called(1);
        },
      );
    });

    group('invalid input', () {
      blocTest<LoginCubit, LoginState>(
        'emits only [failure(ValidationFailure)] for an invalid email, '
        'without calling the use case',
        build: buildCubit,
        act: (cubit) =>
            cubit.login(email: 'not-an-email', password: validPassword),
        expect: () => [
          const LoginState.failure(
            Failure.validation(
              errors: {'email': 'Please enter a valid email address.'},
            ),
          ),
        ],
        verify: (_) {
          verifyNever(
            () => authRepository.login(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ),
          );
        },
      );

      blocTest<LoginCubit, LoginState>(
        'emits [failure(ValidationFailure)] for an empty password',
        build: buildCubit,
        act: (cubit) => cubit.login(email: validEmail, password: ''),
        expect: () => [
          const LoginState.failure(
            Failure.validation(
              errors: {'password': 'Password must not be empty.'},
            ),
          ),
        ],
      );

      blocTest<LoginCubit, LoginState>(
        'collects both field violations when email and password are '
        'both invalid',
        build: buildCubit,
        act: (cubit) => cubit.login(email: 'not-an-email', password: ''),
        expect: () => [
          const LoginState.failure(
            Failure.validation(
              errors: {
                'email': 'Please enter a valid email address.',
                'password': 'Password must not be empty.',
              },
            ),
          ),
        ],
      );

      blocTest<LoginCubit, LoginState>(
        'never calls the use case when validation fails',
        build: buildCubit,
        act: (cubit) => cubit.login(email: 'not-an-email', password: ''),
        verify: (_) {
          verifyNever(
            () => authRepository.login(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ),
          );
        },
      );
    });

    group('reset', () {
      blocTest<LoginCubit, LoginState>(
        'emits LoginState.initial when called after a success',
        setUp: () {
          when(
            () => authRepository.login(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ),
          ).thenAnswer((_) async => Right(mockUser));
        },
        build: buildCubit,
        act: (cubit) async {
          await cubit.login(email: validEmail, password: validPassword);
          cubit.reset();
        },
        expect: () => [
          const LoginState.loading(),
          const LoginState.success(),
          const LoginState.initial(),
        ],
      );
    });
  });
}
