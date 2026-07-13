import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../models/user_model.dart';
import '../models/user_profile_model.dart';
import 'i_auth_remote_data_source.dart';

/// Dio-based implementation of [IAuthRemoteDataSource].
///
/// Receives a pre-configured [Dio] instance via constructor injection —
/// base URL, timeouts, and certificate pinning (OWASP A05 row)
/// are the concern of whichever module wires the
/// dependency graph (`get_it`), not of this class.
///
/// Endpoint paths are static string literals, never built by
/// interpolating request data into the URL (OWASP A03 row) — the request
/// body carries all user-supplied values, exclusively via Dio's typed
/// `data` parameter.
///
/// Grows one method per task, mirroring [IAuthRemoteDataSource] itself:
/// - `register()`
/// - `login()`
/// - `getCurrentUser()`, `refreshToken()`
/// - `logout()`
class AuthRemoteDataSourceImpl implements IAuthRemoteDataSource {
  const AuthRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<UserModel> register({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {'email': email, 'password': password, 'username': username},
      );

      return UserModel.fromJson(response.data!);
    } on DioException catch (exception) {
      throw _mapDioException(exception);
    }
  }

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      return UserModel.fromJson(response.data!);
    } on DioException catch (exception) {
      // Reuses the same generic mapper as register(): a 401 here becomes
      // a ServerException(401, ...) like any other status code. The
      // semantic decision to treat 401 specifically as an AuthFailure
      // belongs to AuthRepositoryImpl.login, not to this data source —
      // keeping this class's exception mapping identical across every
      // method it exposes.
      throw _mapDioException(exception);
    }
  }

  @override
  Future<UserProfileModel> getCurrentUser({required String accessToken}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      return UserProfileModel.fromJson(response.data!);
    } on DioException catch (exception) {
      throw _mapDioException(exception);
    }
  }

  @override
  Future<UserModel> refreshToken({required String refreshToken}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      return UserModel.fromJson(response.data!);
    } on DioException catch (exception) {
      throw _mapDioException(exception);
    }
  }

  @override
  Future<void> logout({required String accessToken}) async {
    try {
      await _dio.post<void>(
        '/auth/logout',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
    } on DioException catch (exception) {
      throw _mapDioException(exception);
    }
  }

  /// Maps a [DioException] to the typed exception hierarchy consumed by
  /// [AuthRepositoryImpl].
  ///
  /// - [DioExceptionType.connectionError] (and the related timeout
  ///   variants, which are equally "the request never reached the
  ///   server" from the caller's perspective) become [NetworkException].
  /// - Any response actually received from the server — HTTP 409
  ///   (duplicate email) as much as any other status — becomes a
  ///   [ServerException] carrying the real status code, letting the
  ///   repository layer decide what each code means rather than
  ///   special-casing 409 here.
  /// - Anything else (e.g. the request was cancelled, or an unexpected
  ///   Dio-internal error with neither a response nor a network-level
  ///   type) is treated as a [NetworkException] fallback: from the
  ///   caller's perspective, no interpretable server response exists
  ///   either way.
  Exception _mapDioException(DioException exception) {
    final isConnectivityIssue =
        exception.type == DioExceptionType.connectionError ||
        exception.type == DioExceptionType.connectionTimeout ||
        exception.type == DioExceptionType.sendTimeout ||
        exception.type == DioExceptionType.receiveTimeout;

    if (isConnectivityIssue) {
      return const NetworkException();
    }

    final response = exception.response;
    if (response != null) {
      return ServerException(
        statusCode: response.statusCode ?? -1,
        message:
            _extractServerMessage(response) ??
            exception.message ??
            'Unknown server error.',
      );
    }

    return const NetworkException();
  }

  /// Extracts the backend's `message` field from a NestJS error response
  /// body, when present and shaped as expected.
  ///
  /// NestJS's default exception filters return `{ statusCode, message,
  /// error }`. This is read defensively: an unexpected or malformed body
  /// falls back to Dio's own [DioException.message] in [_mapDioException]
  /// rather than throwing a second exception while handling the first.
  String? _extractServerMessage(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return null;
  }
}
