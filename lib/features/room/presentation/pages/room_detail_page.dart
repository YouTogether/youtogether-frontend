import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../video_sync/domain/usecases/get_current_playback_state_usecase.dart';
import '../../../video_sync/domain/usecases/get_video_session_usecase.dart';
import '../../../video_sync/domain/usecases/subscribe_to_playback_state_usecase.dart';
import '../../../video_sync/domain/usecases/update_playback_state_usecase.dart';
import '../../../video_sync/presentation/bloc/video_sync_bloc.dart';
import '../../../video_sync/presentation/bloc/video_sync_event.dart';
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

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated
        ? authState.user.id
        : '';

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
            getVideoSessionUseCase: getVideoSessionUseCase,
            getCurrentPlaybackStateUseCase: getCurrentPlaybackStateUseCase,
            subscribeToPlaybackStateUseCase: subscribeToPlaybackStateUseCase,
            updatePlaybackStateUseCase: updatePlaybackStateUseCase,
          )..add(const VideoSyncEvent.sessionJoined()),
        ),
      ],
      child: RoomDetailView(roomId: roomId),
    );
  }
}
