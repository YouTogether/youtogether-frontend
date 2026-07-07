/// Exceptions thrown by data sources (remote and local).
///
/// These are infrastructure-level signals, never returned to the domain
/// layer directly. Each repository method catches the exception types its
/// data sources can throw and maps them to the corresponding [Failure]
/// subtype before returning `Either<Failure, T>` — the exception
/// hierarchy and the [Failure] hierarchy are deliberately kept separate:
/// exceptions are a data-layer implementation detail, `Failure` is the
/// domain-facing contract.
///
/// This file has no feature-specific ticket — it is a prerequisite for
/// the first data-source contract (`IAuthRemoteDataSource`)
/// and is created here rather than deferred, mirroring how
/// `core/error/failures.dart` was introduced ahead of its own first
/// consumer.
library;

/// Thrown by a remote data source when the server responds with an
/// error status code (4xx or 5xx).
///
/// Carries the raw HTTP status code so the repository can decide how to
/// map it — e.g. 409 becomes a duplicate-email `ServerFailure` on
/// register, 401 becomes an `AuthFailure` on login. The [message] is
/// diagnostic text only (see `Failure` internationalisation convention);
/// it must never be rendered directly in the UI.
class ServerException implements Exception {
  const ServerException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => 'ServerException($statusCode): $message';
}

/// Thrown by a remote data source when the request never reaches the
/// server — no connectivity, DNS failure, or connection timeout.
class NetworkException implements Exception {
  const NetworkException();

  @override
  String toString() => 'NetworkException';
}

/// Thrown by the local data source when reading from or writing to
/// secure storage fails, or when a value expected to be present
/// (e.g. a cached token) is absent.
class CacheException implements Exception {
  const CacheException({required this.message});

  final String message;

  @override
  String toString() => 'CacheException: $message';
}

/// Thrown by a remote data source specifically for authentication and
/// authorisation errors (HTTP 401) — kept distinct from the general
/// [ServerException] so that repositories can map it to `AuthFailure`
/// without inspecting a status code.
class AuthException implements Exception {
  const AuthException({required this.message});

  final String message;

  @override
  String toString() => 'AuthException: $message';
}
