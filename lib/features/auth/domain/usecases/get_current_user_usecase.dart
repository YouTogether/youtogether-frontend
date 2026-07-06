import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_entity.dart';
import '../repositories/i_auth_repository.dart';

/// Use case for retrieving the currently authenticated user's profile.
///
/// Extends `UseCase<UserEntity, NoParams>`. Delegates entirely to
/// `IAuthRepository.getCurrentUser()`, which validates the cached access
/// token by calling `GET /auth/me` and returns the fresh server-side
/// profile — never trusting a locally cached copy alone, mirroring the
/// backend's own design (a `GET /auth/me` call always re-reads the
/// database rather than trusting the token's claims; see backend
/// `GetCurrentUserUseCase`).
///
/// Absence of a valid session (no cached token, an expired token that
/// could not be silently renewed, or a token whose account no longer
/// exists) is modelled as `Left(Failure)`, not as `Right(null)`: there is
/// no meaningful non-error "no user" success value in this domain, and
/// keeping the success channel strictly non-nullable avoids a second way
/// to represent the same "not authenticated" outcome that `LoginUseCase`
/// and `RefreshTokenUseCase` already express through `Left(Failure)`.
///
/// Primary consumer: `AuthBloc.checkAuthStatus`,
/// dispatched once on application cold start.
///
/// @see IAuthRepository.getCurrentUser — the delegated port method
class GetCurrentUserUseCase extends UseCase<UserEntity, NoParams> {
  GetCurrentUserUseCase(this._authRepository);

  final IAuthRepository _authRepository;

  @override
  Future<Either<Failure, UserEntity>> call(NoParams params) {
    return _authRepository.getCurrentUser();
  }
}
