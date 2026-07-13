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
/// Two handlers are wired so far:
/// - `AuthEvent.checkStatusRequested` — restores a previous
///   session silently on cold start.
/// - `AuthEvent.logoutRequested` — terminates the session on
///   user request.
///
/// See `AuthEvent` for which other variants remain unhandled and why.
///
/// ## Scope boundary
/// The full F-A03 feature also calls for an `App` widget that dispatches
/// `checkStatusRequested` on initialisation, and a `GoRouterRefreshStream`
/// that re-evaluates route guards on every [AuthState] emission. The full
/// F-A04 feature calls for a `ProfilePage` whose logout button dispatches
/// `logoutRequested`. None of this exists yet: this codebase has no
/// routing package (`go_router` or otherwise), no application shell, and
/// no `ProfilePage` (a separate, unbuilt feature — F-A05, which adds the
/// user's username, email, role badge, avatar, and member-since date;
/// building it here to satisfy this ticket's UI-facing acceptance
/// criteria would be scope creep well beyond "wire AuthBloc"). Every
/// screen built so far (`RegisterPage`, `LoginPage`) is wired through
/// plain constructor callbacks precisely because nothing above them
/// exists yet. This class is fully ready to be dispatched from wherever
/// that shell and that page eventually live —
/// `context.read<AuthBloc>().add(const AuthEvent.logoutRequested())` is
/// the call `ProfilePage`'s logout button makes once it exists.
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
/// This sequencing, combined with `AuthRepositoryImpl`'s own local
/// short-circuiting (a missing cached token never reaches the
/// network at all), satisfies every acceptance path without this class
/// needing to special-case "no token" itself:
/// - Valid cached access token → step 2 succeeds directly.
/// - Expired access token, valid refresh token → step 2 fails, step 3
///   succeeds.
/// - Both expired/invalid → step 2 fails, step 3 fails; the repository
///   layer clears the now-useless cached tokens itself (see
///   `AuthRepositoryImpl.refreshToken`'s 401 handling) before this
///   handler emits [AuthState.unauthenticated].
/// - No cached token at all → both steps fail purely locally, with no
///   network round-trip, before immediately emitting
///   [AuthState.unauthenticated].
///
/// ## logoutRequested behaviour
/// 1. Emit [AuthState.loading].
/// 2. Call `LogoutUseCase`.
/// 3. On success, emit [AuthState.unauthenticated].
/// 4. On failure, emit [AuthState.failure] with the received `Failure`
///    — a deliberate departure from this ticket's literal Definition of
///    Done ("Calls LogoutUseCase, then emits AuthUnauthenticated"),
///    which describes only the success path. `LogoutUseCase` /
///    `AuthRepositoryImpl.logout` can still fail with a
///    [Failure.cache] if the device's own secure storage cannot
///    actually be cleared — in that case the user's tokens are *not*
///    gone, and silently claiming [AuthState.unauthenticated] would be
///    actively misleading about the true session state. This is the
///    first real consumer of [AuthState.failure], reserved for exactly
///    this kind of case since F-A03-T3.
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
}
