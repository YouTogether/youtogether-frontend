import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/room_entity.dart';
import '../../domain/usecases/create_room_usecase.dart';
import '../cubit/create_room_cubit.dart';
import 'create_room_view.dart';

/// Route-level widget for the room creation screen.
///
/// Creates the [CreateRoomCubit] backing this screen from the
/// constructor-injected [CreateRoomUseCase] — mirroring
/// `RegisterPage`/`LoginPage` exactly.
///
/// [onRoomCreated] is exposed as a callback rather than a hardcoded
/// navigation for the same reason those pages expose `on*Succeeded`:
/// whichever ticket wires the application's route table supplies the
/// real behaviour. Concretely, at the point this task lands, that
/// behaviour is `context.go(AppRoutes.home)` — there is no "room detail
/// view" page in this codebase yet for a created room to navigate to
/// (this task's own Definition of Done says "navigate to the room
/// detail view", but no ticket in the backlog actually builds
/// that page; all *assume* one exists
/// to attach their edit/delete/leave actions to). Navigating home
/// re-triggers `RoomEvent.fetchPublicRooms()` for free, since
/// `AppRouter`'s `/` route constructs a fresh `RoomBloc` on every visit
/// — which also satisfies this task's "refresh the room list"
/// requirement without reaching into the previous `RoomBloc` instance.
///
/// Flagged here rather than silently worked around: a dedicated
/// backlog item for a `RoomDetailPage` is a genuine gap worth adding
/// before next task begins.
class CreateRoomPage extends StatelessWidget {
  const CreateRoomPage({
    required this.createRoomUseCase,
    required this.onRoomCreated,
    super.key,
  });

  final CreateRoomUseCase createRoomUseCase;
  final ValueChanged<RoomEntity> onRoomCreated;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CreateRoomCubit(createRoomUseCase),
      child: CreateRoomView(onRoomCreated: onRoomCreated),
    );
  }
}
