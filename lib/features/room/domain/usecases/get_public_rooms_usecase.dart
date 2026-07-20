import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/room_entity.dart';
import '../repositories/i_room_repository.dart';

/// Use case for listing every active, public room.
///
/// Extends `UseCase<List<RoomEntity>, NoParams>`. Delegates entirely to
/// `IRoomRepository.getPublicRooms()`, which fetches every active,
/// public room together with its current active member count.
///
/// Takes no parameters: listing public rooms requires no caller input
/// beyond the implicit "public, active" filter, which is not a
/// user-supplied value — mirroring the backend's own
/// `GetPublicRoomsUseCase`, which is likewise parameterless.
///
/// Primary consumer: `RoomBloc`, on initialization and on
/// pull-to-refresh.
///
/// @see IRoomRepository.getPublicRooms — the delegated port method
class GetPublicRoomsUseCase extends UseCase<List<RoomEntity>, NoParams> {
  GetPublicRoomsUseCase(this._roomRepository);

  final IRoomRepository _roomRepository;

  @override
  Future<Either<Failure, List<RoomEntity>>> call(NoParams params) {
    return _roomRepository.getPublicRooms();
  }
}
