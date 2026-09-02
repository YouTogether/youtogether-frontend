import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import 'i_firebase_token_remote_data_source.dart';

/// Dio-based implementation of [IFirebaseTokenRemoteDataSource].
///
/// Mirrors `VideoSessionRemoteDataSourceImpl`: a pre-configured [Dio]
/// instance via constructor injection, and the same [DioException]
/// mapping to `ServerException`/`NetworkException`.
///
/// The injected instance must be the one carrying the authentication
/// interceptor — `POST /auth/firebase-token` is guarded, and a plain
/// client would receive a 401 for every call.
class FirebaseTokenRemoteDataSourceImpl
    implements IFirebaseTokenRemoteDataSource {
  const FirebaseTokenRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<String> fetchCustomToken() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/firebase-token',
      );

      final token = response.data?['firebaseToken'];
      if (token is! String || token.isEmpty) {
        // A 2xx with an unusable body. Reported as a server error
        // rather than returned as an empty string, which would fail far
        // downstream inside the SDK with a message naming nothing.
        throw const ServerException(
          statusCode: 502,
          message: 'The firebase-token response carried no token.',
        );
      }

      return token;
    } on DioException catch (exception) {
      throw _mapDioException(exception);
    }
  }

  /// Identical mapping strategy to
  /// `VideoSessionRemoteDataSourceImpl._mapDioException` — duplicated
  /// per that class's own precedent of each data source owning its
  /// mapper.
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

  String? _extractServerMessage(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return null;
  }
}
