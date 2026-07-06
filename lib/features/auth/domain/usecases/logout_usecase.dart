import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/i_auth_repository.dart';

/// Use case for terminating the current session on both client and
/// server.
///
/// Extends `UseCase<void, NoParams>`. Delegates entirely to
/// `IAuthRepository.logout()`, which invalidates the session server-side
/// and unconditionally clears the locally cached token pair — even if
/// the remote call fails, mirroring the backend's own logout semantics
/// (idempotent, no observable failure from the caller's perspective; see
/// backend `LogoutUseCase`, which likewise returns no domain result
/// beyond confirmation).
///
/// Unlike the other auth use cases, this one carries no meaningful
/// success payload: there is no [UserEntity] to return, since the whole
/// point of the operation is that no user remains authenticated
/// afterwards.
///
/// Primary consumer: `AuthBloc.logoutRequested`,
/// dispatched by the `ProfilePage` logout button.
///
/// @see IAuthRepository.logout — the delegated port method
class LogoutUseCase extends UseCase<void, NoParams> {
  LogoutUseCase(this._authRepository);

  final IAuthRepository _authRepository;

  @override
  Future<Either<Failure, void>> call(NoParams params) {
    return _authRepository.logout();
  }
}
