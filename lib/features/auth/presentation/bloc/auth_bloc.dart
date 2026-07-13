import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
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
/// One handler wired:
/// `AuthEvent.checkStatusRequested`, dispatched once on application cold
/// start to silently restore a previous session. See `AuthEvent` for
/// which other variants remain unhandled and why.
///
/// ## Scope boundary
/// The full feature (F-A03) also calls for an `App` widget that
/// dispatches `checkStatusRequested` on initialisation, and a
/// `GoRouterRefreshStream` that re-evaluates route guards on every
/// [AuthState] emission. Neither exists yet: this codebase has no
/// routing package (`go_router` or otherwise) and no application shell
/// at all — every screen built so far (`RegisterPage`, `LoginPage`) is
/// wired through plain constructor callbacks precisely because nothing
/// above them exists yet. Building a full app shell and router
/// speculatively, without its own ticket, would be scope creep well
/// beyond "wire AuthBloc". This class is fully ready to be dispatched
/// from wherever that shell eventually lives; the callbacks already
/// exposed by `RegisterPage.onRegistrationSucceeded` and
/// `LoginPage.onLoginSucceeded` are the natural call sites for
/// `context.read<AuthBloc>().add(const AuthEvent.checkStatusRequested())`
/// once it exists.
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
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required RefreshTokenUseCase refreshTokenUseCase,
  }) : _getCurrentUserUseCase = getCurrentUserUseCase,
       _refreshTokenUseCase = refreshTokenUseCase,
       super(const AuthState.initial()) {
    on<AuthCheckStatusRequested>(_onCheckStatusRequested);
  }

  final GetCurrentUserUseCase _getCurrentUserUseCase;
  final RefreshTokenUseCase _refreshTokenUseCase;

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
}
