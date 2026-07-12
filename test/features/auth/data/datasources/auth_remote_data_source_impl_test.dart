import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/exceptions.dart';
import 'package:youtogether/features/auth/data/datasources/auth_remote_data_source_impl.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late AuthRemoteDataSourceImpl dataSource;
  late MockDio dio;

  const email = 'test@example.com';
  const password = 'securepassword';
  const username = 'testuser';

  final requestOptions = RequestOptions(path: '/auth/register');

  setUpAll(() {
    registerFallbackValue(requestOptions);
    registerFallbackValue(Options());
  });

  setUp(() {
    dio = MockDio();
    dataSource = AuthRemoteDataSourceImpl(dio);
  });

  Map<String, dynamic> buildSuccessBody() => {
    'user': {
      'id': '550e8400-e29b-41d4-a716-446655440000',
      'email': email,
      'username': username,
      'role': 'registered',
      'createdAt': '2025-01-01T00:00:00.000Z',
    },
    'accessToken': 'mock.access.token',
    'refreshToken': List.filled(64, 'a').join(),
  };

  group('AuthRemoteDataSourceImpl.register', () {
    test(
      'should POST to /auth/register with the correct request body',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
        ).thenAnswer(
          (_) async => Response(
            data: buildSuccessBody(),
            statusCode: 201,
            requestOptions: requestOptions,
          ),
        );

        await dataSource.register(
          email: email,
          password: password,
          username: username,
        );

        verify(
          () => dio.post<Map<String, dynamic>>(
            '/auth/register',
            data: {'email': email, 'password': password, 'username': username},
          ),
        ).called(1);
      },
    );

    test(
      'should return a UserModel parsed from the response body on 201',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
        ).thenAnswer(
          (_) async => Response(
            data: buildSuccessBody(),
            statusCode: 201,
            requestOptions: requestOptions,
          ),
        );

        final result = await dataSource.register(
          email: email,
          password: password,
          username: username,
        );

        expect(result.email, email);
        expect(result.username, username);
        expect(result.role, 'registered');
        expect(result.accessToken, 'mock.access.token');
        expect(result.refreshToken, List.filled(64, 'a').join());
      },
    );

    test(
      'should throw ServerException with statusCode 409 on duplicate email',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
        ).thenThrow(
          DioException(
            requestOptions: requestOptions,
            type: DioExceptionType.badResponse,
            response: Response(
              data: {
                'statusCode': 409,
                'message': 'An active account already exists for this email.',
                'error': 'Conflict',
              },
              statusCode: 409,
              requestOptions: requestOptions,
            ),
          ),
        );

        await expectLater(
          () => dataSource.register(
            email: email,
            password: password,
            username: username,
          ),
          throwsA(
            isA<ServerException>()
                .having((e) => e.statusCode, 'statusCode', 409)
                .having(
                  (e) => e.message,
                  'message',
                  'An active account already exists for this email.',
                ),
          ),
        );
      },
    );

    test('should throw ServerException with the real status code for other '
        'HTTP errors (e.g. 400)', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(
        DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: Response(
            data: {'statusCode': 400, 'message': 'Validation failed.'},
            statusCode: 400,
            requestOptions: requestOptions,
          ),
        ),
      );

      await expectLater(
        () => dataSource.register(
          email: email,
          password: password,
          username: username,
        ),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });

    test('should fall back to the DioException message when the response '
        'body has no readable message field', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(
        DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          message: 'Internal server error',
          response: Response(
            data: 'not a map',
            statusCode: 500,
            requestOptions: requestOptions,
          ),
        ),
      );

      await expectLater(
        () => dataSource.register(
          email: email,
          password: password,
          username: username,
        ),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message', 'Internal server error'),
        ),
      );
    });

    test(
      'should throw NetworkException on DioExceptionType.connectionError',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
        ).thenThrow(
          DioException(
            requestOptions: requestOptions,
            type: DioExceptionType.connectionError,
          ),
        );

        await expectLater(
          () => dataSource.register(
            email: email,
            password: password,
            username: username,
          ),
          throwsA(isA<NetworkException>()),
        );
      },
    );

    test(
      'should throw NetworkException on DioExceptionType.connectionTimeout',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
        ).thenThrow(
          DioException(
            requestOptions: requestOptions,
            type: DioExceptionType.connectionTimeout,
          ),
        );

        await expectLater(
          () => dataSource.register(
            email: email,
            password: password,
            username: username,
          ),
          throwsA(isA<NetworkException>()),
        );
      },
    );

    test(
      'should fall back to NetworkException when a DioException carries '
      'no response and is not a recognised connectivity type (e.g. cancel)',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
        ).thenThrow(
          DioException(
            requestOptions: requestOptions,
            type: DioExceptionType.cancel,
          ),
        );

        await expectLater(
          () => dataSource.register(
            email: email,
            password: password,
            username: username,
          ),
          throwsA(isA<NetworkException>()),
        );
      },
    );
  });

  group('AuthRemoteDataSourceImpl.login', () {
    test('should POST to /auth/login with the correct request body', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => Response(
          data: buildSuccessBody(),
          statusCode: 200,
          requestOptions: requestOptions,
        ),
      );

      await dataSource.login(email: email, password: password);

      verify(
        () => dio.post<Map<String, dynamic>>(
          '/auth/login',
          data: {'email': email, 'password': password},
        ),
      ).called(1);
    });

    test(
      'should return a UserModel parsed from the response body on 200',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
        ).thenAnswer(
          (_) async => Response(
            data: buildSuccessBody(),
            statusCode: 200,
            requestOptions: requestOptions,
          ),
        );

        final result = await dataSource.login(email: email, password: password);

        expect(result.email, email);
        expect(result.accessToken, 'mock.access.token');
      },
    );

    test('should throw ServerException with statusCode 401 on invalid '
        'credentials', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(
        DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: Response(
            data: {'statusCode': 401, 'message': 'Invalid email or password.'},
            statusCode: 401,
            requestOptions: requestOptions,
          ),
        ),
      );

      await expectLater(
        () => dataSource.login(email: email, password: password),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test(
      'should throw NetworkException on DioExceptionType.connectionError',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
        ).thenThrow(
          DioException(
            requestOptions: requestOptions,
            type: DioExceptionType.connectionError,
          ),
        );

        await expectLater(
          () => dataSource.login(email: email, password: password),
          throwsA(isA<NetworkException>()),
        );
      },
    );
  });

  group('AuthRemoteDataSourceImpl.getCurrentUser', () {
    Map<String, dynamic> buildProfileBody() => {
      'id': '550e8400-e29b-41d4-a716-446655440000',
      'email': email,
      'username': username,
      'role': 'registered',
      'createdAt': '2025-01-01T00:00:00.000Z',
    };

    test(
      'should GET /auth/me with the access token as a Bearer header',
      () async {
        when(
          () => dio.get<Map<String, dynamic>>(
            any(),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            data: buildProfileBody(),
            statusCode: 200,
            requestOptions: requestOptions,
          ),
        );

        await dataSource.getCurrentUser(accessToken: 'my-access-token');

        final captured = verify(
          () => dio.get<Map<String, dynamic>>(
            '/auth/me',
            options: captureAny(named: 'options'),
          ),
        ).captured;
        final options = captured.single as Options;
        expect(options.headers?['Authorization'], 'Bearer my-access-token');
      },
    );

    test(
      'should return a UserProfileModel parsed from the response body',
      () async {
        when(
          () => dio.get<Map<String, dynamic>>(
            any(),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            data: buildProfileBody(),
            statusCode: 200,
            requestOptions: requestOptions,
          ),
        );

        final result = await dataSource.getCurrentUser(
          accessToken: 'my-access-token',
        );

        expect(result.email, email);
        expect(result.username, username);
      },
    );

    test('should throw ServerException with statusCode 401 on an invalid '
        'or expired token', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: Response(
            data: {'statusCode': 401, 'message': 'Invalid or expired session.'},
            statusCode: 401,
            requestOptions: requestOptions,
          ),
        ),
      );

      await expectLater(
        () => dataSource.getCurrentUser(accessToken: 'invalid-token'),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test(
      'should throw NetworkException on DioExceptionType.connectionError',
      () async {
        when(
          () => dio.get<Map<String, dynamic>>(
            any(),
            options: any(named: 'options'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: requestOptions,
            type: DioExceptionType.connectionError,
          ),
        );

        await expectLater(
          () => dataSource.getCurrentUser(accessToken: 'my-access-token'),
          throwsA(isA<NetworkException>()),
        );
      },
    );
  });

  group('AuthRemoteDataSourceImpl.refreshToken', () {
    test(
      'should POST to /auth/refresh with the refresh token in the body',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
        ).thenAnswer(
          (_) async => Response(
            data: buildSuccessBody(),
            statusCode: 200,
            requestOptions: requestOptions,
          ),
        );

        await dataSource.refreshToken(refreshToken: 'cached-refresh-token');

        verify(
          () => dio.post<Map<String, dynamic>>(
            '/auth/refresh',
            data: {'refreshToken': 'cached-refresh-token'},
          ),
        ).called(1);
      },
    );

    test(
      'should return a UserModel with the rotated tokens on success',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
        ).thenAnswer(
          (_) async => Response(
            data: buildSuccessBody(),
            statusCode: 200,
            requestOptions: requestOptions,
          ),
        );

        final result = await dataSource.refreshToken(
          refreshToken: 'cached-refresh-token',
        );

        expect(result.accessToken, 'mock.access.token');
        expect(result.refreshToken, List.filled(64, 'a').join());
      },
    );

    test('should throw ServerException with statusCode 401 on an invalid, '
        'expired, or replayed refresh token', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(
        DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: Response(
            data: {
              'statusCode': 401,
              'message': 'Invalid or expired refresh token.',
            },
            statusCode: 401,
            requestOptions: requestOptions,
          ),
        ),
      );

      await expectLater(
        () => dataSource.refreshToken(refreshToken: 'stale-token'),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test(
      'should throw NetworkException on DioExceptionType.connectionError',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
        ).thenThrow(
          DioException(
            requestOptions: requestOptions,
            type: DioExceptionType.connectionError,
          ),
        );

        await expectLater(
          () => dataSource.refreshToken(refreshToken: 'cached-refresh-token'),
          throwsA(isA<NetworkException>()),
        );
      },
    );
  });
}
