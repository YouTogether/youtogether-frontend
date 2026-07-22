import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'l10n/generated/app_localizations.dart';
import 'core/di/injection_container.dart';
import 'core/router/app_router.dart';
import 'features/auth/domain/usecases/login_usecase.dart';
import 'features/auth/domain/usecases/register_usecase.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/room/domain/usecases/create_room_usecase.dart';
import 'features/room/domain/usecases/delete_room_usecase.dart';
import 'features/room/domain/usecases/get_public_rooms_usecase.dart';
import 'features/room/domain/usecases/get_room_by_id_usecase.dart';
import 'features/room/domain/usecases/join_room_usecase.dart';
import 'features/room/domain/usecases/leave_room_usecase.dart';
import 'features/room/domain/usecases/update_room_usecase.dart';

/// Application root widget.
///
/// Closes gap 2 of `ADR-001-authentication-infrastructure-deferral`:
/// before this widget existed, `AuthBloc` was fully implemented and
/// tested but never instantiated in a running app, and nothing
/// dispatched `AuthEvent.checkStatusRequested()` on cold start.
///
/// A [StatefulWidget] rather than [StatelessWidget] specifically so
/// `checkStatusRequested` is dispatched exactly once, in [initState] —
/// not on every rebuild of this widget, which a stateless
/// `build()`-time dispatch could not guarantee.
///
/// Provides the single, app-wide [AuthBloc] instance (via [sl], the
/// `get_it` service locator from `injection_container.dart`) to the
/// whole widget tree, and builds the [GoRouter] instance (`AppRouter`)
/// that reads and reacts to it.
class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthBloc _authBloc;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    _authBloc = sl<AuthBloc>()..add(const AuthEvent.checkStatusRequested());

    _router = buildAppRouter(
      authBloc: _authBloc,
      registerUseCase: sl<RegisterUseCase>(),
      loginUseCase: sl<LoginUseCase>(),
      getPublicRoomsUseCase: sl<GetPublicRoomsUseCase>(),
      createRoomUseCase: sl<CreateRoomUseCase>(),
      getRoomByIdUseCase: sl<GetRoomByIdUseCase>(),
      updateRoomUseCase: sl<UpdateRoomUseCase>(),
      deleteRoomUseCase: sl<DeleteRoomUseCase>(),
      joinRoomUseCase: sl<JoinRoomUseCase>(),
      leaveRoomUseCase: sl<LeaveRoomUseCase>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authBloc,
      child: MaterialApp.router(
        routerConfig: _router,
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }
}
