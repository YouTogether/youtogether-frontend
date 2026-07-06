import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';

/// Repository port for the Authentication bounded context.
///
/// This abstract class defines the contract the domain layer depends on.
/// It is implemented by `AuthRepositoryImpl` in the data layer,
/// which performs the actual HTTP
/// call and local token persistence.
///
/// Mirrors the backend's `IAuthRepository` abstract class in spirit:
/// domain code depends on this interface, never on the concrete data
/// layer implementation, enforcing the same dependency-inversion boundary
/// on both sides of the stack.
///
/// This interface grows incrementally, one method per task, mirroring how
/// the backend's `IAuthRepository` was built (register → login → refresh
/// → logout → getCurrentUser) rather than being fully specified up front:
/// - `register()`
/// - `login()`
/// - `getCurrentUser()`, `refreshToken()`
/// - `logout()`
///
/// @see RegisterUseCase — primary consumer of [register]
/// @see LoginUseCase — primary consumer of [login]
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
  ///   `Left(ServerFailure)` on HTTP 409 (duplicate email) or any other
  ///   unhandled server error.
  ///   `Left(NetworkFailure)` if the request never reaches the server.
  Future<Either<Failure, UserEntity>> register({
    required String email,
    required String password,
    required String username,
  });

  /// Authenticates an existing account with email and password.
  ///
  /// Calls `POST /auth/login` (via `IAuthRemoteDataSource`, forthcoming)
  /// and persists the returned access/refresh token pair locally (via
  /// `IAuthLocalDataSource`, forthcoming) on success.
  ///
  /// The backend deliberately returns the same generic failure for an
  /// unknown email and for a wrong password, to prevent user enumeration
  /// (OWASP A07:2021 — see backend `InvalidCredentialsFailure`). This
  /// contract preserves that guarantee: implementations must not attempt
  /// to distinguish the two cases when mapping the HTTP 401 response.
  ///
  /// @param email User email address.
  /// @param password User plaintext password.
  /// @returns `Right(UserEntity)` on success.
  ///   `Left(AuthFailure)` on HTTP 401 (invalid email or password —
  ///   the two cases are indistinguishable by design).
  ///   `Left(NetworkFailure)` if the request never reaches the server.
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  });
}
