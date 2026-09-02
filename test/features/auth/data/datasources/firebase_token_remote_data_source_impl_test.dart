import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/core/error/exceptions.dart';
import 'package:youtogether/features/auth/data/datasources/firebase_token_remote_data_source_impl.dart';

class MockDio extends Mock implements Dio {}

/// Unit tests for [FirebaseTokenRemoteDataSourceImpl].
///
/// Mirrors `video_session_remote_data_source_impl_test.dart`.
///
/// The "no request body" assertion is the deliberate one. The backend
/// derives the token's `uid` from the bearer token and re-checks the
/// account before minting; sending a user id from here would be the
/// access-control mistake that endpoint exists to avoid, and the
/// backend's ValidationPipe would strip it silently, so only a
/// client-side assertion can catch a regression.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios A-FBS-05, A-FBS-07.
void main() {
  late MockDio dio;
  late FirebaseTokenRemoteDataSourceImpl dataSource;

  final requestOptions = RequestOptions(path: '/auth/firebase-token');

  setUp(() {
    dio = MockDio();
    dataSource = FirebaseTokenRemoteDataSourceImpl(dio);
  });

  Response<Map<String, dynamic>> buildResponse(
    Map<String, dynamic>? data, {
    int statusCode = 201,
  }) {
    return Response<Map<String, dynamic>>(
      data: data,
      statusCode: statusCode,
      requestOptions: requestOptions,
    );
  }

  test('should POST to /auth/firebase-token with no body', () async {
    when(
      () => dio.post<Map<String, dynamic>>(any()),
    ).thenAnswer((_) async => buildResponse({'firebaseToken': 'a.b.c'}));

    await dataSource.fetchCustomToken();

    verify(
      () => dio.post<Map<String, dynamic>>('/auth/firebase-token'),
    ).called(1);
  });

  test('should return the token carried by the response body', () async {
    when(
      () => dio.post<Map<String, dynamic>>(any()),
    ).thenAnswer((_) async => buildResponse({'firebaseToken': 'a.b.c'}));

    final result = await dataSource.fetchCustomToken();

    expect(result, 'a.b.c');
  });

  test('should throw ServerException when a 2xx carries no token', () async {
    when(
      () => dio.post<Map<String, dynamic>>(any()),
    ).thenAnswer((_) async => buildResponse({}));

    expect(
      () => dataSource.fetchCustomToken(),
      throwsA(isA<ServerException>()),
    );
  });

  test(
    'should throw ServerException when the token is an empty string',
    () async {
      when(
        () => dio.post<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => buildResponse({'firebaseToken': ''}));

      expect(
        () => dataSource.fetchCustomToken(),
        throwsA(isA<ServerException>()),
      );
    },
  );

  test('should throw ServerException with statusCode 401 when the session is '
      'gone (A-FBS-07)', () async {
    when(() => dio.post<Map<String, dynamic>>(any())).thenThrow(
      DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          data: {'statusCode': 401, 'message': 'Unauthorized'},
          statusCode: 401,
          requestOptions: requestOptions,
        ),
      ),
    );

    expect(
      () => dataSource.fetchCustomToken(),
      throwsA(
        isA<ServerException>().having(
          (exception) => exception.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
  });

  test('should throw ServerException with statusCode 502 when Firebase could '
      'not sign the token (A-FBS-05)', () async {
    when(() => dio.post<Map<String, dynamic>>(any())).thenThrow(
      DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          data: {
            'statusCode': 502,
            'message': 'A Firebase custom token could not be issued.',
          },
          statusCode: 502,
          requestOptions: requestOptions,
        ),
      ),
    );

    expect(
      () => dataSource.fetchCustomToken(),
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
    when(() => dio.post<Map<String, dynamic>>(any())).thenThrow(
      DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.connectionError,
      ),
    );

    expect(
      () => dataSource.fetchCustomToken(),
      throwsA(isA<NetworkException>()),
    );
  });
}
