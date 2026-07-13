import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_event.freezed.dart';

/// Event hierarchy for [AuthBloc].
///
/// Declared here as the full, already-specified five-variant union
/// rather than grown incrementally (unlike `IAuthRepository`): the
/// Interface Contracts document fully specifies this shape up front.
/// Only [AuthEvent.checkStatusRequested] is actually handled by
/// [AuthBloc]; the remaining variants are
/// declared for contract completeness and wired by their own tickets:
/// - [AuthEvent.logoutRequested].
/// - [AuthEvent.loginRequested], `LoginCubit` independently owns the login
///   flow today.
/// - [AuthEvent.tokenRefreshRequested] — intended to be dispatched
///   internally by a Dio interceptor on an intercepted 401, which does
///   not exist yet in this codebase.
///
/// Dispatching an event variant with no registered handler is not an
/// error in `flutter_bloc` — it is simply a no-op until the
/// corresponding ticket adds an `on<...>()` registration.
@freezed
sealed class AuthEvent with _$AuthEvent {
  /// Dispatched when the user submits the login form.
  const factory AuthEvent.loginRequested({
    required String email,
    required String password,
  }) = AuthLoginRequested;

  /// Dispatched when the user triggers logout from the menu.
  const factory AuthEvent.logoutRequested() = AuthLogoutRequested;

  /// Dispatched on app cold start to restore session state.
  const factory AuthEvent.checkStatusRequested() = AuthCheckStatusRequested;

  /// Dispatched internally when a 401 is intercepted by Dio.
  const factory AuthEvent.tokenRefreshRequested() = AuthTokenRefreshRequested;
}
