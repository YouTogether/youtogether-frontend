import 'package:freezed_annotation/freezed_annotation.dart';

part 'failures.freezed.dart';

/// Sealed union of all error conditions that can cross a repository or
/// use case boundary in the application.
///
/// Declared with `@freezed` so that consuming code can use Dart's
/// exhaustive `switch` expressions in `fold()` callbacks instead of
/// runtime type checks.
///
/// Every repository and use case in the application returns
/// `Either<Failure, T>` (see `either_dart`); the `Left` side is always
/// one of these subtypes, never a raw exception or a bare `String`.
///
/// Internationalisation convention: every `message` field on a `Failure`
/// subtype (`ServerFailure.message`, `CacheFailure.message`,
/// `AuthFailure.message`, `FirebaseFailure.message`) is diagnostic text —
/// often sourced verbatim from the backend or a platform exception — and
/// is for logs and debugging only. Presentation-layer code (Cubit/BLoC)
/// must NEVER render `failure.message` directly in the UI. Instead, it
/// switches exhaustively on the `Failure` subtype and selects the
/// corresponding string from the generated `AppLocalizations` (see
/// `l10n.yaml`, `lib/l10n/*.arb`). This keeps error copy translatable and
/// prevents an untranslated backend string from leaking into a localised
/// screen.
@freezed
sealed class Failure with _$Failure {
  const Failure._();

  /// HTTP or NestJS API error (e.g. 409 Conflict, 400 Bad Request,
  /// 500 Internal Server Error).
  const factory Failure.server({
    required int statusCode,
    required String message,
  }) = ServerFailure;

  /// No network connectivity — the request never reached the server.
  const factory Failure.network() = NetworkFailure;

  /// Error reading from or writing to local secure storage
  /// (`flutter_secure_storage`).
  const factory Failure.cache({required String message}) = CacheFailure;

  /// Authentication or authorisation error — invalid credentials, an
  /// invalid/expired/replayed token, or a session that is no longer valid.
  const factory Failure.auth({required String message}) = AuthFailure;

  /// The requested resource does not exist.
  const factory Failure.notFound() = NotFoundFailure;

  /// Client-side or server-side input validation failed.
  ///
  /// [errors] maps field names to a human-readable message, mirroring the
  /// per-field error shape returned by the backend's `ValidationPipe`
  /// (see `RegisterDto`, `LoginDto` on the NestJS side).
  const factory Failure.validation({
    required Map<String, String> errors,
  }) = ValidationFailure;

  /// Error from the Firebase Realtime Database (video sync bounded context).
  const factory Failure.firebase({required String message}) = FirebaseFailure;
}