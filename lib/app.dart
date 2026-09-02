import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:youtogether/features/video_sync/domain/usecases/create_sync_barrier_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/create_video_session_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/delete_sync_barrier_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/get_current_playback_state_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/get_video_session_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/increment_ready_count_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/remove_presence_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/set_all_ready_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/set_presence_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/subscribe_to_playback_state_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/subscribe_to_presence_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/subscribe_to_sync_barrier_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/update_barrier_total_count_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/update_playback_state_usecase.dart';

import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/cubit/firebase_session_cubit.dart';
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
  late final FirebaseSessionCubit _firebaseSessionCubit;

  @override
  void initState() {
    super.initState();

    _authBloc = sl<AuthBloc>()..add(const AuthEvent.checkStatusRequested());
    _firebaseSessionCubit = sl<FirebaseSessionCubit>();
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
      getVideoSessionUseCase: sl<GetVideoSessionUseCase>(),
      getCurrentPlaybackStateUseCase: sl<GetCurrentPlaybackStateUseCase>(),
      subscribeToPlaybackStateUseCase: sl<SubscribeToPlaybackStateUseCase>(),
      updatePlaybackStateUseCase: sl<UpdatePlaybackStateUseCase>(),
      createSyncBarrierUseCase: sl<CreateSyncBarrierUseCase>(),
      subscribeToSyncBarrierUseCase: sl<SubscribeToSyncBarrierUseCase>(),
      incrementReadyCountUseCase: sl<IncrementReadyCountUseCase>(),
      updateBarrierTotalCountUseCase: sl<UpdateBarrierTotalCountUseCase>(),
      setAllReadyUseCase: sl<SetAllReadyUseCase>(),
      deleteSyncBarrierUseCase: sl<DeleteSyncBarrierUseCase>(),
      setPresenceUseCase: sl<SetPresenceUseCase>(),
      removePresenceUseCase: sl<RemovePresenceUseCase>(),
      subscribeToPresenceUseCase: sl<SubscribeToPresenceUseCase>(),
      createVideoSessionUseCase: sl<CreateVideoSessionUseCase>(),
    );
  }

  @override
  void dispose() {
    _firebaseSessionCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authBloc),
        BlocProvider.value(value: _firebaseSessionCubit),
      ],
      // Establishing the Firebase session on sign-in rather than waiting
      // for a room means the credential is already in place by the time
      // one is opened. Signing out releases it immediately: leaving a
      // live named credential on the device of a user who has just
      // logged out would be a real exposure, and re-establishing it
      // anonymously here would do exactly that.
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          switch (state) {
            case AuthAuthenticated(:final user):
              _firebaseSessionCubit.synchronise(appUserId: user.id);
            case AuthUnauthenticated():
              _firebaseSessionCubit.release();
            default:
              break;
          }
        },
        child: MaterialApp.router(
          routerConfig: _router,
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
  }
}
