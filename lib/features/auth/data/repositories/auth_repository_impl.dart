import 'package:either_dart/either.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../datasources/i_auth_local_data_source.dart';
import '../datasources/i_auth_remote_data_source.dart';

/// Data layer implementation of the [IAuthRepository] port.
///
/// `IAuthRepository` was fully specified through
/// five methods: register, login, getCurrentUser,
/// refreshToken, logout, before any concrete implementation existed.
/// [register], [login], [getCurrentUser], and
/// [refreshToken] are now implemented; only [logout]
/// remains a temporary stub that throws [UnimplementedError], replaced
/// by real logic. No test exercises that stub — there is no
/// behaviour yet to verify.
///
/// [register] orchestrates:
/// 1. Delegate the network call to [IAuthRemoteDataSource.register].
/// 2. On success, persist the returned token pair via
///    [IAuthLocalDataSource.saveTokens] before returning to the caller —
///    a session is not considered established until tokens are safely
///    cached, consistent with the backend's own "register establishes a
///    session immediately" guarantee.
/// 3. Convert the [UserModel] to the domain [UserEntity] via
///    `toDomain()` only after the above succeeds.
///
/// [login] follows the identical remote-call-then-cache-tokens sequence
/// as [register] (see its own doc comment for the failure mapping,
/// which differs on one point: HTTP 401 becomes [AuthFailure], not
/// [ServerFailure] — see [login]'s own doc comment).
///
/// [getCurrentUser] and [refreshToken] both read a cached token from
/// [IAuthLocalDataSource] *before* making any network call: a `null`
/// result (nothing cached) is treated as an ordinary [AuthFailure] —
/// "no active session" — resolved entirely locally, never as an error
/// requiring a network round-trip. See each method's own doc comment for
/// its specific failure mapping.
///
/// Exception-to-Failure mapping (shared by all four implemented
/// methods except where noted): [ServerException] becomes
/// [ServerFailure] (carrying the original status code and message),
/// [NetworkException] becomes [NetworkFailure], and [CacheException]
/// becomes [CacheFailure]. No other exception type is expected from
/// either data source at this stage; anything else propagates unhandled
/// rather than being silently swallowed, so a genuine bug surfaces
/// instead of being misreported as a known failure category.
///
/// @see IAuthRepository — the domain port being implemented
class AuthRepositoryImpl implements IAuthRepository {
  AuthRepositoryImpl({
    required IAuthRemoteDataSource remoteDataSource,
    required IAuthLocalDataSource localDataSource,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource;

  final IAuthRemoteDataSource _remoteDataSource;
  final IAuthLocalDataSource _localDataSource;

  @override
  Future<Either<Failure, UserEntity>> register({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final userModel = await _remoteDataSource.register(
        email: email,
        password: password,
        username: username,
      );

      await _localDataSource.saveTokens(
        accessToken: userModel.accessToken,
        refreshToken: userModel.refreshToken,
      );

      return Right(userModel.toDomain());
    } on ServerException catch (exception) {
      return Left(
        Failure.server(
          statusCode: exception.statusCode,
          message: exception.message,
        ),
      );
    } on NetworkException {
      return const Left(Failure.network());
    } on CacheException catch (exception) {
      return Left(Failure.cache(message: exception.message));
    }
  }

  /// Authenticates an existing account with email and password.
  ///
  /// HTTP 401 is mapped to [Failure.auth] with a fixed, literal message
  /// — never the exception's own `message` field — regardless of what
  /// the backend actually sent. This is a deliberate, defensive
  /// duplication of the anti-enumeration guarantee already enforced
  /// server-side (`InvalidCredentialsFailure` on the backend): even if
  /// the backend's exact wording ever changed, this repository would
  /// still surface the same fixed message for every 401, preserving the
  /// guarantee documented on `IAuthRepository.login` that an unknown
  /// email and a wrong password remain indistinguishable to the caller.
  ///
  /// Any other status code falls through to the same generic
  /// [ServerFailure] mapping used by [register].
  @override
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  }) async {
    try {
      final userModel = await _remoteDataSource.login(
        email: email,
        password: password,
      );

      await _localDataSource.saveTokens(
        accessToken: userModel.accessToken,
        refreshToken: userModel.refreshToken,
      );

      return Right(userModel.toDomain());
    } on ServerException catch (exception) {
      if (exception.statusCode == 401) {
        return const Left(Failure.auth(message: 'Invalid email or password.'));
      }
      return Left(
        Failure.server(
          statusCode: exception.statusCode,
          message: exception.message,
        ),
      );
    } on NetworkException {
      return const Left(Failure.network());
    } on CacheException catch (exception) {
      return Left(Failure.cache(message: exception.message));
    }
  }

  /// Retrieves the profile of the currently authenticated user.
  ///
  /// Reads the cached access token before making any network call. If
  /// none is cached, returns [Failure.auth] locally — "no active
  /// session" — without attempting `GET /auth/me` at all.
  ///
  /// A 401 response (token invalid, expired, or its account no longer
  /// exists — see backend `UserNotFoundFailure`) is also mapped to
  /// [Failure.auth], with a fixed literal message, for the same reason
  /// documented on [login]: never forward a server-provided message for
  /// an authentication failure, regardless of what the backend
  /// specifically said.
  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    final accessToken = await _localDataSource.getAccessToken();
    if (accessToken == null) {
      return const Left(Failure.auth(message: 'No active session.'));
    }

    try {
      final profile = await _remoteDataSource.getCurrentUser(
        accessToken: accessToken,
      );
      return Right(profile.toDomain());
    } on ServerException catch (exception) {
      if (exception.statusCode == 401) {
        return const Left(Failure.auth(message: 'Invalid or expired session.'));
      }
      return Left(
        Failure.server(
          statusCode: exception.statusCode,
          message: exception.message,
        ),
      );
    } on NetworkException {
      return const Left(Failure.network());
    } on CacheException catch (exception) {
      return Left(Failure.cache(message: exception.message));
    }
  }

  /// Silently renews the session using the cached refresh token.
  ///
  /// Reads the cached refresh token before making any network call. If
  /// none is cached, returns [Failure.auth] locally, without attempting
  /// `POST /auth/refresh` at all.
  ///
  /// On success, the newly rotated token pair is persisted via
  /// [IAuthLocalDataSource.saveTokens] before returning — mirroring
  /// [register] and [login]'s "cache before returning" sequencing.
  ///
  /// A 401 response (invalid, expired, or already-rotated/replayed
  /// token — see backend `InvalidRefreshTokenFailure`) is mapped to
  /// [Failure.auth] with a fixed literal message, for the same reason
  /// documented on [login].
  @override
  Future<Either<Failure, UserEntity>> refreshToken() async {
    final cachedRefreshToken = await _localDataSource.getRefreshToken();
    if (cachedRefreshToken == null) {
      return const Left(Failure.auth(message: 'No refresh token cached.'));
    }

    try {
      final userModel = await _remoteDataSource.refreshToken(
        refreshToken: cachedRefreshToken,
      );

      await _localDataSource.saveTokens(
        accessToken: userModel.accessToken,
        refreshToken: userModel.refreshToken,
      );

      return Right(userModel.toDomain());
    } on ServerException catch (exception) {
      if (exception.statusCode == 401) {
        return const Left(
          Failure.auth(message: 'Invalid or expired refresh token.'),
        );
      }
      return Left(
        Failure.server(
          statusCode: exception.statusCode,
          message: exception.message,
        ),
      );
    } on NetworkException {
      return const Left(Failure.network());
    } on CacheException catch (exception) {
      return Left(Failure.cache(message: exception.message));
    }
  }

  @override
  Future<Either<Failure, void>> logout() {
    // TODO implement later
    throw UnimplementedError('AuthRepositoryImpl.logout is implemented later.');
  }
}
