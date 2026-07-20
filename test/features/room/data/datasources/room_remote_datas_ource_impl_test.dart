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
}
