import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/user_entity.dart';

part 'auth_state.freezed.dart';

/// State hierarchy for [AuthBloc].
///
/// This is the application's single, global source of truth for
/// session status — distinct from `RegisterState`/`LoginState`, which
/// only track the lifecycle of their own form submission. Any part of
/// the UI (route guards, the app shell, a profile menu) reflects the
/// current session by watching this state, not by re-deriving it.
///
/// The `failure` variant's generated class is deliberately named
/// [AuthOperationFailure], not `AuthFailure`: `Failure.auth(...)`
/// (`core/error/failures.dart`) already generates a class named
/// `AuthFailure`, and freezed does not namespace generated class names
/// by their parent union — reusing that name here would collide.
@freezed
sealed class AuthState with _$AuthState {
  /// Initial state before any authentication check has run.
  const factory AuthState.initial() = AuthInitial;

  /// Any authentication operation is in progress. UI must show an
  /// indicator.
  const factory AuthState.loading() = AuthLoading;

  /// A valid session exists. [user] contains the current user data.
  const factory AuthState.authenticated(UserEntity user) = AuthAuthenticated;

  /// No valid session. UI must navigate to (or remain on) the login
  /// screen.
  const factory AuthState.unauthenticated() = AuthUnauthenticated;

  /// The last authentication operation failed for a reason distinct from
  /// "no session" — reserved for future consumers of this bloc (e.g. a
  /// future `AuthEvent.loginRequested` handler); `AuthBloc`'s current
  /// `checkStatusRequested` handler never emits this variant itself,
  /// since both of its failure paths (`getCurrentUser` and
  /// `refreshToken` failing) resolve to [AuthState.unauthenticated]
  /// instead — a failed session check has exactly one meaningful
  /// outcome for the rest of the app to react to.
  const factory AuthState.failure(Failure failure) = AuthOperationFailure;
}
