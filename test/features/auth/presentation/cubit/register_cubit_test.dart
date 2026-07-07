import 'package:bloc_test/bloc_test.dart';
import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';
import 'package:youtogether/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:youtogether/features/auth/domain/usecases/register_usecase.dart';
import 'package:youtogether/features/auth/presentation/cubit/register_cubit.dart';
import 'package:youtogether/features/auth/presentation/cubit/register_state.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late RegisterUseCase registerUseCase;
  late MockAuthRepository authRepository;

  const validEmail = 'test@example.com';
  const validPassword = 'securepassword';
  const validUsername = 'testuser';

  final mockUser = UserEntity(
    id: '550e8400-e29b-41d4-a716-446655440000',
    email: validEmail,
    displayName: validUsername,
    role: UserRole.registered,
    createdAt: DateTime.utc(2025, 1, 1),
  );

  setUp(() {
    authRepository = MockAuthRepository();
    // RegisterUseCase is a thin wrapper; exercising it through a real
    // instance (backed by a mocked repository) keeps this suite focused
    // on RegisterCubit's own behaviour — validation and state emission —
    // without re-mocking a use case whose delegation is already verified
    // by register_usecase_test.dart.
    registerUseCase = RegisterUseCase(authRepository);
  });

  RegisterCubit buildCubit() => RegisterCubit(registerUseCase);

  group('RegisterCubit', () {
    test('initial state is RegisterState.initial', () {
      expect(buildCubit().state, const RegisterState.initial());
    });

    group('valid input', () {
      blocTest<RegisterCubit, RegisterState>(
        'emits [loading, success] when the use case succeeds',
        setUp: () {
          when(
            () => authRepository.register(
              email: any(named: 'email'),
              password: any(named: 'password'),
              username: any(named: 'username'),
            ),
          ).thenAnswer((_) async => Right(mockUser));
        },
        build: buildCubit,
        act: (cubit) => cubit.register(
          email: validEmail,
          password: validPassword,
          username: validUsername,
        ),
        expect: () => [
          const RegisterState.loading(),
          const RegisterState.success(),
        ],
      );

      blocTest<RegisterCubit, RegisterState>(
        'emits [loading, failure(ServerFailure)] when the server rejects '
        'a duplicate email (409)',
        setUp: () {
          when(
            () => authRepository.register(
              email: any(named: 'email'),
              password: any(named: 'password'),
              username: any(named: 'username'),
            ),
          ).thenAnswer(
            (_) async => const Left(
              Failure.server(
                statusCode: 409,
                message: 'An active account already exists for this email.',
              ),
            ),
          );
        },
        build: buildCubit,
        act: (cubit) => cubit.register(
          email: validEmail,
          password: validPassword,
          username: validUsername,
        ),
        expect: () => [
          const RegisterState.loading(),
          const RegisterState.failure(
            Failure.server(
              statusCode: 409,
              message: 'An active account already exists for this email.',
            ),
          ),
        ],
      );

      blocTest<RegisterCubit, RegisterState>(
        'emits [loading, failure(NetworkFailure)] when there is no '
        'connectivity',
        setUp: () {
          when(
            () => authRepository.register(
              email: any(named: 'email'),
              password: any(named: 'password'),
              username: any(named: 'username'),
            ),
          ).thenAnswer((_) async => const Left(Failure.network()));
        },
        build: buildCubit,
        act: (cubit) => cubit.register(
          email: validEmail,
          password: validPassword,
          username: validUsername,
        ),
        expect: () => [
          const RegisterState.loading(),
          const RegisterState.failure(Failure.network()),
        ],
      );

      blocTest<RegisterCubit, RegisterState>(
        'calls the use case exactly once with the submitted values',
        setUp: () {
          when(
            () => authRepository.register(
              email: any(named: 'email'),
              password: any(named: 'password'),
              username: any(named: 'username'),
            ),
          ).thenAnswer((_) async => Right(mockUser));
        },
        build: buildCubit,
        act: (cubit) => cubit.register(
          email: validEmail,
          password: validPassword,
          username: validUsername,
        ),
        verify: (_) {
          verify(
            () => authRepository.register(
              email: validEmail,
              password: validPassword,
              username: validUsername,
            ),
          ).called(1);
        },
      );
    });

    group('invalid input', () {
      blocTest<RegisterCubit, RegisterState>(
        'emits only [failure(ValidationFailure)] for an invalid email, '
        'without calling the use case',
        build: buildCubit,
        act: (cubit) => cubit.register(
          email: 'not-an-email',
          password: validPassword,
          username: validUsername,
        ),
        expect: () => [
          const RegisterState.failure(
            Failure.validation(
              errors: {'email': 'Please enter a valid email address.'},
            ),
          ),
        ],
        verify: (_) {
          verifyNever(
            () => authRepository.register(
              email: any(named: 'email'),
              password: any(named: 'password'),
              username: any(named: 'username'),
            ),
          );
        },
      );

      blocTest<RegisterCubit, RegisterState>(
        'emits [failure(ValidationFailure)] for a password shorter than '
        '8 characters',
        build: buildCubit,
        act: (cubit) => cubit.register(
          email: validEmail,
          password: '1234567',
          username: validUsername,
        ),
        expect: () => [
          const RegisterState.failure(
            Failure.validation(
              errors: {'password': 'Password must be at least 8 characters.'},
            ),
          ),
        ],
      );

      blocTest<RegisterCubit, RegisterState>(
        'emits [failure(ValidationFailure)] for an empty username',
        build: buildCubit,
        act: (cubit) => cubit.register(
          email: validEmail,
          password: validPassword,
          username: '',
        ),
        expect: () => [
          const RegisterState.failure(
            Failure.validation(
              errors: {'username': 'Username must not be empty.'},
            ),
          ),
        ],
      );

      blocTest<RegisterCubit, RegisterState>(
        'emits [failure(ValidationFailure)] for a username longer than '
        '50 characters',
        build: buildCubit,
        act: (cubit) => cubit.register(
          email: validEmail,
          password: validPassword,
          username: List.filled(51, 'a').join(),
        ),
        expect: () => [
          const RegisterState.failure(
            Failure.validation(
              errors: {'username': 'Username must not exceed 50 characters.'},
            ),
          ),
        ],
      );

      blocTest<RegisterCubit, RegisterState>(
        'collects every field violation in a single ValidationFailure '
        'when multiple fields are invalid at once',
        build: buildCubit,
        act: (cubit) => cubit.register(
          email: 'not-an-email',
          password: 'short',
          username: '',
        ),
        expect: () => [
          const RegisterState.failure(
            Failure.validation(
              errors: {
                'email': 'Please enter a valid email address.',
                'password': 'Password must be at least 8 characters.',
                'username': 'Username must not be empty.',
              },
            ),
          ),
        ],
      );

      blocTest<RegisterCubit, RegisterState>(
        'never calls the use case when validation fails',
        build: buildCubit,
        act: (cubit) => cubit.register(
          email: 'not-an-email',
          password: 'short',
          username: '',
        ),
        verify: (_) {
          verifyNever(
            () => authRepository.register(
              email: any(named: 'email'),
              password: any(named: 'password'),
              username: any(named: 'username'),
            ),
          );
        },
      );
    });
  });
}
