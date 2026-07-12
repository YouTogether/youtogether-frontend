import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/exceptions.dart';
import 'package:youtogether/features/auth/data/datasources/auth_local_data_source_impl.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late AuthLocalDataSourceImpl dataSource;
  late MockFlutterSecureStorage secureStorage;

  setUp(() {
    secureStorage = MockFlutterSecureStorage();
    dataSource = AuthLocalDataSourceImpl(secureStorage);
  });

  group('saveTokens', () {
    test('should write both tokens under their dedicated keys', () async {
      when(
        () => secureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      await dataSource.saveTokens(
        accessToken: 'access-token-value',
        refreshToken: 'refresh-token-value',
      );

      verify(
        () => secureStorage.write(
          key: AuthLocalDataSourceImpl.accessTokenKey,
          value: 'access-token-value',
        ),
      ).called(1);
      verify(
        () => secureStorage.write(
          key: AuthLocalDataSourceImpl.refreshTokenKey,
          value: 'refresh-token-value',
        ),
      ).called(1);
    });

    test(
      'should throw CacheException when the underlying write fails',
      () async {
        when(
          () => secureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenThrow(Exception('keystore unavailable'));

        await expectLater(
          () => dataSource.saveTokens(accessToken: 'a', refreshToken: 'b'),
          throwsA(isA<CacheException>()),
        );
      },
    );
  });

  group('getAccessToken', () {
    test('should return the cached value under the access token key', () async {
      when(
        () => secureStorage.read(key: AuthLocalDataSourceImpl.accessTokenKey),
      ).thenAnswer((_) async => 'cached-access-token');

      final result = await dataSource.getAccessToken();

      expect(result, 'cached-access-token');
    });

    test('should return null when nothing is cached', () async {
      when(
        () => secureStorage.read(key: AuthLocalDataSourceImpl.accessTokenKey),
      ).thenAnswer((_) async => null);

      final result = await dataSource.getAccessToken();

      expect(result, isNull);
    });

    test(
      'should throw CacheException when the underlying read fails',
      () async {
        when(
          () => secureStorage.read(key: AuthLocalDataSourceImpl.accessTokenKey),
        ).thenThrow(Exception('keystore unavailable'));

        await expectLater(
          () => dataSource.getAccessToken(),
          throwsA(isA<CacheException>()),
        );
      },
    );
  });

  group('getRefreshToken', () {
    test(
      'should return the cached value under the refresh token key',
      () async {
        when(
          () =>
              secureStorage.read(key: AuthLocalDataSourceImpl.refreshTokenKey),
        ).thenAnswer((_) async => 'cached-refresh-token');

        final result = await dataSource.getRefreshToken();

        expect(result, 'cached-refresh-token');
      },
    );

    test('should return null when nothing is cached', () async {
      when(
        () => secureStorage.read(key: AuthLocalDataSourceImpl.refreshTokenKey),
      ).thenAnswer((_) async => null);

      final result = await dataSource.getRefreshToken();

      expect(result, isNull);
    });

    test(
      'should throw CacheException when the underlying read fails',
      () async {
        when(
          () =>
              secureStorage.read(key: AuthLocalDataSourceImpl.refreshTokenKey),
        ).thenThrow(Exception('keystore unavailable'));

        await expectLater(
          () => dataSource.getRefreshToken(),
          throwsA(isA<CacheException>()),
        );
      },
    );
  });

  group('hasValidToken', () {
    test('should return true when an access token is cached', () async {
      when(
        () => secureStorage.read(key: AuthLocalDataSourceImpl.accessTokenKey),
      ).thenAnswer((_) async => 'some-token');

      expect(await dataSource.hasValidToken(), isTrue);
    });

    test('should return false when no access token is cached', () async {
      when(
        () => secureStorage.read(key: AuthLocalDataSourceImpl.accessTokenKey),
      ).thenAnswer((_) async => null);

      expect(await dataSource.hasValidToken(), isFalse);
    });

    test('should return false when the cached access token is empty', () async {
      when(
        () => secureStorage.read(key: AuthLocalDataSourceImpl.accessTokenKey),
      ).thenAnswer((_) async => '');

      expect(await dataSource.hasValidToken(), isFalse);
    });
  });
}
