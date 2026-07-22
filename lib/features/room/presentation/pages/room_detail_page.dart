import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_room_by_id_usecase.dart';
import '../cubit/room_detail_cubit.dart';
import 'room_detail_view.dart';

/// Route-level widget for the room detail screen (`AppRoutes.roomDetail`,
/// `/rooms/:id`).
///
/// Closes the backlog gap identified during `F-R02-T3` and tracked in
/// `sprint-2-room-planning.md` §5 ("Build RoomDetailPage") — the
/// attachment point `F-R03-T3` (edit), `F-R04-T3` (delete), and
/// `F-R06-T3` (join/leave) all assumed already existed.
///
/// Creates a fresh [RoomDetailCubit] per visit and immediately
/// dispatches [RoomDetailCubit.fetchRoom], mirroring how `AppRouter`'s
/// `/` route constructs a fresh `RoomBloc` for `HomePage`.
class RoomDetailPage extends StatelessWidget {
  const RoomDetailPage({
    required this.roomId,
    required this.getRoomByIdUseCase,
    super.key,
  });

  final String roomId;
  final GetRoomByIdUseCase getRoomByIdUseCase;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RoomDetailCubit(getRoomByIdUseCase)..fetchRoom(roomId),
      child: RoomDetailView(roomId: roomId),
    );
  }
}
