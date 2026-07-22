import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/exceptions.dart';
import 'package:youtogether/features/room/data/datasources/room_remote_data_source_impl.dart';

class MockDio extends Mock implements Dio {}

/// Unit tests for [RoomRemoteDataSourceImpl.getPublicRooms].
///
/// Mirrors `auth_remote_data_source_impl_test.dart`: a mocked [Dio]
/// instance, verifying both the outgoing request shape and the
/// [DioException]-to-typed-exception mapping.
///
/// @competency Unit test harness, TDD cycle.
void main() {
  late MockDio dio;
  late RoomRemoteDataSourceImpl dataSource;

  final requestOptions = RequestOptions(path: '/rooms');

  List<Map<String, dynamic>> buildSuccessBody() => [
    {
      'id': '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f',
      'name': 'Friday Movie Night',
      'description': 'Weekly watch party',
      'ownerId': '550e8400-e29b-41d4-a716-446655440000',
      'isPublic': true,
      'memberCount': 3,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-01T00:00:00.000Z',
    },
  ];

  setUp(() {
    dio = MockDio();
    dataSource = RoomRemoteDataSourceImpl(dio);
  });

  group('RoomRemoteDataSourceImpl.getPublicRooms', () {
    test('should GET /rooms with no query parameters', () async {
      when(() => dio.get<List<dynamic>>(any())).thenAnswer(
        (_) async => Response(
          data: buildSuccessBody(),
          statusCode: 200,
          requestOptions: requestOptions,
        ),
      );

      await dataSource.getPublicRooms();

      verify(() => dio.get<List<dynamic>>('/rooms')).called(1);
    });

    test(
      'should return a list of RoomModel parsed from the response body on 200',
      () async {
        when(() => dio.get<List<dynamic>>(any())).thenAnswer(
          (_) async => Response(
            data: buildSuccessBody(),
            statusCode: 200,
            requestOptions: requestOptions,
          ),
        );

        final result = await dataSource.getPublicRooms();

        expect(result, hasLength(1));
        expect(result.first.name, 'Friday Movie Night');
        expect(result.first.memberCount, 3);
      },
    );

    test('should return an empty list when the server returns none', () async {
      when(() => dio.get<List<dynamic>>(any())).thenAnswer(
        (_) async => Response(
          data: <Map<String, dynamic>>[],
          statusCode: 200,
          requestOptions: requestOptions,
        ),
      );

      final result = await dataSource.getPublicRooms();

      expect(result, isEmpty);
    });

    test(
      'should throw NetworkException on DioExceptionType.connectionError',
      () async {
        when(() => dio.get<List<dynamic>>(any())).thenThrow(
          DioException(
            requestOptions: requestOptions,
            type: DioExceptionType.connectionError,
          ),
        );

        await expectLater(
          () => dataSource.getPublicRooms(),
          throwsA(isA<NetworkException>()),
        );
      },
    );

    test('should throw ServerException with the response status code on a '
        'server error', () async {
      when(() => dio.get<List<dynamic>>(any())).thenThrow(
        DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: Response(
            data: {'statusCode': 500, 'message': 'Internal server error'},
            statusCode: 500,
            requestOptions: requestOptions,
          ),
        ),
      );

      await expectLater(
        () => dataSource.getPublicRooms(),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });
  });

  group('RoomRemoteDataSourceImpl.createRoom', () {
    final createRequestOptions = RequestOptions(path: '/rooms');

    Map<String, dynamic> buildCreateSuccessBody() => {
      'id': '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f',
      'name': 'Friday Movie Night',
      'description': 'Weekly watch party',
      'ownerId': '550e8400-e29b-41d4-a716-446655440000',
      'isPublic': true,
      'memberCount': 1,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-01T00:00:00.000Z',
    };

    test('should POST to /rooms with the correct request body', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => Response(
          data: buildCreateSuccessBody(),
          statusCode: 201,
          requestOptions: createRequestOptions,
        ),
      );

      await dataSource.createRoom(
        name: 'Friday Movie Night',
        description: 'Weekly watch party',
        isPublic: true,
      );

      verify(
        () => dio.post<Map<String, dynamic>>(
          '/rooms',
          data: {
            'name': 'Friday Movie Night',
            'description': 'Weekly watch party',
            'isPublic': true,
          },
        ),
      ).called(1);
    });

    test(
      'should send a null description unchanged in the request body',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
        ).thenAnswer(
          (_) async => Response(
            data: buildCreateSuccessBody(),
            statusCode: 201,
            requestOptions: createRequestOptions,
          ),
        );

        await dataSource.createRoom(
          name: 'Friday Movie Night',
          description: null,
          isPublic: true,
        );

        verify(
          () => dio.post<Map<String, dynamic>>(
            '/rooms',
            data: {
              'name': 'Friday Movie Night',
              'description': null,
              'isPublic': true,
            },
          ),
        ).called(1);
      },
    );

    test(
      'should return a RoomModel parsed from the response body on 201',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
        ).thenAnswer(
          (_) async => Response(
            data: buildCreateSuccessBody(),
            statusCode: 201,
            requestOptions: createRequestOptions,
          ),
        );

        final result = await dataSource.createRoom(
          name: 'Friday Movie Night',
          description: 'Weekly watch party',
          isPublic: true,
        );

        expect(result.name, 'Friday Movie Night');
        expect(result.memberCount, 1);
      },
    );

    test(
      'should throw ServerException with statusCode 400 on invalid input',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
        ).thenThrow(
          DioException(
            requestOptions: createRequestOptions,
            type: DioExceptionType.badResponse,
            response: Response(
              data: {
                'statusCode': 400,
                'message': ['name must not exceed 100 characters'],
              },
              statusCode: 400,
              requestOptions: createRequestOptions,
            ),
          ),
        );

        await expectLater(
          () => dataSource.createRoom(
            name: List.filled(101, 'a').join(),
            description: null,
            isPublic: true,
          ),
          throwsA(
            isA<ServerException>().having(
              (e) => e.statusCode,
              'statusCode',
              400,
            ),
          ),
        );
      },
    );

    test(
      'should throw NetworkException on DioExceptionType.connectionError',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
        ).thenThrow(
          DioException(
            requestOptions: createRequestOptions,
            type: DioExceptionType.connectionError,
          ),
        );

        await expectLater(
          () => dataSource.createRoom(
            name: 'Friday Movie Night',
            description: null,
            isPublic: true,
          ),
          throwsA(isA<NetworkException>()),
        );
      },
    );
  });

  group('RoomRemoteDataSourceImpl.updateRoom', () {
    const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';
    final updateRequestOptions = RequestOptions(path: '/rooms/$roomId');

    Map<String, dynamic> buildUpdateSuccessBody() => {
      'id': roomId,
      'name': 'Renamed Movie Night',
      'description': 'Updated description',
      'ownerId': '550e8400-e29b-41d4-a716-446655440000',
      'isPublic': true,
      'memberCount': 2,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-05T00:00:00.000Z',
    };

    test(
      'should PATCH /rooms/:id with both fields when both are provided',
      () async {
        when(
          () =>
              dio.patch<Map<String, dynamic>>(any(), data: any(named: 'data')),
        ).thenAnswer(
          (_) async => Response(
            data: buildUpdateSuccessBody(),
            statusCode: 200,
            requestOptions: updateRequestOptions,
          ),
        );

        await dataSource.updateRoom(
          roomId: roomId,
          name: 'Renamed Movie Night',
          description: 'Updated description',
        );

        verify(
          () => dio.patch<Map<String, dynamic>>(
            '/rooms/$roomId',
            data: {
              'name': 'Renamed Movie Night',
              'description': 'Updated description',
            },
          ),
        ).called(1);
      },
    );

    test('should omit a null field from the request body entirely (partial '
        'update — a null key would mean "clear it" server-side, not "leave '
        'unchanged")', () async {
      when(
        () => dio.patch<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => Response(
          data: buildUpdateSuccessBody(),
          statusCode: 200,
          requestOptions: updateRequestOptions,
        ),
      );

      await dataSource.updateRoom(
        roomId: roomId,
        description: 'Only description changes',
      );

      final capturedData =
          verify(
                () => dio.patch<Map<String, dynamic>>(
                  '/rooms/$roomId',
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;

      expect(capturedData.containsKey('name'), isFalse);
      expect(capturedData['description'], 'Only description changes');
    });

    test(
      'should return a RoomModel parsed from the response body on 200',
      () async {
        when(
          () =>
              dio.patch<Map<String, dynamic>>(any(), data: any(named: 'data')),
        ).thenAnswer(
          (_) async => Response(
            data: buildUpdateSuccessBody(),
            statusCode: 200,
            requestOptions: updateRequestOptions,
          ),
        );

        final result = await dataSource.updateRoom(
          roomId: roomId,
          name: 'Renamed Movie Night',
        );

        expect(result.name, 'Renamed Movie Night');
        expect(result.memberCount, 2);
      },
    );

    test(
      'should throw ServerException with statusCode 403 for a non-owner',
      () async {
        when(
          () =>
              dio.patch<Map<String, dynamic>>(any(), data: any(named: 'data')),
        ).thenThrow(
          DioException(
            requestOptions: updateRequestOptions,
            type: DioExceptionType.badResponse,
            response: Response(
              data: {
                'statusCode': 403,
                'message':
                    'Only the owner of this room may perform this action.',
              },
              statusCode: 403,
              requestOptions: updateRequestOptions,
            ),
          ),
        );

        await expectLater(
          () => dataSource.updateRoom(roomId: roomId, name: 'Hijacked Name'),
          throwsA(
            isA<ServerException>().having(
              (e) => e.statusCode,
              'statusCode',
              403,
            ),
          ),
        );
      },
    );

    test(
      'should throw ServerException with statusCode 404 for a missing room',
      () async {
        when(
          () =>
              dio.patch<Map<String, dynamic>>(any(), data: any(named: 'data')),
        ).thenThrow(
          DioException(
            requestOptions: updateRequestOptions,
            type: DioExceptionType.badResponse,
            response: Response(
              data: {'statusCode': 404, 'message': 'Room not found.'},
              statusCode: 404,
              requestOptions: updateRequestOptions,
            ),
          ),
        );

        await expectLater(
          () => dataSource.updateRoom(roomId: roomId, name: 'Does Not Matter'),
          throwsA(
            isA<ServerException>().having(
              (e) => e.statusCode,
              'statusCode',
              404,
            ),
          ),
        );
      },
    );

    test(
      'should throw NetworkException on DioExceptionType.connectionError',
      () async {
        when(
          () =>
              dio.patch<Map<String, dynamic>>(any(), data: any(named: 'data')),
        ).thenThrow(
          DioException(
            requestOptions: updateRequestOptions,
            type: DioExceptionType.connectionError,
          ),
        );

        await expectLater(
          () => dataSource.updateRoom(roomId: roomId, name: 'New Name'),
          throwsA(isA<NetworkException>()),
        );
      },
    );
  });

  group('RoomRemoteDataSourceImpl.getRoomById', () {
    const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';
    final detailRequestOptions = RequestOptions(path: '/rooms/$roomId');

    Map<String, dynamic> buildDetailSuccessBody() => {
      'id': roomId,
      'name': 'Friday Movie Night',
      'description': 'Weekly watch party',
      'ownerId': '550e8400-e29b-41d4-a716-446655440000',
      'isPublic': true,
      'memberCount': 2,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-01T00:00:00.000Z',
    };

    test('should GET /rooms/:id with the correct room id', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => Response(
          data: buildDetailSuccessBody(),
          statusCode: 200,
          requestOptions: detailRequestOptions,
        ),
      );

      await dataSource.getRoomById(roomId: roomId);

      verify(() => dio.get<Map<String, dynamic>>('/rooms/$roomId')).called(1);
    });

    test(
      'should return a RoomModel parsed from the response body on 200',
      () async {
        when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
          (_) async => Response(
            data: buildDetailSuccessBody(),
            statusCode: 200,
            requestOptions: detailRequestOptions,
          ),
        );

        final result = await dataSource.getRoomById(roomId: roomId);

        expect(result.name, 'Friday Movie Night');
        expect(result.memberCount, 2);
      },
    );

    test('should throw ServerException with statusCode 404 for a missing or '
        'deleted room', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          requestOptions: detailRequestOptions,
          type: DioExceptionType.badResponse,
          response: Response(
            data: {'statusCode': 404, 'message': 'Room not found.'},
            statusCode: 404,
            requestOptions: detailRequestOptions,
          ),
        ),
      );

      await expectLater(
        () => dataSource.getRoomById(roomId: roomId),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });

    test(
      'should throw NetworkException on DioExceptionType.connectionError',
      () async {
        when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(
          DioException(
            requestOptions: detailRequestOptions,
            type: DioExceptionType.connectionError,
          ),
        );

        await expectLater(
          () => dataSource.getRoomById(roomId: roomId),
          throwsA(isA<NetworkException>()),
        );
      },
    );
  });

  group('RoomRemoteDataSourceImpl.deleteRoom', () {
    const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';
    final deleteRequestOptions = RequestOptions(path: '/rooms/$roomId');

    test('should DELETE /rooms/:id with the correct room id', () async {
      when(() => dio.delete<dynamic>(any())).thenAnswer(
        (_) async => Response(
          data: null,
          statusCode: 200,
          requestOptions: deleteRequestOptions,
        ),
      );

      await dataSource.deleteRoom(roomId: roomId);

      verify(() => dio.delete<dynamic>('/rooms/$roomId')).called(1);
    });

    test(
      'should throw ServerException with statusCode 403 for a non-owner',
      () async {
        when(() => dio.delete<dynamic>(any())).thenThrow(
          DioException(
            requestOptions: deleteRequestOptions,
            type: DioExceptionType.badResponse,
            response: Response(
              data: {
                'statusCode': 403,
                'message':
                    'Only the owner of this room may perform this action.',
              },
              statusCode: 403,
              requestOptions: deleteRequestOptions,
            ),
          ),
        );

        await expectLater(
          () => dataSource.deleteRoom(roomId: roomId),
          throwsA(
            isA<ServerException>().having(
              (e) => e.statusCode,
              'statusCode',
              403,
            ),
          ),
        );
      },
    );

    test('should throw ServerException with statusCode 404 for a missing or '
        'already-deleted room', () async {
      when(() => dio.delete<dynamic>(any())).thenThrow(
        DioException(
          requestOptions: deleteRequestOptions,
          type: DioExceptionType.badResponse,
          response: Response(
            data: {'statusCode': 404, 'message': 'Room not found.'},
            statusCode: 404,
            requestOptions: deleteRequestOptions,
          ),
        ),
      );

      await expectLater(
        () => dataSource.deleteRoom(roomId: roomId),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });

    test(
      'should throw NetworkException on DioExceptionType.connectionError',
      () async {
        when(() => dio.delete<dynamic>(any())).thenThrow(
          DioException(
            requestOptions: deleteRequestOptions,
            type: DioExceptionType.connectionError,
          ),
        );

        await expectLater(
          () => dataSource.deleteRoom(roomId: roomId),
          throwsA(isA<NetworkException>()),
        );
      },
    );
  });
}
