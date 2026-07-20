import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/register_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/profile_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/room/domain/usecases/get_public_rooms_usecase.dart';
import '../../features/room/presentation/bloc/room_bloc.dart';
import '../../features/room/presentation/bloc/room_event.dart';
import '../../features/room/presentation/pages/home_page.dart';
import 'go_router_refresh_stream.dart';

/// Route paths, centralised to avoid string-literal drift between the
/// route table and any `context.go(...)` call site.
abstract final class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String profile = '/profile';
}

/// Pure route-guard decision function, extracted from
/// `GoRouter.redirect` specifically so it can be unit tested without
/// booting a `GoRouter` or a widget tree (see
/// `test/core/router/app_router_test.dart`).
///
/// Returns the path to redirect to, or `null` to stay on
/// [matchedLocation].
///
/// Decision table:
/// - [AuthState.initial] / [AuthState.loading]: no redirect. The session
///   check triggered by `App`'s `checkStatusRequested` dispatch on cold
///   start has not resolved yet; redirecting to `/login` here would
///   flash the login screen for a fraction of a second even for a user
///   with a perfectly valid cached session, on every cold start.
/// - Authenticated, on `/login` or `/register`: redirect to
///   [AppRoutes.home] (an already-authenticated user has no reason to
///   see the auth forms).
/// - Authenticated, elsewhere (including [AppRoutes.profile]): no
///   redirect.
/// - Unauthenticated or failed (`AuthState.unauthenticated` /
///   `AuthState.failure` — both mean "no valid session" from the
///   router's perspective, see `AuthState.failure`'s own doc comment),
///   on a protected route (including [AppRoutes.profile]): redirect to
///   [AppRoutes.login].
/// - Unauthenticated or failed, already on `/login` or `/register`: no
///   redirect.
///
/// [AppRoutes.profile] needs no dedicated branch here: it falls out of
/// the existing "any route that isn't `/login`/`/register`" cases
/// exactly like [AppRoutes.home] does — only the route table itself
/// (see [buildAppRouter]) needed to grow, not this decision function.
String? resolveRedirect(AuthState authState, String matchedLocation) {
  final isAuthRoute =
      matchedLocation == AppRoutes.login ||
      matchedLocation == AppRoutes.register;

  return switch (authState) {
    AuthInitial() || AuthLoading() => null,
    AuthAuthenticated() => isAuthRoute ? AppRoutes.home : null,
    AuthUnauthenticated() ||
    AuthOperationFailure() => isAuthRoute ? null : AppRoutes.login,
  };
}

/// Builds the application's [GoRouter] instance.
///
/// [authBloc] is read both for the initial `redirect` evaluation
/// (`authBloc.state`) and to construct the [GoRouterRefreshStream] that
/// makes the router re-evaluate `redirect` on every subsequent
/// [AuthState] emission — not just on user-initiated navigation. This
/// closes gaps 3 and 4 of `ADR-001-authentication-infrastructure-deferral.md`.
///
/// [AppRoutes.profile] renders [ProfilePage] directly: unlike
/// [LoginPage]/[RegisterPage], it takes no constructor dependencies (it
/// reads the ambient `AuthBloc` via `BlocProvider`/`BlocBuilder`
/// instead), so no further wiring is needed here beyond the route
/// itself. This route was the one piece of gap 3's remediation still
/// missing when F-INF-T1's completeness was audited at the start of
/// Sprint 2 — `ProfilePage` had been fully built and unit-tested since
/// Sprint 1 (`F-A05-T1`) but was never actually reachable until now.
///
/// [registerUseCase] / [loginUseCase] are threaded through to
/// `RegisterPage`/`LoginPage` exactly as their own constructors already
/// require (see those classes' doc comments) — this router is the
/// "whichever ticket wires the application's route table" both pages
/// were written in anticipation of.
///
/// [getPublicRoomsUseCase] is threaded through to construct a fresh
/// [RoomBloc] directly in the `/` route's builder, immediately
/// dispatching [RoomEvent.fetchPublicRooms] — mirroring how `App`
/// dispatches `AuthEvent.checkStatusRequested` once on `AuthBloc`, but
/// scoped to this one route instead of the whole app (see `RoomBloc`'s
/// own doc for why). This replaces `PlaceholderHomePage` wholesale,
/// exactly as that file's own doc comment anticipated (F-R01-T3).
///
/// `RegisterPage.onNavigateToLogin`, `LoginPage.onNavigateToRegister`,
/// and both pages' `on*Succeeded` callbacks are wired to `context.go(...)`
/// here — `checkStatusRequested`/`AuthBloc` re-evaluation of the guard
/// after a successful login/register is handled implicitly by the
/// `GoRouterRefreshStream`, once `LoginCubit`/`RegisterCubit` themselves
/// eventually dispatch into `AuthBloc` (see `AuthEvent.loginRequested`'s
/// own doc comment on that still-open architectural question) — for now,
/// `context.go(AppRoutes.home)` after a successful login/register is a
/// direct, explicit navigation, not solely reliant on the guard, since
/// `LoginCubit`/`RegisterCubit` do not update `AuthBloc.state` themselves
/// yet.
GoRouter buildAppRouter({
  required AuthBloc authBloc,
  required RegisterUseCase registerUseCase,
  required LoginUseCase loginUseCase,
  required GetPublicRoomsUseCase getPublicRoomsUseCase,
}) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) =>
        resolveRedirect(authBloc.state, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => BlocProvider(
          create: (_) =>
              RoomBloc(getPublicRoomsUseCase: getPublicRoomsUseCase)
                ..add(const RoomEvent.fetchPublicRooms()),
          child: const HomePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => LoginPage(
          loginUseCase: loginUseCase,
          onLoginSucceeded: () => context.go(AppRoutes.home),
          onNavigateToRegister: () => context.go(AppRoutes.register),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => RegisterPage(
          registerUseCase: registerUseCase,
          onRegistrationSucceeded: () => context.go(AppRoutes.home),
          onNavigateToLogin: () => context.go(AppRoutes.login),
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfilePage(),
      ),
    ],
  );
}
