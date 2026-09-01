import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:youtogether/features/video_sync/domain/usecases/create_video_session_usecase.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../video_sync/domain/usecases/get_current_playback_state_usecase.dart';
import '../../../video_sync/domain/usecases/get_video_session_usecase.dart';
import '../../../video_sync/domain/usecases/subscribe_to_playback_state_usecase.dart';
import '../../../video_sync/domain/usecases/update_playback_state_usecase.dart';
import '../../../video_sync/domain/usecases/create_sync_barrier_usecase.dart';
import '../../../video_sync/domain/usecases/delete_sync_barrier_usecase.dart';
import '../../../video_sync/domain/usecases/increment_ready_count_usecase.dart';
import '../../../video_sync/domain/usecases/remove_presence_usecase.dart';
import '../../../video_sync/domain/usecases/set_all_ready_usecase.dart';
import '../../../video_sync/domain/usecases/subscribe_to_sync_barrier_usecase.dart';
import '../../../video_sync/domain/usecases/update_barrier_total_count_usecase.dart';
import '../../../video_sync/domain/usecases/set_presence_usecase.dart';
import '../../../video_sync/domain/usecases/subscribe_to_presence_usecase.dart';
import '../../../video_sync/presentation/bloc/video_sync_bloc.dart';
import '../../../video_sync/presentation/bloc/video_sync_event.dart';
import '../../../video_sync/presentation/cubit/add_video_cubit.dart';
import '../../../video_sync/presentation/cubit/presence_cubit.dart';
import '../../domain/usecases/delete_room_usecase.dart';
import '../../domain/usecases/get_room_by_id_usecase.dart';
import '../../domain/usecases/join_room_usecase.dart';
import '../../domain/usecases/leave_room_usecase.dart';
import '../cubit/delete_room_cubit.dart';
import '../cubit/join_room_cubit.dart';
import '../cubit/leave_room_cubit.dart';
import '../cubit/room_detail_cubit.dart';
import 'room_detail_view.dart';

/// Route-level widget for the room detail screen (`AppRoutes.roomDetail`,
/// `/rooms/:id`).
///
/// Creates a fresh [RoomDetailCubit] per visit and immediately
/// dispatches [RoomDetailCubit.fetchRoom], mirroring how `AppRouter`'s
/// `/` route constructs a fresh `RoomBloc` for `HomePage`. Also
/// provides a fresh [DeleteRoomCubit], [JoinRoomCubit], [LeaveRoomCubit]
/// (unchanged from prior sprints), and — new for F-V03-T2 — a fresh
/// [VideoSyncBloc], immediately dispatching
/// [VideoSyncEvent.sessionJoined].
///
/// [VideoSyncBloc] needs [AuthBloc]'s current user id (`currentUserId`)
/// to derive `isLeader` — read once, synchronously, from the ancestor
/// [AuthBloc] already provided above this page in the widget tree
/// (`AppRouter`'s root `BlocProvider<AuthBloc>`), the same way
/// `RoomDetailView` itself already reads [AuthBloc] for the owner
/// badge. An unauthenticated visitor cannot reach this page at all in
/// practice (anonymous/guest join always resolves to *some*
/// authenticated identity per `decision-anonymous-room-join.md`), but
/// if `AuthState` is ever `unauthenticated` here regardless, `''` is
/// used: it will simply never equal a real `leaderId`, so `isLeader`
/// safely resolves to `false` rather than throwing.
class RoomDetailPage extends StatelessWidget {
  const RoomDetailPage({
    required this.roomId,
    required this.getRoomByIdUseCase,
    required this.deleteRoomUseCase,
    required this.joinRoomUseCase,
    required this.leaveRoomUseCase,
    required this.getVideoSessionUseCase,
    required this.getCurrentPlaybackStateUseCase,
    required this.subscribeToPlaybackStateUseCase,
    required this.updatePlaybackStateUseCase,
    required this.createSyncBarrierUseCase,
    required this.subscribeToSyncBarrierUseCase,
    required this.incrementReadyCountUseCase,
    required this.updateBarrierTotalCountUseCase,
    required this.setAllReadyUseCase,
    required this.deleteSyncBarrierUseCase,
    required this.setPresenceUseCase,
    required this.removePresenceUseCase,
    required this.subscribeToPresenceUseCase,
    required this.createVideoSessionUseCase,
    super.key,
  });

  final String roomId;
  final GetRoomByIdUseCase getRoomByIdUseCase;
  final DeleteRoomUseCase deleteRoomUseCase;
  final JoinRoomUseCase joinRoomUseCase;
  final LeaveRoomUseCase leaveRoomUseCase;
  final GetVideoSessionUseCase getVideoSessionUseCase;
  final GetCurrentPlaybackStateUseCase getCurrentPlaybackStateUseCase;
  final SubscribeToPlaybackStateUseCase subscribeToPlaybackStateUseCase;
  final UpdatePlaybackStateUseCase updatePlaybackStateUseCase;

  /// Ready-gate orchestration use cases, required by [VideoSyncBloc].
  final CreateSyncBarrierUseCase createSyncBarrierUseCase;
  final SubscribeToSyncBarrierUseCase subscribeToSyncBarrierUseCase;
  final IncrementReadyCountUseCase incrementReadyCountUseCase;
  final UpdateBarrierTotalCountUseCase updateBarrierTotalCountUseCase;
  final SetAllReadyUseCase setAllReadyUseCase;
  final DeleteSyncBarrierUseCase deleteSyncBarrierUseCase;
  final SetPresenceUseCase setPresenceUseCase;
  final RemovePresenceUseCase removePresenceUseCase;
  final SubscribeToPresenceUseCase subscribeToPresenceUseCase;
  final CreateVideoSessionUseCase createVideoSessionUseCase;

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated
        ? authState.user.id
        : '';
    // UserEntity exposes `displayName`, not `username` — the backend's
    // `username` wire field is renamed at the data-layer boundary (see
    // UserEntity's own class doc). PresenceModel writes it back out as
    // `username` in Firebase, so the wire vocabulary is preserved
    // there without the domain having to carry the backend's term.
    final currentUsername = authState is AuthAuthenticated
        ? authState.user.displayName
        : 'Guest';
    // Derived from the same condition as the username fallback above,
    // deliberately: 'Guest' *is* the anonymous case, and writing that
    // name without the flag would make an account-less viewer
    // indistinguishable from a registered user who happens to be called
    // Guest.
    final isAnonymous = authState is! AuthAuthenticated;

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => RoomDetailCubit(getRoomByIdUseCase)..fetchRoom(roomId),
        ),
        BlocProvider(create: (_) => DeleteRoomCubit(deleteRoomUseCase)),
        BlocProvider(create: (_) => JoinRoomCubit(joinRoomUseCase)),
        BlocProvider(create: (_) => LeaveRoomCubit(leaveRoomUseCase)),
        BlocProvider(
          create: (_) => VideoSyncBloc(
            roomId: roomId,
            currentUserId: currentUserId,
            getRoomByIdUseCase: getRoomByIdUseCase,
            getVideoSessionUseCase: getVideoSessionUseCase,
            getCurrentPlaybackStateUseCase: getCurrentPlaybackStateUseCase,
            subscribeToPlaybackStateUseCase: subscribeToPlaybackStateUseCase,
            updatePlaybackStateUseCase: updatePlaybackStateUseCase,
            createSyncBarrierUseCase: createSyncBarrierUseCase,
            subscribeToSyncBarrierUseCase: subscribeToSyncBarrierUseCase,
            incrementReadyCountUseCase: incrementReadyCountUseCase,
            updateBarrierTotalCountUseCase: updateBarrierTotalCountUseCase,
            setAllReadyUseCase: setAllReadyUseCase,
            deleteSyncBarrierUseCase: deleteSyncBarrierUseCase,
            // Shared with PresenceCubit below — VideoSyncBloc reads it
            // only to size and resize the ready gate, PresenceCubit to
            // drive the participant list. Both observe the same node;
            // neither owns it.
            subscribeToPresenceUseCase: subscribeToPresenceUseCase,
          )..add(const VideoSyncEvent.sessionJoined()),
        ),
        // Presence is scoped to this provider's lifetime, which is
        // exactly the lifetime of the page carrying the player. Entering
        // the session on creation and PresenceCubit.close() clearing it
        // on disposal is what makes participation follow the page rather
        // than the leave button — see PresenceCubit's own doc comment.
        BlocProvider(
          create: (_) => PresenceCubit(
            roomId: roomId,
            userId: currentUserId,
            username: currentUsername,
            isAnonymous: isAnonymous,
            setPresenceUseCase: setPresenceUseCase,
            removePresenceUseCase: removePresenceUseCase,
            subscribeToPresenceUseCase: subscribeToPresenceUseCase,
          )..enterSession(),
        ),
        BlocProvider<AddVideoCubit>(
          create: (_) => AddVideoCubit(createVideoSessionUseCase),
        ),
      ],
      child: RoomDetailView(roomId: roomId),
    );
  }
}
