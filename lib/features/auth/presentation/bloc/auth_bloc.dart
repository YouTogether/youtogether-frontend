import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/refresh_token_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// Global session-state bloc for the Authentication bounded context.
///
/// Unlike `RegisterCubit`/`LoginCubit`, which each track only their own
/// form's submission lifecycle, [AuthBloc] is the application's single
/// source of truth for whether a session currently exists — consumed by
/// route guards and the app shell, not tied to any one screen.
///
/// Three handlers are wired:
/// - `AuthEvent.checkStatusRequested` — restores a previous
///   session silently on cold start.
/// - `AuthEvent.logoutRequested` — terminates the session on
///   user request.
/// - `AuthEvent.tokenRefreshRequested` — dispatched internally by
///   [AuthInterceptor] on an intercepted 401 (F-INF-T1, closing gap 6 of
///   ADR-001). See that handler's own doc comment for why it does not
///   emit [AuthState.loading].
///
/// See `AuthEvent` for which other variants remain unhandled and why.
///
/// ## Scope boundary (historical — F-A03-T3)
/// The full F-A03 feature also called for an `App` widget dispatching
/// `checkStatusRequested` on initialisation, and a `GoRouterRefreshStream`
/// re-evaluating route guards on every [AuthState] emission. Both now
/// exist (`lib/app.dart`, `lib/core/router/go_router_refresh_stream.dart`,
/// built by F-INF-T1).
///
/// ## checkStatusRequested behaviour
/// 1. Emit [AuthState.loading].
/// 2. Call `GetCurrentUserUseCase`. On success, emit
///    [AuthState.authenticated] with the returned user and stop — no
///    cached token even needs inspecting further, and
///    `RefreshTokenUseCase` is never called.
/// 3. On failure (no cached access token, or the server rejected it),
///    call `RefreshTokenUseCase` as a silent fallback. Both of its own
///    outcomes are then resolved directly: a returned user means the
///    token was successfully renewed (and already re-persisted by
///    `AuthRepositoryImpl.refreshToken` before this handler ever sees
///    the result), emitting [AuthState.authenticated]; a failure of any
///    kind — no refresh token cached, or the server rejected it too —
///    emits [AuthState.unauthenticated].
///
/// ## logoutRequested behaviour
/// Emits [AuthState.loading], calls `LogoutUseCase`, then emits
/// [AuthState.unauthenticated] on success or [AuthState.failure] if
/// `LogoutUseCase` / `AuthRepositoryImpl.logout` can still fail with a
/// [Failure.cache] if the device's own secure storage cannot
/// actually be cleared — in that case the user's tokens are *not*
/// gone, and silently claiming [AuthState.unauthenticated] would be
/// actively misleading about the true session state. This is the
/// first real consumer of [AuthState.failure], reserved for exactly
/// this kind of case since F-A03-T3.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required RefreshTokenUseCase refreshTokenUseCase,
    required LogoutUseCase logoutUseCase,
  }) : _getCurrentUserUseCase = getCurrentUserUseCase,
       _refreshTokenUseCase = refreshTokenUseCase,
       _logoutUseCase = logoutUseCase,
       super(const AuthState.initial()) {
    on<AuthCheckStatusRequested>(_onCheckStatusRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthTokenRefreshRequested>(_onTokenRefreshRequested);
  }

  final GetCurrentUserUseCase _getCurrentUserUseCase;
  final RefreshTokenUseCase _refreshTokenUseCase;
  final LogoutUseCase _logoutUseCase;

  Future<void> _onCheckStatusRequested(
    AuthCheckStatusRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.loading());

    final currentUserResult = await _getCurrentUserUseCase(const NoParams());

    if (currentUserResult.isRight) {
      emit(AuthState.authenticated(currentUserResult.right));
      return;
    }

    final refreshResult = await _refreshTokenUseCase(const NoParams());

    refreshResult.fold(
      (failure) => emit(const AuthState.unauthenticated()),
      (user) => emit(AuthState.authenticated(user)),
    );
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.loading());

    final result = await _logoutUseCase(const NoParams());

    result.fold(
      (failure) => emit(AuthState.failure(failure)),
      (_) => emit(const AuthState.unauthenticated()),
    );
  }

  /// Handles a 401 intercepted by [AuthInterceptor].
  ///
  /// Deliberately does **not** emit [AuthState.loading] first, unlike
  /// [_onCheckStatusRequested]: this refresh happens silently in the
  /// background, potentially while the user is mid-interaction on any
  /// screen that watches this Bloc's global state (a profile menu, a
  /// route guard). Emitting `loading` here would flash a session-wide
  /// loading indicator for a request the user never initiated and may
  /// not even be aware of — `checkStatusRequested`'s cold-start loading
  /// state is acceptable because the whole app is already showing a
  /// splash at that point; this handler has no equivalent justification.
  ///
  /// [AuthInterceptor] awaits the next terminal state emitted here
  /// (`authenticated`, `unauthenticated`, or `failure`) via
  /// `authBloc.stream.firstWhere(...)` to decide whether to retry the
  /// original request — see that class for the full collaboration.
  Future<void> _onTokenRefreshRequested(
    AuthTokenRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _refreshTokenUseCase(const NoParams());

    result.fold(
      (failure) => emit(const AuthState.unauthenticated()),
      (user) => emit(AuthState.authenticated(user)),
    );
  }
}
