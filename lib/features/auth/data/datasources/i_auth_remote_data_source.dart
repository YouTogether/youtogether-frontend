import '../models/user_model.dart';

/// Remote data source contract for the Authentication bounded context.
///
/// Implemented by `AuthRemoteDataSourceImpl`,
/// which performs the actual HTTP calls via Dio against the NestJS
/// backend.
///
/// This interface grows incrementally, one method per task, mirroring
/// how `IAuthRepository` was built:
/// - `register()`
/// - `login()`
/// - `getCurrentUser()`, `refreshToken()`
/// - `logout()`
///
/// @see AuthRepositoryImpl.register — primary consumer of [register]
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
}
