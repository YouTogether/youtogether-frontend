import '../models/user_model.dart';
import '../models/user_profile_model.dart';

/// Remote data source contract for the Authentication bounded context.
///
/// Implemented by `AuthRemoteDataSourceImpl`, which performs the actual
/// HTTP calls via Dio against the NestJS backend.
///
/// This interface grows incrementally, one method per task, mirroring
/// how `IAuthRepository` was built:
/// - `register()`
/// - `login()`
/// - `getCurrentUser()`, `refreshToken()`
/// - `logout()`
///
/// @see AuthRepositoryImpl.register — primary consumer of [register]
/// @see AuthRemoteDataSourceImpl.register — the HTTP implementation
abstract class IAuthRemoteDataSource {
  /// Sends `POST /auth/register` with the given credentials and display
  /// name.
  ///
  /// @returns The parsed [UserModel], including the issued session
  ///   tokens.
  /// @throws `ServerException` (statusCode 409) if the email is already
  ///   registered to an active account.
  /// @throws `ServerException` (statusCode 400) if the server rejects
  ///   the payload (validation failure).
  /// @throws `NetworkException` if the request never reaches the server.
  Future<UserModel> register({
    required String email,
    required String password,
    required String username,
  });

  /// Sends `POST /auth/login` with the given credentials.
  ///
  /// @returns The parsed [UserModel], including the issued session
  ///   tokens.
  /// @throws `ServerException` (statusCode 401) on invalid credentials.
  ///   The backend returns the identical generic message for an unknown
  ///   email and for a wrong password (OWASP A07:2021 — see backend
  ///   `InvalidCredentialsFailure`); this data source forwards that
  ///   status code and message without attempting to distinguish the
  ///   two cases either.
  /// @throws `NetworkException` if the request never reaches the server.
  Future<UserModel> login({required String email, required String password});

  /// Sends `GET /auth/me` with the given access token attached as a
  /// Bearer credential.
  ///
  /// The token is supplied explicitly by the caller (`AuthRepositoryImpl`,
  /// which reads it from `IAuthLocalDataSource`) rather than attached
  /// automatically by a Dio interceptor — no such interceptor exists yet
  /// in this codebase, and an explicit parameter keeps this method
  /// testable in isolation without one.
  ///
  /// @returns The parsed [UserProfileModel] — no session tokens are
  ///   present in this response (unlike [register]/[login]/[refreshToken]).
  /// @throws `ServerException` (statusCode 401) if the token is missing,
  ///   invalid, expired, or its underlying account no longer exists.
  /// @throws `NetworkException` if the request never reaches the server.
  Future<UserProfileModel> getCurrentUser({required String accessToken});

  /// Sends `POST /auth/refresh` with the given refresh token.
  ///
  /// @returns The parsed [UserModel], including the newly rotated
  ///   session tokens (the backend's `POST /auth/refresh` returns the
  ///   same response shape as `register`/`login` — see backend
  ///   `AuthResponseDto`).
  /// @throws `ServerException` (statusCode 401) if the refresh token is
  ///   invalid, expired, or has already been used (rotation/replay — see
  ///   backend `InvalidRefreshTokenFailure`, covered by the same generic
  ///   401 on this endpoint).
  /// @throws `NetworkException` if the request never reaches the server.
  Future<UserModel> refreshToken({required String refreshToken});
}
