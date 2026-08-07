import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/i_presence_repository.dart';
import 'set_presence_params.dart';

/// Use case for writing a participant's presence node on room entry.
///
/// Extends `UseCase<void, SetPresenceParams>`. Contains no business
/// logic beyond unpacking [SetPresenceParams] into the named-parameter
/// call expected by `IPresenceRepository.setPresence()` — mirroring
/// `UpdatePlaybackStateUseCase`.
///
/// Registering the Firebase `onDisconnect` handler is deliberately
/// **not** this use case's concern: it is a data-layer detail of
/// `PresenceRemoteDataSourceImpl`, invisible at this
/// abstraction level, mirroring how this use case has no knowledge of
/// Firebase at all.
///
/// @see IPresenceRepository.setPresence — the delegated port method
/// @see SetPresenceParams — the input value object
class SetPresenceUseCase extends UseCase<void, SetPresenceParams> {
  SetPresenceUseCase(this._presenceRepository);

  final IPresenceRepository _presenceRepository;

  @override
  Future<Either<Failure, void>> call(SetPresenceParams params) {
    return _presenceRepository.setPresence(
      roomId: params.roomId,
      userId: params.userId,
      username: params.username,
    );
  }
}
