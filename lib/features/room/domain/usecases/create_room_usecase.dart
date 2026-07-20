import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/room_entity.dart';
import '../repositories/i_room_repository.dart';
import 'create_room_params.dart';

/// Use case for room creation.
///
/// Extends `UseCase<RoomEntity, CreateRoomParams>`. Contains no business
/// logic beyond unpacking [CreateRoomParams] into the named-parameter
/// call expected by `IRoomRepository.createRoom()` and returning its
/// result unchanged — mirroring `RegisterUseCase` and the backend's own
/// `CreateRoomUseCase`, both of which purely delegate without adding
/// logic of their own.
///
/// Client-side validation (non-empty name, 100-character maximum) is
/// the responsibility of the room creation form/cubit, not
/// this use case or [CreateRoomParams] — mirroring how `RegisterParams`
/// documents the identical boundary for email/password validation.
///
/// @see IRoomRepository.createRoom — the delegated port method
/// @see CreateRoomParams — the input value object
class CreateRoomUseCase extends UseCase<RoomEntity, CreateRoomParams> {
  CreateRoomUseCase(this._roomRepository);

  final IRoomRepository _roomRepository;

  @override
  Future<Either<Failure, RoomEntity>> call(CreateRoomParams params) {
    return _roomRepository.createRoom(
      name: params.name,
      description: params.description,
      isPublic: params.isPublic,
    );
  }
}
