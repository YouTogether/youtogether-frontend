import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/core/usecases/usecase.dart';
import 'package:youtogether/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:youtogether/features/auth/domain/usecases/logout_usecase.dart';

/// Mocktail mock for [IAuthRepository].
///
/// Declared locally, per the convention established across the auth
/// domain test suite (see `register_usecase_test.dart`,
/// `login_usecase_test.dart`, `get_current_user_usecase_test.dart`,
/// `refresh_token_usecase_test.dart`).
class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late LogoutUseCase logoutUseCase;
  late MockAuthRepository authRepository;

  setUp(() {
    authRepository = MockAuthRepository();
    logoutUseCase = LogoutUseCase(authRepository);
  });

  group('LogoutUseCase', () {
    test('should call IAuthRepository.logout with no arguments', () async {
      when(
        () => authRepository.logout(),
      ).thenAnswer((_) async => const Right(null));

      await logoutUseCase(const NoParams());

      verify(() => authRepository.logout()).called(1);
    });

    test('should return Right(null) on success', () async {
      when(
        () => authRepository.logout(),
      ).thenAnswer((_) async => const Right(null));

      final result = await logoutUseCase(const NoParams());

      expect(result.isRight, isTrue);
    });

    test('should propagate Left(Failure) unchanged if the repository ever '
        'reports one (the repository is expected to swallow remote errors, '
        'but the use case must not mask a Left it does receive)', () async {
      const failure = Failure.cache(message: 'Unable to clear tokens.');
      when(
        () => authRepository.logout(),
      ).thenAnswer((_) async => const Left(failure));

      final result = await logoutUseCase(const NoParams());

      expect(result.isLeft, isTrue);
      expect(result.left, failure);
    });

    test('should call the repository exactly once per invocation', () async {
      when(
        () => authRepository.logout(),
      ).thenAnswer((_) async => const Right(null));

      await logoutUseCase(const NoParams());

      verify(() => authRepository.logout()).called(1);
    });
  });
}
