import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_entity.dart';
import '../repositories/i_auth_repository.dart';
import 'login_params.dart';

/// Use case for authenticating an existing account.
///
/// Extends `UseCase<UserEntity, LoginParams>`.
/// Contains no business logic beyond unpacking [LoginParams]
/// into the named-parameter call expected by `IAuthRepository.login()`
/// and returning its result unchanged — mirroring the backend's
/// `LoginUseCase.execute()`, which purely delegates to
/// `IAuthRepository.login()` without adding logic of its own.
///
/// @see IAuthRepository.login — the delegated port method
/// @see LoginParams — the input value object
class LoginUseCase extends UseCase<UserEntity, LoginParams> {
  LoginUseCase(this._authRepository);

  final IAuthRepository _authRepository;

  @override
  Future<Either<Failure, UserEntity>> call(LoginParams params) {
    return _authRepository.login(
      email: params.email,
      password: params.password,
    );
  }
}
