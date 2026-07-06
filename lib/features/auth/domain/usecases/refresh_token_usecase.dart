import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_entity.dart';
import '../repositories/i_auth_repository.dart';

/// Use case for silently renewing an expired session.
///
/// Extends `UseCase<UserEntity, NoParams>`. Delegates entirely to
/// `IAuthRepository.refreshToken()`, which reads the cached refresh
/// token, calls `POST /auth/refresh`, and persists the newly issued
/// token pair on success.
///
/// Returns the renewed [UserEntity] directly rather than `void` (a
/// deliberate departure from the general shape
/// `Either<Failure, void>`):
/// the backend's `POST /auth/refresh` already returns the full user profile
/// alongside the rotated tokens (see backend `AuthResponseDto`), so
/// requiring a separate `GetCurrentUserUseCase` call immediately after a
/// successful refresh would reintroduce exactly the redundant round-trip
/// this use case exists to avoid — the same argument the interface
/// contracts make for `register()` establishing a session without a
/// subsequent login call (OWASP A07 row).
///
/// Primary consumer: `AuthBloc.checkAuthStatus`,
/// invoked when `GetCurrentUserUseCase` fails with an expired access
/// token, before falling back to `AuthUnauthenticated`.
///
/// @see IAuthRepository.refreshToken — the delegated port method
class RefreshTokenUseCase extends UseCase<UserEntity, NoParams> {
  RefreshTokenUseCase(this._authRepository);

  final IAuthRepository _authRepository;

  @override
  Future<Either<Failure, UserEntity>> call(NoParams params) {
    return _authRepository.refreshToken();
  }
}
