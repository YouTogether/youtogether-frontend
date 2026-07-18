import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/core/network/auth_interceptor.dart';
import 'package:youtogether/core/usecases/usecase.dart';
import 'package:youtogether/features/auth/data/datasources/i_auth_local_data_source.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';
import 'package:youtogether/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:youtogether/features/auth/domain/usecases/logout_usecase.dart';
import 'package:youtogether/features/auth/domain/usecases/refresh_token_usecase.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_bloc.dart';

class MockAuthLocalDataSource extends Mock implements IAuthLocalDataSource {}

class MockGetCurrentUserUseCase extends Mock implements GetCurrentUserUseCase {}

class MockRefreshTokenUseCase extends Mock implements RefreshTokenUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDio extends Mock implements Dio {}

/// Unit tests for [AuthInterceptor] (F-INF-T1, gap 5 of ADR-001).
///
/// A real [AuthBloc] is used (with mocked use cases), rather than a
/// mocked Bloc, so its actual `stream`/`add` behaviour drives the
/// interceptor's await-for-resolution logic exactly as it would in the
/// running app — mirroring how `auth_bloc_test.dart` itself is
/// structured.
///
/// The refresh-decision and retry-construction logic is exercised via
/// `@visibleForTesting` seams (`shouldAttemptRefresh`, `refreshSession`,
/// `buildRetryOptions`) rather than by driving Dio's own
/// `RequestInterceptorHandler`/`ErrorInterceptorHandler` completion
/// machinery directly — coupling tests to that internal API would make
/// them fragile across Dio versions for no added confidence in this
/// class's own logic.
///
/// @competency Unit test harness, TDD cycle.
/// @competency OWASP A07 (auto-refresh on 401).
void main() {
  late MockAuthLocalDataSource localDataSource;
  late MockGetCurrentUserUseCase getCurrentUserUseCase;
  late MockRefreshTokenUseCase refreshTokenUseCase;
  late MockLogoutUseCase logoutUseCase;
  late AuthBloc authBloc;
  late MockDio dio;
  late AuthInterceptor interceptor;

  final mockUser = UserEntity(
    id: '550e8400-e29b-41d4-a716-446655440000',
    email: 'test@example.com',
    displayName: 'testuser',
    role: UserRole.registered,
    createdAt: DateTime.utc(2025, 1, 1),
  );

  setUp(() {
    localDataSource = MockAuthLocalDataSource();
    getCurrentUserUseCase = MockGetCurrentUserUseCase();
    refreshTokenUseCase = MockRefreshTokenUseCase();
    logoutUseCase = MockLogoutUseCase();
    authBloc = AuthBloc(
      getCurrentUserUseCase: getCurrentUserUseCase,
      refreshTokenUseCase: refreshTokenUseCase,
      logoutUseCase: logoutUseCase,
    );
    dio = MockDio();
    interceptor = AuthInterceptor(
      localDataSource: localDataSource,
      authBloc: authBloc,
      dio: dio,
    );
  });

  tearDown(() {
    authBloc.close();
  });

  RequestOptions buildRequestOptions({
    String path = '/rooms',
    Map<String, dynamic>? extra,
  }) => RequestOptions(path: path, extra: extra ?? {});

  DioException build401({required String path, Map<String, dynamic>? extra}) {
    final requestOptions = buildRequestOptions(path: path, extra: extra);
    return DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.badResponse,
      response: Response(statusCode: 401, requestOptions: requestOptions),
    );
  }

  group('shouldAttemptRefresh', () {
    test('returns true for a 401 on a non-exempt, non-retried request', () {
      final exception = build401(path: '/rooms');

      expect(interceptor.shouldAttemptRefresh(exception), isTrue);
    });

    test('returns false for a non-401 status code', () {
      final requestOptions = buildRequestOptions();
      final exception = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response(statusCode: 500, requestOptions: requestOptions),
      );

      expect(interceptor.shouldAttemptRefresh(exception), isFalse);
    });

    test(
      'returns false for a 401 on /auth/refresh (avoids a refresh loop)',
      () {
        final exception = build401(path: '/auth/refresh');

        expect(interceptor.shouldAttemptRefresh(exception), isFalse);
      },
    );

    test('returns false for a 401 on /auth/login (invalid credentials, '
        'not an expired session)', () {
      final exception = build401(path: '/auth/login');

      expect(interceptor.shouldAttemptRefresh(exception), isFalse);
    });

    test('returns false for a 401 on /auth/register', () {
      final exception = build401(path: '/auth/register');

      expect(interceptor.shouldAttemptRefresh(exception), isFalse);
    });

    test('returns false when the request has already been retried once '
        '(prevents an infinite retry loop)', () {
      final exception = build401(
        path: '/rooms',
        extra: {AuthInterceptor.retriedFlag: true},
      );

      expect(interceptor.shouldAttemptRefresh(exception), isFalse);
    });
  });

  group('refreshSession', () {
    test('dispatches AuthEvent.tokenRefreshRequested exactly once', () async {
      when(
        () => refreshTokenUseCase(const NoParams()),
      ).thenAnswer((_) async => Right(mockUser));

      await interceptor.refreshSession();

      verify(() => refreshTokenUseCase(const NoParams())).called(1);
    });

    test('returns the refreshed user on success', () async {
      when(
        () => refreshTokenUseCase(const NoParams()),
      ).thenAnswer((_) async => Right(mockUser));

      final result = await interceptor.refreshSession();

      expect(result, mockUser);
    });

    test('returns null when the refresh fails', () async {
      when(() => refreshTokenUseCase(const NoParams())).thenAnswer(
        (_) async => const Left(
          Failure.auth(message: 'Invalid or expired refresh token.'),
        ),
      );

      final result = await interceptor.refreshSession();

      expect(result, isNull);
    });

    test(
      'deduplicates concurrent calls into a single dispatched event',
      () async {
        when(() => refreshTokenUseCase(const NoParams())).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return Right(mockUser);
        });

        final results = await Future.wait([
          interceptor.refreshSession(),
          interceptor.refreshSession(),
          interceptor.refreshSession(),
        ]);

        expect(results, everyElement(mockUser));
        verify(() => refreshTokenUseCase(const NoParams())).called(1);
      },
    );
  });

  group('buildRetryOptions', () {
    test(
      'attaches the freshly cached access token as a Bearer header',
      () async {
        when(
          () => localDataSource.getAccessToken(),
        ).thenAnswer((_) async => 'new-access-token');

        final options = await interceptor.buildRetryOptions(
          buildRequestOptions(path: '/rooms'),
        );

        expect(options.headers['Authorization'], 'Bearer new-access-token');
      },
    );

    test('marks the retried request via the retried flag (prevents a '
        'second refresh attempt on repeated failure)', () async {
      when(
        () => localDataSource.getAccessToken(),
      ).thenAnswer((_) async => 'new-access-token');

      final options = await interceptor.buildRetryOptions(
        buildRequestOptions(path: '/rooms'),
      );

      expect(options.extra[AuthInterceptor.retriedFlag], isTrue);
    });
  });
}
