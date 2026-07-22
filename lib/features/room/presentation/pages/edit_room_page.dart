import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/room_entity.dart';
import '../../domain/usecases/update_room_usecase.dart';
import '../cubit/edit_room_cubit.dart';
import 'edit_room_view.dart';

/// Route-level widget for the room edit screen
/// (`AppRoutes.editRoomPattern`, `/rooms/:id/edit`).
///
/// [initialRoom] is passed via `GoRouterState.extra` from
/// `RoomDetailPage` (already holding the loaded room) rather than
/// re-fetched via `GetRoomByIdUseCase` — this screen is only ever
/// reached from the detail view's edit button, which already has the
/// current data in hand; fetching it again would be a redundant round
/// trip for data already on screen.
///
/// [onRoomUpdated] is exposed as a callback rather than a hardcoded
/// navigation, mirroring `CreateRoomPage`/`RegisterPage`/`LoginPage`.
/// Wired in `AppRouter` to navigate back to the room detail view
/// (`context.go(AppRoutes.roomDetail(room.id))`), which constructs a
/// fresh `RoomDetailCubit` and re-fetches — satisfying this ticket's
/// "room detail refreshes on success" requirement the same way
/// `CreateRoomPage`'s wiring satisfies its own refresh requirement.
class EditRoomPage extends StatelessWidget {
  const EditRoomPage({
    required this.initialRoom,
    required this.updateRoomUseCase,
    required this.onRoomUpdated,
    super.key,
  });

  final RoomEntity initialRoom;
  final UpdateRoomUseCase updateRoomUseCase;
  final ValueChanged<RoomEntity> onRoomUpdated;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => EditRoomCubit(updateRoomUseCase),
      child: EditRoomView(
        initialRoom: initialRoom,
        onRoomUpdated: onRoomUpdated,
      ),
    );
  }
}
