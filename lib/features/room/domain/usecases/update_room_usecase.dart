import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/room_entity.dart';
import '../repositories/i_room_repository.dart';
import 'update_room_params.dart';

/// Use case for updating a room's name and/or description.
///
/// Extends `UseCase<RoomEntity, UpdateRoomParams>`. Contains no business
/// logic beyond unpacking [UpdateRoomParams] into the named-parameter
/// call expected by `IRoomRepository.updateRoom()` and returning its
/// result unchanged — mirroring `CreateRoomUseCase` and the backend's
/// own `UpdateRoomUseCase`.
///
/// Ownership authorization is deliberately **not** this use case's
/// concern: enforcement is server-side (`OwnershipGuard`), and the
/// client additionally hides the edit action from non-owners
/// as defence in depth, not as the source of truth. A
/// request that somehow still reaches this use case for a non-owner
/// resolves to `Left(AuthFailure)`, per this feature's acceptance
/// criteria.
///
/// @see IRoomRepository.updateRoom — the delegated port method
/// @see UpdateRoomParams — the input value object
class UpdateRoomUseCase extends UseCase<RoomEntity, UpdateRoomParams> {
  UpdateRoomUseCase(this._roomRepository);

  final IRoomRepository _roomRepository;

  @override
  Future<Either<Failure, RoomEntity>> call(UpdateRoomParams params) {
    return _roomRepository.updateRoom(
      roomId: params.roomId,
      name: params.name,
      description: params.description,
    );
  }
}
