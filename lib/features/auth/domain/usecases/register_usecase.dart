import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_entity.dart';
import '../repositories/i_auth_repository.dart';
import 'register_params.dart';

/// Use case for registering a new account.
///
/// Extends `UseCase<UserEntity, RegisterParams>`.
/// Contains no business logic beyond unpacking [RegisterParams]
/// into the named-parameter call expected by `IAuthRepository.register()`
/// and returning its result unchanged — mirroring the backend's
/// `RegisterUseCase.execute()`, which purely delegates to
/// `IAuthRepository.register()` without adding logic of its own.
///
/// @see IAuthRepository.register — the delegated port method
/// @see RegisterParams — the input value object
class RegisterUseCase extends UseCase<UserEntity, RegisterParams> {
  RegisterUseCase(this._authRepository);

  final IAuthRepository _authRepository;

  @override
  Future<Either<Failure, UserEntity>> call(RegisterParams params) {
    return _authRepository.register(
      email: params.email,
      password: params.password,
      username: params.username,
    );
  }
}
