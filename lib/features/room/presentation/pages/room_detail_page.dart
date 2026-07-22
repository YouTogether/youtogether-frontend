import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/delete_room_usecase.dart';
import '../../domain/usecases/get_room_by_id_usecase.dart';
import '../../domain/usecases/join_room_usecase.dart';
import '../cubit/delete_room_cubit.dart';
import '../cubit/join_room_cubit.dart';
import '../cubit/room_detail_cubit.dart';
import 'room_detail_view.dart';

/// Route-level widget for the room detail screen (`AppRoutes.roomDetail`,
/// `/rooms/:id`).
///
/// Creates a fresh [RoomDetailCubit] per visit and immediately
/// dispatches [RoomDetailCubit.fetchRoom], mirroring how `AppRouter`'s
/// `/` route constructs a fresh `RoomBloc` for `HomePage`. Also
/// provides a fresh [DeleteRoomCubit], read by
/// `RoomDetailView`'s owner-only delete button and confirmation
/// dialog.
class RoomDetailPage extends StatelessWidget {
  const RoomDetailPage({
    required this.roomId,
    required this.getRoomByIdUseCase,
    required this.deleteRoomUseCase,
    required this.joinRoomUseCase,
    super.key,
  });

  final String roomId;
  final GetRoomByIdUseCase getRoomByIdUseCase;
  final DeleteRoomUseCase deleteRoomUseCase;
  final JoinRoomUseCase joinRoomUseCase;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => RoomDetailCubit(getRoomByIdUseCase)..fetchRoom(roomId),
        ),
        BlocProvider(create: (_) => DeleteRoomCubit(deleteRoomUseCase)),
        BlocProvider(create: (_) => JoinRoomCubit(joinRoomUseCase)),
      ],
      child: RoomDetailView(roomId: roomId),
    );
  }
}
