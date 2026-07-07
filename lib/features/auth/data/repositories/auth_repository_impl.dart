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
/// refreshToken, logout before any concrete implementation existed. As
/// a result, this class is scoped
/// to `register()` only — must nonetheless provide a body for every
/// abstract method to satisfy the interface. The four methods outside
/// this ticket's scope ([login], [getCurrentUser], [refreshToken],
/// [logout]) are temporary stubs that throw [UnimplementedError]; each
/// is replaced by real logic in its own ticket. No test exercises a stub — there is
/// no behaviour yet to verify.
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
/// Exception-to-Failure mapping: [ServerException] becomes
/// [ServerFailure] (carrying the original status code and message),
/// [NetworkException] becomes [NetworkFailure], and [CacheException] —
/// which can only arise from the local token-saving step, since the
/// remote call already succeeded by that point — becomes [CacheFailure].
/// No other exception type is expected from either data source at this
/// stage; anything else propagates unhandled rather than being silently
/// swallowed, so a genuine bug surfaces instead of being misreported as
/// a known failure category.
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

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() {
    // TODO implement later
    throw UnimplementedError(
      'AuthRepositoryImpl.getCurrentUser is implemented later.',
    );
  }

  @override
  Future<Either<Failure, UserEntity>> refreshToken() {
    // TODO implement later
    throw UnimplementedError(
      'AuthRepositoryImpl.refreshToken is implemented later.',
    );
  }

  @override
  Future<Either<Failure, void>> logout() {
    // TODO implement later
    throw UnimplementedError('AuthRepositoryImpl.logout is implemented later.');
  }
}
