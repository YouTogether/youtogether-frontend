/// Local data source contract for the Authentication bounded context.
///
/// Implemented by `AuthLocalDataSourceImpl` (forthcoming), backed by
/// `flutter_secure_storage` — all data is encrypted at rest (AES-256 on
/// Android, Keychain on iOS). Passwords are never stored client-side;
/// only the token pair is persisted here.
///
/// This interface grows incrementally, one method per task, mirroring
/// how `IAuthRepository` was built:
/// - `saveTokens()`
/// - `getAccessToken()`, `getRefreshToken()`, `hasValidToken()` — (session restoration needs to read the cached tokens)
/// - `clearTokens()`
///
/// @see AuthRepositoryImpl.register — primary consumer of [saveTokens]
abstract class IAuthLocalDataSource {
  /// Persists both tokens to secure storage, overwriting any existing
  /// tokens.
  ///
  /// @throws `CacheException` if the underlying secure storage write
  ///   fails (e.g. platform keystore unavailable).
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });
}
