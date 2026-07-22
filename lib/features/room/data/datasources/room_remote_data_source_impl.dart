import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../models/room_model.dart';
import 'i_room_remote_data_source.dart';

/// Dio-based implementation of [IRoomRemoteDataSource].
///
/// Mirrors `AuthRemoteDataSourceImpl` exactly: receives a pre-configured
/// [Dio] instance via constructor injection (base URL, timeouts,
/// certificate pinning, and now also the `Authorization` header
/// attachment via the interceptor from `F-INF-T1`/`F-INF-T2`, are the
/// concern of whichever module wires the dependency graph), and maps
/// [DioException] to the same typed exception hierarchy
/// (`ServerException`, `NetworkException`) consumed by
/// [RoomRepositoryImpl].
///
/// Grows one method per task, mirroring [IRoomRemoteDataSource] itself:
/// - `getPublicRooms()`
/// - `createRoom()`,
/// - `updateRoom()`,
/// - `getRoomById()`,
/// - `deleteRoom()`,
/// - `joinRoom()`,
/// - `leaveRoom()`
class RoomRemoteDataSourceImpl implements IRoomRemoteDataSource {
  const RoomRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<RoomModel>> getPublicRooms() async {
    try {
      final response = await _dio.get<List<dynamic>>('/rooms');

      return response.data!
          .map((json) => RoomModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (exception) {
      throw _mapDioException(exception);
    }
  }

  @override
  Future<RoomModel> createRoom({
    required String name,
    required String? description,
    required bool isPublic,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/rooms',
        data: {'name': name, 'description': description, 'isPublic': isPublic},
      );

      return RoomModel.fromJson(response.data!);
    } on DioException catch (exception) {
      throw _mapDioException(exception);
    }
  }

  @override
  Future<RoomModel> updateRoom({
    required String roomId,
    String? name,
    String? description,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/rooms/$roomId',
        // Only the provided fields are included in the body — a `null`
        // parameter here means "leave unchanged" and must be omitted
        // entirely, never sent as JSON `null`. See this method's own
        // doc comment on `IRoomRemoteDataSource` for why sending
        // `"name": null` would actually cause the backend to write
        // `null` into a non-nullable column.
        data: {'name': ?name, 'description': ?description},
      );

      return RoomModel.fromJson(response.data!);
    } on DioException catch (exception) {
      throw _mapDioException(exception);
    }
  }

  @override
  Future<RoomModel> getRoomById({required String roomId}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/rooms/$roomId');

      return RoomModel.fromJson(response.data!);
    } on DioException catch (exception) {
      throw _mapDioException(exception);
    }
  }

  @override
  Future<void> deleteRoom({required String roomId}) async {
    try {
      await _dio.delete<dynamic>('/rooms/$roomId');
    } on DioException catch (exception) {
      throw _mapDioException(exception);
    }
  }

  /// Maps a [DioException] to the typed exception hierarchy consumed by
  /// [RoomRepositoryImpl].
  ///
  /// Identical mapping strategy to
  /// `AuthRemoteDataSourceImpl._mapDioException` — duplicated here
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

  /// Extracts the backend's `message` field from a NestJS error response
  /// body, when present and shaped as expected.
  String? _extractServerMessage(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return null;
  }
}
