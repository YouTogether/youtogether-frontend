import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/core/error/exceptions.dart';
import 'package:youtogether/features/video_sync/data/datasources/video_session_remote_data_source_impl.dart';

class MockDio extends Mock implements Dio {}

/// Unit tests for [VideoSessionRemoteDataSourceImpl.getByRoomId].
///
/// Mirrors `room_remote_data_source_impl_test.dart`'s `getRoomById`
/// suite: a mocked [Dio] instance, verifying the outgoing request shape
/// and the [DioException]-to-typed-exception mapping.
///
/// @competency Unit test harness, TDD cycle.
void main() {
  late MockDio dio;
  late VideoSessionRemoteDataSourceImpl dataSource;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';
  final requestOptions = RequestOptions(path: '/rooms/$roomId/video-session');

  Map<String, dynamic> buildSuccessBody() => {
    'id': 'session-uuid',
    'roomId': roomId,
    'youtubeVideoId': 'dQw4w9WgXcQ',
    'title': 'Never Gonna Give You Up',
    'thumbnailUrl': 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
    'durationSeconds': 213,
    'addedBy': '550e8400-e29b-41d4-a716-446655440000',
    'createdAt': '2026-01-05T00:00:00.000Z',
  };

  setUp(() {
    dio = MockDio();
    dataSource = VideoSessionRemoteDataSourceImpl(dio);
  });

  test(
    'should GET /rooms/:id/video-session with the correct room id',
    () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => Response(
          data: buildSuccessBody(),
          statusCode: 200,
          requestOptions: requestOptions,
        ),
      );

      await dataSource.getByRoomId(roomId: roomId);

      verify(
        () => dio.get<Map<String, dynamic>>('/rooms/$roomId/video-session'),
      ).called(1);
    },
  );

  test(
    'should return a VideoSessionMetadataModel parsed from the response body on 200',
    () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => Response(
          data: buildSuccessBody(),
          statusCode: 200,
          requestOptions: requestOptions,
        ),
      );

      final result = await dataSource.getByRoomId(roomId: roomId);

      expect(result.durationSeconds, 213);
      expect(result.youtubeVideoId, 'dQw4w9WgXcQ');
    },
  );

  test(
    'should throw ServerException with statusCode 404 when the room or session is missing',
    () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: Response(
            data: {
              'statusCode': 404,
              'message': 'Room "x" has no video session.',
            },
            statusCode: 404,
            requestOptions: requestOptions,
          ),
        ),
      );

      await expectLater(
        () => dataSource.getByRoomId(roomId: roomId),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    },
  );

  test(
    'should throw NetworkException on DioExceptionType.connectionError',
    () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        () => dataSource.getByRoomId(roomId: roomId),
        throwsA(isA<NetworkException>()),
      );
    },
  );

  group('VideoSessionRemoteDataSourceImpl.create', () {
    setUp(() {
      registerFallbackValue(<String, dynamic>{});
    });

    test('should POST /rooms/:id/video-session with the video id as the '
        'only body field', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => Response(
          data: buildSuccessBody(),
          statusCode: 201,
          requestOptions: requestOptions,
        ),
      );

      await dataSource.create(roomId: roomId, youtubeVideoId: 'dQw4w9WgXcQ');

      // The body is asserted exhaustively rather than with
      // `containsPair`: sending an `addedBy` or `leaderId` field would
      // be an access-control mistake, and the backend's ValidationPipe
      // silently strips extras, so only a client-side assertion can
      // catch it.
      verify(
        () => dio.post<Map<String, dynamic>>(
          '/rooms/$roomId/video-session',
          data: {'youtubeVideoId': 'dQw4w9WgXcQ'},
        ),
      ).called(1);
    });

    test('should return a VideoSessionMetadataModel parsed from the '
        'response body on 201', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => Response(
          data: buildSuccessBody(),
          statusCode: 201,
          requestOptions: requestOptions,
        ),
      );

      final result = await dataSource.create(
        roomId: roomId,
        youtubeVideoId: 'dQw4w9WgXcQ',
      );

      expect(result.durationSeconds, 213);
      expect(result.youtubeVideoId, 'dQw4w9WgXcQ');
    });

    test('should throw ServerException with statusCode 400 when the backend '
        'rejects the video id', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(
        DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: Response(
            data: {
              'statusCode': 400,
              'message': 'YouTube video "zzzzzzzzzzz" was not found.',
            },
            statusCode: 400,
            requestOptions: requestOptions,
          ),
        ),
      );

      expect(
        () => dataSource.create(roomId: roomId, youtubeVideoId: 'zzzzzzzzzzz'),
        throwsA(
          isA<ServerException>().having(
            (exception) => exception.statusCode,
            'statusCode',
            400,
          ),
        ),
      );
    });

    test(
      'should throw ServerException with statusCode 403 for a non-owner',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
        ).thenThrow(
          DioException(
            requestOptions: requestOptions,
            type: DioExceptionType.badResponse,
            response: Response(
              data: {'statusCode': 403, 'message': 'Forbidden resource'},
              statusCode: 403,
              requestOptions: requestOptions,
            ),
          ),
        );

        expect(
          () =>
              dataSource.create(roomId: roomId, youtubeVideoId: 'dQw4w9WgXcQ'),
          throwsA(
            isA<ServerException>().having(
              (exception) => exception.statusCode,
              'statusCode',
              403,
            ),
          ),
        );
      },
    );

    test('should throw ServerException with statusCode 502 when the realtime '
        'state could not be written', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(
        DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: Response(
            data: {
              'statusCode': 502,
              'message':
                  'The realtime playback state could not be initialised: '
                  'permission_denied',
            },
            statusCode: 502,
            requestOptions: requestOptions,
          ),
        ),
      );

      expect(
        () => dataSource.create(roomId: roomId, youtubeVideoId: 'dQw4w9WgXcQ'),
        throwsA(
          isA<ServerException>().having(
            (exception) => exception.statusCode,
            'statusCode',
            502,
          ),
        ),
      );
    });

    test('should throw NetworkException on a connection error', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(
        DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionError,
        ),
      );

      expect(
        () => dataSource.create(roomId: roomId, youtubeVideoId: 'dQw4w9WgXcQ'),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
