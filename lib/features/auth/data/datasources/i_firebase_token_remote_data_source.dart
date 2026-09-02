/// Contract for the REST (HTTP) data source that obtains a Firebase
/// custom token from the backend.
///
/// Deliberately separate from the SDK-backed
/// `IFirebaseSessionDataSource`. Obtaining a token is an authenticated
/// HTTP call that fails with `ServerException`/`NetworkException`;
/// exchanging it is an SDK call that fails with `FirebaseAuthException`.
/// Collapsing the two into one data source would produce a class with
/// two unrelated failure surfaces, and would make it impossible to test
/// the HTTP half without the platform channels the SDK needs.
///
/// @see FirebaseTokenRemoteDataSourceImpl — the Dio-based implementation
abstract class IFirebaseTokenRemoteDataSource {
  /// Requests a Firebase custom token via
  /// `POST /auth/firebase-token`.
  ///
  /// Sends no body. The backend resolves the user from the bearer token
  /// the Dio interceptor attaches, and re-checks the account is still
  /// active before minting (B-A06) — the returned token's `uid` is what
  /// the Realtime Database rules authorise against, so it must never
  /// derive from anything this client says about itself.
  ///
  /// Throws [ServerException] with:
  /// - `401` — no valid access token, or the account no longer resolves.
  ///   The caller should treat the user as anonymous rather than retry.
  /// - `502` — Firebase could not sign the token. Transient.
  ///
  /// Throws [NetworkException] if the request never reached the backend.
  Future<String> fetchCustomToken();
}
