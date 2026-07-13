import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/error/exceptions.dart';
import 'i_auth_local_data_source.dart';

/// `flutter_secure_storage`-based implementation of
/// [IAuthLocalDataSource].
///
/// Receives a pre-configured [FlutterSecureStorage] instance via
/// constructor injection — platform-specific options (e.g.
/// `AndroidOptions(encryptedSharedPreferences: true)`) are the concern of
/// whichever module wires the dependency graph, not of this class.
///
/// Every method wraps the underlying plugin call in a try/catch and
/// rethrows as [CacheException]: `flutter_secure_storage` surfaces
/// platform-specific exceptions (e.g. `PlatformException` on Android),
/// which this class translates into the single, platform-agnostic
/// exception type the rest of the data layer already expects (see
/// `AuthRepositoryImpl`).
///
/// Grows one method (or group) per task, mirroring [IAuthLocalDataSource]
/// itself:
/// - `saveTokens()`
/// - `getAccessToken()`, `getRefreshToken()`, `hasValidToken()`
/// - `clearTokens()`
class AuthLocalDataSourceImpl implements IAuthLocalDataSource {
  const AuthLocalDataSourceImpl(this._secureStorage);

  final FlutterSecureStorage _secureStorage;

  /// Storage key for the cached access token.
  static const String accessTokenKey = 'auth_access_token';

  /// Storage key for the cached refresh token.
  static const String refreshTokenKey = 'auth_refresh_token';

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      await _secureStorage.write(key: accessTokenKey, value: accessToken);
      await _secureStorage.write(key: refreshTokenKey, value: refreshToken);
    } catch (error) {
      throw CacheException(message: 'Failed to persist session tokens: $error');
    }
  }

  @override
  Future<String?> getAccessToken() async {
    try {
      return await _secureStorage.read(key: accessTokenKey);
    } catch (error) {
      throw CacheException(message: 'Failed to read the access token: $error');
    }
  }

  @override
  Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.read(key: refreshTokenKey);
    } catch (error) {
      throw CacheException(message: 'Failed to read the refresh token: $error');
    }
  }

  @override
  Future<bool> hasValidToken() async {
    final accessToken = await getAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }

  @override
  Future<void> clearTokens() async {
    try {
      await _secureStorage.delete(key: accessTokenKey);
      await _secureStorage.delete(key: refreshTokenKey);
    } catch (error) {
      throw CacheException(message: 'Failed to clear session tokens: $error');
    }
  }
}
