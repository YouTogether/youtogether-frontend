/// Local data source contract for the Authentication bounded context.
///
/// Implemented by `AuthLocalDataSourceImpl`, backed by
/// `flutter_secure_storage` — all data is encrypted at rest (Keychain on
/// iOS, AES-256 EncryptedSharedPreferences on Android). Passwords are
/// never stored client-side; only the token pair is persisted here.
///
/// This interface grows incrementally, one method (or group) per task,
/// mirroring how `IAuthRepository` was built:
/// - `saveTokens()`
/// - `getAccessToken()`, `getRefreshToken()`, `hasValidToken()` - session restoration needs to read the cached tokens
/// - `clearTokens()` - logout
///
/// @see AuthRepositoryImpl.register — primary consumer of [saveTokens]
/// @see AuthRepositoryImpl.getCurrentUser — primary consumer of [getAccessToken]
/// @see AuthRepositoryImpl.refreshToken — primary consumer of [getRefreshToken]
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

  /// Reads the cached access token, if any.
  ///
  /// Returns `null` when no token has ever been saved, or after
  /// `clearTokens()` — this is a normal, expected outcome (e.g. a fresh
  /// install, or a logged-out user), not an error. A read failure
  /// against the underlying storage itself (as opposed to a legitimate
  /// absence of a cached value) is the only case that throws.
  ///
  /// @throws `CacheException` if the underlying secure storage read
  ///   fails.
  Future<String?> getAccessToken();

  /// Reads the cached refresh token, if any.
  ///
  /// Same absence-vs-failure distinction as [getAccessToken]: `null`
  /// means "nothing cached", not an error.
  ///
  /// @throws `CacheException` if the underlying secure storage read
  ///   fails.
  Future<String?> getRefreshToken();

  /// Returns `true` if an access token is currently cached.
  ///
  /// A cheap, storage-only presence check — it does not contact the
  /// server and does not decode or verify the token's own expiration
  /// claim. A token can be present yet already expired; the definitive
  /// validity check is always the server's response to the next
  /// authenticated request (`GET /auth/me` via
  /// `AuthRepositoryImpl.getCurrentUser`), not this method. Intended for
  /// callers (`AuthBloc`) that need a fast, synchronous-feeling
  /// decision on whether attempting session restoration is worthwhile at
  /// all, before making any network call.
  Future<bool> hasValidToken();
}
