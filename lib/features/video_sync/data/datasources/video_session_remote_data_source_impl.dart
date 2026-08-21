import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../models/video_session_metadata_model.dart';
import 'i_video_session_remote_data_source.dart';

/// Dio-based implementation of [IVideoSessionRemoteDataSource].
///
/// Mirrors `RoomRemoteDataSourceImpl` exactly: receives a pre-configured
/// [Dio] instance via constructor injection, maps [DioException] to the
/// same typed exception hierarchy (`ServerException`, `NetworkException`)
/// consumed by [VideoSessionRepositoryImpl].
class VideoSessionRemoteDataSourceImpl
    implements IVideoSessionRemoteDataSource {
  const VideoSessionRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<VideoSessionMetadataModel> getByRoomId({
    required String roomId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/rooms/$roomId/video-session',
      );

      return VideoSessionMetadataModel.fromJson(response.data!);
    } on DioException catch (exception) {
      throw _mapDioException(exception);
    }
  }

  /// Identical mapping strategy to
  /// `RoomRemoteDataSourceImpl._mapDioException` — duplicated here
  /// rather than extracted to a shared utility, consistent with that
  /// class's own precedent of each data source owning its mapper.
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
