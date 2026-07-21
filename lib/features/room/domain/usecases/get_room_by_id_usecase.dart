import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/room_entity.dart';
import '../repositories/i_room_repository.dart';

/// Use case for retrieving a single room's details.
///
/// Extends `UseCase<RoomEntity, String>`: the input is simply the
/// room's id, mirroring `DeleteRoomUseCase`/`JoinRoomUseCase`/
/// `LeaveRoomUseCase` — no dedicated Params wrapper.
///
/// Identified as a missing frontend prerequisite while implementing
/// room creation form: that task's Definition of Done
/// calls for "navigate to the room detail view" on success, but no
/// ticket built the page or the use case backing it.
///
/// Contains no business logic beyond delegating to
/// `IRoomRepository.getRoomById()` and returning its result unchanged.
///
/// @see IRoomRepository.getRoomById — the delegated port method
class GetRoomByIdUseCase extends UseCase<RoomEntity, String> {
  GetRoomByIdUseCase(this._roomRepository);

  final IRoomRepository _roomRepository;

  @override
  Future<Either<Failure, RoomEntity>> call(String roomId) {
    return _roomRepository.getRoomById(roomId: roomId);
  }
}
