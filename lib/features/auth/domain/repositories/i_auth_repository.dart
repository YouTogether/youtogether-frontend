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
/// This interface grows incrementally, one method (or pair) per task, mirroring how
/// the backend's `IAuthRepository` was built (register → login → refresh
/// → logout → getCurrentUser) rather than being fully specified up front:
/// - `register()`
/// - `login()`
/// - `getCurrentUser()`, `refreshToken()`
/// - `logout()`
///
/// @see RegisterUseCase — primary consumer of [register]
/// @see LoginUseCase — primary consumer of [login]
/// @see GetCurrentUserUseCase — primary consumer of [getCurrentUser]
/// @see RefreshTokenUseCase — primary consumer of [refreshToken]
/// @see LogoutUseCase — primary consumer of [logout]
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

  /// Returns the current authenticated user by validating the cached
  /// access token against `GET /auth/me`.
  ///
  /// Always performs a fresh server-side lookup rather than trusting the
  /// cached token's claims alone, mirroring the backend's own design (a
  /// `GET /auth/me` call always re-reads the database — see backend
  /// `GetCurrentUserUseCase`, which exists precisely to catch a token
  /// whose underlying account was deactivated after issuance).
  ///
  /// This method takes no parameters: the access token is read
  /// internally from local secure storage by the implementation (via
  /// `IAuthLocalDataSource`, forthcoming), not supplied by the caller.
  ///
  /// Absence of a valid session (no cached token, or a cached token the
  /// server no longer honours) is modelled as `Left(Failure)`, never as
  /// `Right(null)` — see [GetCurrentUserUseCase] for the rationale.
  ///
  /// @returns `Right(UserEntity)` on success.
  ///   `Left(AuthFailure)` if no access token is cached, or the cached
  ///   token is invalid/expired/orphaned (HTTP 401).
  ///   `Left(NetworkFailure)` if the request never reaches the server.
  Future<Either<Failure, UserEntity>> getCurrentUser();

  /// Silently renews the session using the cached refresh token via
  /// `POST /auth/refresh`, persisting the newly issued access/refresh
  /// token pair locally on success.
  ///
  /// This method takes no parameters: the refresh token is read
  /// internally from local secure storage by the implementation, not
  /// supplied by the caller.
  ///
  /// Returns the renewed [UserEntity], not `void`: the backend's
  /// `POST /auth/refresh` already returns the full user profile
  /// alongside the rotated tokens (see backend `AuthResponseDto`), so
  /// this contract avoids forcing a redundant `getCurrentUser()` call
  /// immediately after a successful refresh — see [RefreshTokenUseCase]
  /// for the full rationale.
  ///
  /// @returns `Right(UserEntity)` on success, with new tokens persisted.
  ///   `Left(AuthFailure)` if no refresh token is cached, or the cached
  ///   refresh token is invalid, expired, or has already been used
  ///   (rotation/replay — see backend `InvalidRefreshTokenFailure`, which
  ///   the same generic HTTP 401 covers on this endpoint too).
  ///   `Left(NetworkFailure)` if the request never reaches the server.
  Future<Either<Failure, UserEntity>> refreshToken();

  /// Terminates the current session on both client and server.
  ///
  /// Calls `POST /auth/logout` (via `IAuthRemoteDataSource`, forthcoming)
  /// with the cached access token to invalidate the refresh token
  /// server-side, then unconditionally clears the locally cached token
  /// pair (via `IAuthLocalDataSource`, forthcoming) — even if the remote
  /// call fails (e.g. no network connectivity). The user must never be
  /// left in a state where the app still behaves as authenticated after
  /// requesting logout, regardless of server reachability.
  /// This method takes no parameters: the access token is read
  /// internally from local secure storage by the implementation, not
  /// supplied by the caller.
  ///
  /// @returns `Right(null)` once local tokens are cleared, whether or not
  ///   the remote call succeeded — logout is not expected to fail from
  ///   the caller's perspective. Implementations should not surface
  ///   `Left(NetworkFailure)` here; a failed remote call is logged and
  ///   swallowed, not propagated, precisely because local token clearing
  ///   is unconditional.
  Future<Either<Failure, void>> logout();
}
