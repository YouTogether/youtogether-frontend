/// Shared, presentation-layer input validators.
///
/// These are UI-facing checks only — a fast client-side rejection before
/// a request is ever sent to the server (e.g. `RegisterCubit`,
/// `LoginCubit`). They mirror, but do not replace, the backend's own
/// validation (`RegisterDto`, `LoginDto` on the NestJS side): the server
/// remains the final authority, and its response is always handled
/// regardless of what the client already checked.
///
/// This file has no dedicated ticket — it is a prerequisite for
/// `RegisterCubit` and is created here rather than deferred,
/// mirroring how `core/error/failures.dart` and
/// `core/error/exceptions.dart` were introduced ahead of
/// their own first consumers.
library;

/// Practical email format check.
///
/// Uses the pattern recommended by the WHATWG HTML5 specification for
/// the `email` input type — a close, widely used approximation of
/// RFC 5322 suitable for UI validation. The full RFC 5322 grammar accepts
/// many syntactically valid but never-actually-used address forms
/// (quoted local parts, comments, etc.) that would only confuse users if
/// accepted here. The backend performs the definitive check via
/// `class-validator`'s `@IsEmail()` in any case.
final RegExp _emailPattern = RegExp(
  r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]"
  r'(?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?'
  r'(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
);

/// Namespace for shared presentation-layer validators.
///
/// Declared as a class with a private constructor (rather than top-level
/// functions) purely for discoverability and namespacing at call sites
/// (`Validators.isValidEmail(...)`); it holds no state.
class Validators {
  const Validators._();

  /// Returns `true` if [value] is a plausible email address.
  static bool isValidEmail(String value) => _emailPattern.hasMatch(value);
}
