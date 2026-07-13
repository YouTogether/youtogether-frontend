import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/exceptions.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/auth/data/datasources/i_auth_local_data_source.dart';
import 'package:youtogether/features/auth/data/datasources/i_auth_remote_data_source.dart';
import 'package:youtogether/features/auth/data/models/user_model.dart';
import 'package:youtogether/features/auth/data/models/user_profile_model.dart';
import 'package:youtogether/features/auth/data/repositories/auth_repository_impl.dart';

class MockAuthRemoteDataSource extends Mock implements IAuthRemoteDataSource {}

class MockAuthLocalDataSource extends Mock implements IAuthLocalDataSource {}

void main() {
  late AuthRepositoryImpl authRepository;
  late MockAuthRemoteDataSource remoteDataSource;
  late MockAuthLocalDataSource localDataSource;

  const email = 'test@example.com';
  const password = 'securepassword';
  const username = 'testuser';

  final userModel = UserModel(
    id: '550e8400-e29b-41d4-a716-446655440000',
    email: email,
    username: username,
    role: 'registered',
    createdAt: DateTime.utc(2025, 1, 1),
    accessToken: 'mock.access.token',
    refreshToken: List.filled(64, 'a').join(),
  );

  setUp(() {
    remoteDataSource = MockAuthRemoteDataSource();
    localDataSource = MockAuthLocalDataSource();
    authRepository = AuthRepositoryImpl(
      remoteDataSource: remoteDataSource,
      localDataSource: localDataSource,
    );
  });

  group('AuthRepositoryImpl.register', () {
    test(
      'should call IAuthRemoteDataSource.register with the given fields',
      () async {
        when(
          () => remoteDataSource.register(
            email: any(named: 'email'),
            password: any(named: 'password'),
            username: any(named: 'username'),
          ),
        ).thenAnswer((_) async => userModel);
        when(
          () => localDataSource.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          ),
        ).thenAnswer((_) async {});

        await authRepository.register(
          email: email,
          password: password,
          username: username,
        );

        verify(
          () => remoteDataSource.register(
            email: email,
            password: password,
            username: username,
          ),
        ).called(1);
      },
    );

    test(
      'should persist the returned tokens via IAuthLocalDataSource.saveTokens',
      () async {
        when(
          () => remoteDataSource.register(
            email: any(named: 'email'),
            password: any(named: 'password'),
            username: any(named: 'username'),
          ),
        ).thenAnswer((_) async => userModel);
        when(
          () => localDataSource.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          ),
        ).thenAnswer((_) async {});

        await authRepository.register(
          email: email,
          password: password,
          username: username,
        );

        verify(
          () => localDataSource.saveTokens(
            accessToken: userModel.accessToken,
            refreshToken: userModel.refreshToken,
          ),
        ).called(1);
      },
    );

    test(
      'should return Right(UserEntity) mapped from the UserModel on success',
      () async {
        when(
          () => remoteDataSource.register(
            email: any(named: 'email'),
            password: any(named: 'password'),
            username: any(named: 'username'),
          ),
        ).thenAnswer((_) async => userModel);
        when(
          () => localDataSource.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          ),
        ).thenAnswer((_) async {});

        final result = await authRepository.register(
          email: email,
          password: password,
          username: username,
        );

        expect(result.isRight, isTrue);
        expect(result.right, userModel.toDomain());
      },
    );

    test('should not call saveTokens when the remote call fails', () async {
      when(
        () => remoteDataSource.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
          username: any(named: 'username'),
        ),
      ).thenThrow(
        const ServerException(statusCode: 409, message: 'Email in use'),
      );

      await authRepository.register(
        email: email,
        password: password,
        username: username,
      );

      verifyNever(
        () => localDataSource.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ),
      );
    });

    test('should map a 409 ServerException to Left(ServerFailure) with the '
        'same status code and message', () async {
      when(
        () => remoteDataSource.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
          username: any(named: 'username'),
        ),
      ).thenThrow(
        const ServerException(
          statusCode: 409,
          message: 'An active account already exists for this email.',
        ),
      );

      final result = await authRepository.register(
        email: email,
        password: password,
        username: username,
      );

      expect(result.isLeft, isTrue);
      expect(
        result.left,
        const Failure.server(
          statusCode: 409,
          message: 'An active account already exists for this email.',
        ),
      );
    });

    test('should map a 400 ServerException to Left(ServerFailure) with '
        'statusCode 400', () async {
      when(
        () => remoteDataSource.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
          username: any(named: 'username'),
        ),
      ).thenThrow(
        const ServerException(statusCode: 400, message: 'Bad request'),
      );

      final result = await authRepository.register(
        email: email,
        password: password,
        username: username,
      );

      expect(result.isLeft, isTrue);
      expect((result.left as ServerFailure).statusCode, 400);
    });

    test('should map NetworkException to Left(NetworkFailure)', () async {
      when(
        () => remoteDataSource.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
          username: any(named: 'username'),
        ),
      ).thenThrow(const NetworkException());

      final result = await authRepository.register(
        email: email,
        password: password,
        username: username,
      );

      expect(result.isLeft, isTrue);
      expect(result.left, isA<NetworkFailure>());
    });

    test('should map a CacheException thrown while saving tokens to '
        'Left(CacheFailure)', () async {
      when(
        () => remoteDataSource.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
          username: any(named: 'username'),
        ),
      ).thenAnswer((_) async => userModel);
      when(
        () => localDataSource.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ),
      ).thenThrow(const CacheException(message: 'Secure storage unavailable'));

      final result = await authRepository.register(
        email: email,
        password: password,
        username: username,
      );

      expect(result.isLeft, isTrue);
      expect(
        result.left,
        const Failure.cache(message: 'Secure storage unavailable'),
      );
    });
  });

  group('AuthRepositoryImpl.login', () {
    test(
      'should call IAuthRemoteDataSource.login with the given credentials',
      () async {
        when(
          () => remoteDataSource.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => userModel);
        when(
          () => localDataSource.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          ),
        ).thenAnswer((_) async {});

        await authRepository.login(email: email, password: password);

        verify(
          () => remoteDataSource.login(email: email, password: password),
        ).called(1);
      },
    );

    test('should persist the returned tokens on success', () async {
      when(
        () => remoteDataSource.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => userModel);
      when(
        () => localDataSource.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ),
      ).thenAnswer((_) async {});

      await authRepository.login(email: email, password: password);

      verify(
        () => localDataSource.saveTokens(
          accessToken: userModel.accessToken,
          refreshToken: userModel.refreshToken,
        ),
      ).called(1);
    });

    test(
      'should return Right(UserEntity) mapped from the UserModel on success',
      () async {
        when(
          () => remoteDataSource.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => userModel);
        when(
          () => localDataSource.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          ),
        ).thenAnswer((_) async {});

        final result = await authRepository.login(
          email: email,
          password: password,
        );

        expect(result.isRight, isTrue);
        expect(result.right, userModel.toDomain());
      },
    );

    test('should map a 401 ServerException to Left(AuthFailure) with a fixed '
        'message, not the exception message', () async {
      when(
        () => remoteDataSource.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        const ServerException(
          statusCode: 401,
          message: 'some-backend-specific-diagnostic-text',
        ),
      );

      final result = await authRepository.login(
        email: email,
        password: password,
      );

      expect(result.isLeft, isTrue);
      expect(
        result.left,
        const Failure.auth(message: 'Invalid email or password.'),
      );
    });

    test(
      'should return the identical AuthFailure for an unknown email and '
      'for a wrong password (both surface as a 401 ServerException)',
      () async {
        when(
          () => remoteDataSource.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          const ServerException(statusCode: 401, message: 'irrelevant'),
        );

        final unknownEmailResult = await authRepository.login(
          email: 'nobody@example.com',
          password: 'anything',
        );
        final wrongPasswordResult = await authRepository.login(
          email: email,
          password: 'wrongpassword',
        );

        expect(unknownEmailResult.left, wrongPasswordResult.left);
      },
    );

    test('should map a non-401 ServerException to Left(ServerFailure) with '
        'the real status code', () async {
      when(
        () => remoteDataSource.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        const ServerException(statusCode: 500, message: 'Server error'),
      );

      final result = await authRepository.login(
        email: email,
        password: password,
      );

      expect(result.isLeft, isTrue);
      expect((result.left as ServerFailure).statusCode, 500);
    });

    test('should map NetworkException to Left(NetworkFailure)', () async {
      when(
        () => remoteDataSource.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const NetworkException());

      final result = await authRepository.login(
        email: email,
        password: password,
      );

      expect(result.isLeft, isTrue);
      expect(result.left, isA<NetworkFailure>());
    });

    test('should map a CacheException thrown while saving tokens to '
        'Left(CacheFailure)', () async {
      when(
        () => remoteDataSource.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => userModel);
      when(
        () => localDataSource.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ),
      ).thenThrow(const CacheException(message: 'Secure storage unavailable'));

      final result = await authRepository.login(
        email: email,
        password: password,
      );

      expect(result.isLeft, isTrue);
      expect(
        result.left,
        const Failure.cache(message: 'Secure storage unavailable'),
      );
    });
  });

  group('AuthRepositoryImpl.getCurrentUser', () {
    final userProfileModel = UserProfileModel(
      id: '550e8400-e29b-41d4-a716-446655440000',
      email: email,
      username: username,
      role: 'registered',
      createdAt: DateTime.utc(2025, 1, 1),
    );

    test('should return Left(AuthFailure) without calling the remote data '
        'source when no access token is cached', () async {
      when(
        () => localDataSource.getAccessToken(),
      ).thenAnswer((_) async => null);

      final result = await authRepository.getCurrentUser();

      expect(result.isLeft, isTrue);
      expect(result.left, isA<AuthFailure>());
      verifyNever(
        () => remoteDataSource.getCurrentUser(
          accessToken: any(named: 'accessToken'),
        ),
      );
    });

    test('should call IAuthRemoteDataSource.getCurrentUser with the cached '
        'access token', () async {
      when(
        () => localDataSource.getAccessToken(),
      ).thenAnswer((_) async => 'cached-access-token');
      when(
        () => remoteDataSource.getCurrentUser(
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer((_) async => userProfileModel);

      await authRepository.getCurrentUser();

      verify(
        () =>
            remoteDataSource.getCurrentUser(accessToken: 'cached-access-token'),
      ).called(1);
    });

    test(
      'should return Right(UserEntity) mapped from the profile on success',
      () async {
        when(
          () => localDataSource.getAccessToken(),
        ).thenAnswer((_) async => 'cached-access-token');
        when(
          () => remoteDataSource.getCurrentUser(
            accessToken: any(named: 'accessToken'),
          ),
        ).thenAnswer((_) async => userProfileModel);

        final result = await authRepository.getCurrentUser();

        expect(result.isRight, isTrue);
        expect(result.right, userProfileModel.toDomain());
      },
    );

    test('should map a 401 ServerException to Left(AuthFailure) with a '
        'fixed message', () async {
      when(
        () => localDataSource.getAccessToken(),
      ).thenAnswer((_) async => 'cached-access-token');
      when(
        () => remoteDataSource.getCurrentUser(
          accessToken: any(named: 'accessToken'),
        ),
      ).thenThrow(
        const ServerException(
          statusCode: 401,
          message: 'some-backend-specific-diagnostic-text',
        ),
      );

      final result = await authRepository.getCurrentUser();

      expect(
        result.left,
        const Failure.auth(message: 'Invalid or expired session.'),
      );
    });

    test(
      'should map a non-401 ServerException to Left(ServerFailure)',
      () async {
        when(
          () => localDataSource.getAccessToken(),
        ).thenAnswer((_) async => 'cached-access-token');
        when(
          () => remoteDataSource.getCurrentUser(
            accessToken: any(named: 'accessToken'),
          ),
        ).thenThrow(const ServerException(statusCode: 500, message: 'error'));

        final result = await authRepository.getCurrentUser();

        expect((result.left as ServerFailure).statusCode, 500);
      },
    );

    test('should map NetworkException to Left(NetworkFailure)', () async {
      when(
        () => localDataSource.getAccessToken(),
      ).thenAnswer((_) async => 'cached-access-token');
      when(
        () => remoteDataSource.getCurrentUser(
          accessToken: any(named: 'accessToken'),
        ),
      ).thenThrow(const NetworkException());

      final result = await authRepository.getCurrentUser();

      expect(result.left, isA<NetworkFailure>());
    });
  });

  group('AuthRepositoryImpl.refreshToken', () {
    test('should return Left(AuthFailure) without calling the remote data '
        'source when no refresh token is cached', () async {
      when(
        () => localDataSource.getRefreshToken(),
      ).thenAnswer((_) async => null);

      final result = await authRepository.refreshToken();

      expect(result.isLeft, isTrue);
      expect(result.left, isA<AuthFailure>());
      verifyNever(
        () => remoteDataSource.refreshToken(
          refreshToken: any(named: 'refreshToken'),
        ),
      );
    });

    test('should call IAuthRemoteDataSource.refreshToken with the cached '
        'refresh token', () async {
      when(
        () => localDataSource.getRefreshToken(),
      ).thenAnswer((_) async => 'cached-refresh-token');
      when(
        () => remoteDataSource.refreshToken(
          refreshToken: any(named: 'refreshToken'),
        ),
      ).thenAnswer((_) async => userModel);
      when(
        () => localDataSource.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ),
      ).thenAnswer((_) async {});

      await authRepository.refreshToken();

      verify(
        () =>
            remoteDataSource.refreshToken(refreshToken: 'cached-refresh-token'),
      ).called(1);
    });

    test('should persist the newly rotated tokens on success', () async {
      when(
        () => localDataSource.getRefreshToken(),
      ).thenAnswer((_) async => 'cached-refresh-token');
      when(
        () => remoteDataSource.refreshToken(
          refreshToken: any(named: 'refreshToken'),
        ),
      ).thenAnswer((_) async => userModel);
      when(
        () => localDataSource.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ),
      ).thenAnswer((_) async {});

      await authRepository.refreshToken();

      verify(
        () => localDataSource.saveTokens(
          accessToken: userModel.accessToken,
          refreshToken: userModel.refreshToken,
        ),
      ).called(1);
    });

    test(
      'should return Right(UserEntity) mapped from the rotated tokens',
      () async {
        when(
          () => localDataSource.getRefreshToken(),
        ).thenAnswer((_) async => 'cached-refresh-token');
        when(
          () => remoteDataSource.refreshToken(
            refreshToken: any(named: 'refreshToken'),
          ),
        ).thenAnswer((_) async => userModel);
        when(
          () => localDataSource.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          ),
        ).thenAnswer((_) async {});

        final result = await authRepository.refreshToken();

        expect(result.isRight, isTrue);
        expect(result.right, userModel.toDomain());
      },
    );

    test('should map a 401 ServerException to Left(AuthFailure) with a '
        'fixed message (covers rotation/replay)', () async {
      when(
        () => localDataSource.getRefreshToken(),
      ).thenAnswer((_) async => 'stale-refresh-token');
      when(
        () => remoteDataSource.refreshToken(
          refreshToken: any(named: 'refreshToken'),
        ),
      ).thenThrow(
        const ServerException(statusCode: 401, message: 'irrelevant'),
      );
      when(() => localDataSource.clearTokens()).thenAnswer((_) async {});

      final result = await authRepository.refreshToken();

      expect(
        result.left,
        const Failure.auth(message: 'Invalid or expired refresh token.'),
      );
    });

    test('should clear local tokens when the refresh token is rejected with '
        '401', () async {
      when(
        () => localDataSource.getRefreshToken(),
      ).thenAnswer((_) async => 'stale-refresh-token');
      when(
        () => remoteDataSource.refreshToken(
          refreshToken: any(named: 'refreshToken'),
        ),
      ).thenThrow(
        const ServerException(statusCode: 401, message: 'irrelevant'),
      );
      when(() => localDataSource.clearTokens()).thenAnswer((_) async {});

      await authRepository.refreshToken();

      verify(() => localDataSource.clearTokens()).called(1);
    });

    test('should NOT clear local tokens on a non-401 failure (server error, '
        'network error)', () async {
      when(
        () => localDataSource.getRefreshToken(),
      ).thenAnswer((_) async => 'cached-refresh-token');
      when(
        () => remoteDataSource.refreshToken(
          refreshToken: any(named: 'refreshToken'),
        ),
      ).thenThrow(const NetworkException());

      await authRepository.refreshToken();

      verifyNever(() => localDataSource.clearTokens());
    });

    test('should map NetworkException to Left(NetworkFailure)', () async {
      when(
        () => localDataSource.getRefreshToken(),
      ).thenAnswer((_) async => 'cached-refresh-token');
      when(
        () => remoteDataSource.refreshToken(
          refreshToken: any(named: 'refreshToken'),
        ),
      ).thenThrow(const NetworkException());

      final result = await authRepository.refreshToken();

      expect(result.left, isA<NetworkFailure>());
    });

    test('should map a CacheException thrown while saving the rotated '
        'tokens to Left(CacheFailure)', () async {
      when(
        () => localDataSource.getRefreshToken(),
      ).thenAnswer((_) async => 'cached-refresh-token');
      when(
        () => remoteDataSource.refreshToken(
          refreshToken: any(named: 'refreshToken'),
        ),
      ).thenAnswer((_) async => userModel);
      when(
        () => localDataSource.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ),
      ).thenThrow(const CacheException(message: 'Secure storage unavailable'));

      final result = await authRepository.refreshToken();

      expect(
        result.left,
        const Failure.cache(message: 'Secure storage unavailable'),
      );
    });
  });

  group('AuthRepositoryImpl.logout', () {
    test('should call IAuthRemoteDataSource.logout with the cached access '
        'token when one is present', () async {
      when(
        () => localDataSource.getAccessToken(),
      ).thenAnswer((_) async => 'cached-access-token');
      when(
        () => remoteDataSource.logout(accessToken: any(named: 'accessToken')),
      ).thenAnswer((_) async {});
      when(() => localDataSource.clearTokens()).thenAnswer((_) async {});

      await authRepository.logout();

      verify(
        () => remoteDataSource.logout(accessToken: 'cached-access-token'),
      ).called(1);
    });

    test('should skip the remote call when no access token is cached, but '
        'still clear local tokens', () async {
      when(
        () => localDataSource.getAccessToken(),
      ).thenAnswer((_) async => null);
      when(() => localDataSource.clearTokens()).thenAnswer((_) async {});

      final result = await authRepository.logout();

      verifyNever(
        () => remoteDataSource.logout(accessToken: any(named: 'accessToken')),
      );
      verify(() => localDataSource.clearTokens()).called(1);
      expect(result.isRight, isTrue);
    });

    test(
      'should clear local tokens and return Right(null) on remote success',
      () async {
        when(
          () => localDataSource.getAccessToken(),
        ).thenAnswer((_) async => 'cached-access-token');
        when(
          () => remoteDataSource.logout(accessToken: any(named: 'accessToken')),
        ).thenAnswer((_) async {});
        when(() => localDataSource.clearTokens()).thenAnswer((_) async {});

        final result = await authRepository.logout();

        verify(() => localDataSource.clearTokens()).called(1);
        expect(result.isRight, isTrue);
      },
    );

    test('should still clear local tokens and return Right(null) when the '
        'remote call fails with a ServerException', () async {
      when(
        () => localDataSource.getAccessToken(),
      ).thenAnswer((_) async => 'cached-access-token');
      when(
        () => remoteDataSource.logout(accessToken: any(named: 'accessToken')),
      ).thenThrow(
        const ServerException(statusCode: 401, message: 'irrelevant'),
      );
      when(() => localDataSource.clearTokens()).thenAnswer((_) async {});

      final result = await authRepository.logout();

      verify(() => localDataSource.clearTokens()).called(1);
      expect(result.isRight, isTrue);
    });

    test('should still clear local tokens and return Right(null) when the '
        'remote call fails with a NetworkException', () async {
      when(
        () => localDataSource.getAccessToken(),
      ).thenAnswer((_) async => 'cached-access-token');
      when(
        () => remoteDataSource.logout(accessToken: any(named: 'accessToken')),
      ).thenThrow(const NetworkException());
      when(() => localDataSource.clearTokens()).thenAnswer((_) async {});

      final result = await authRepository.logout();

      verify(() => localDataSource.clearTokens()).called(1);
      expect(result.isRight, isTrue);
    });

    test(
      'should return Left(CacheFailure) when clearing local tokens fails',
      () async {
        when(
          () => localDataSource.getAccessToken(),
        ).thenAnswer((_) async => 'cached-access-token');
        when(
          () => remoteDataSource.logout(accessToken: any(named: 'accessToken')),
        ).thenAnswer((_) async {});
        when(() => localDataSource.clearTokens()).thenThrow(
          const CacheException(message: 'Secure storage unavailable'),
        );

        final result = await authRepository.logout();

        expect(result.isLeft, isTrue);
        expect(
          result.left,
          const Failure.cache(message: 'Secure storage unavailable'),
        );
      },
    );
  });
}
