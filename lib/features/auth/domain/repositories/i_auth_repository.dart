import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';

/// Repository port for the Authentication bounded context.
///
/// This abstract class defines the contract the domain layer depends on.
/// It is implemented by `AuthRepositoryImpl` in the data layer
/// which performs the actual HTTP call and local
/// token persistence.
///
/// Mirrors the backend's `IAuthRepository` abstract class in spirit:
/// domain code depends on this interface, never on the concrete data
/// layer implementation, enforcing the same dependency-inversion boundary
/// on both sides of the stack.
///
/// This class defines [register] only. Subsequent tasks extend
/// this interface incrementally, mirroring how the backend's
/// `IAuthRepository` grew one method per task (register → login →
/// refresh → logout → getCurrentUser)
///
/// @see RegisterUseCase — primary consumer of [register]
abstract class IAuthRepository {
  /// Registers a new account and establishes a session immediately.
  ///
  /// Calls `POST /auth/register` (via `IAuthRemoteDataSource`,
  /// forthcoming) and persists the returned access/refresh token pair
  /// locally (via `IAuthLocalDataSource`, forthcoming) on success —
  /// registration establishes a session without a redundant login
  /// round-trip (OWASP A07 row).
  ///
  /// @param email User email address.
  /// @param password User plaintext password.
  /// @param username Display name shown in the UI.
  /// @returns `Right(UserEntity)` on success.
  ///   `Left(ValidationFailure)` on malformed input (HTTP 400).
  ///   `Left(AuthFailure)` — not expected on this endpoint, reserved for
  ///   symmetry with `login()` in later tasks.
  ///   `Left(ServerFailure)` on HTTP 409 (duplicate email) or any other
  ///   unhandled server error.
  ///   `Left(NetworkFailure)` if the request never reaches the server.
  Future<Either<Failure, UserEntity>> register({
    required String email,
    required String password,
    required String username,
  });
}
