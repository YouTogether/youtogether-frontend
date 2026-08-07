import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/i_presence_repository.dart';
import 'remove_presence_params.dart';

/// Use case for clearing a participant's presence node on a graceful
/// room exit.
///
/// Extends `UseCase<void, RemovePresenceParams>`. Contains no business
/// logic beyond unpacking [RemovePresenceParams] into the
/// named-parameter call expected by
/// `IPresenceRepository.removePresence()` — mirroring
/// `SetPresenceUseCase`.
///
/// This is the explicit-exit counterpart to the `onDisconnect` handler
/// registered by `PresenceRemoteDataSourceImpl`: both paths
/// converge on the same node being cleared, but this use case handles
/// the case where the user navigates away normally, while
/// `onDisconnect` covers app crashes and network loss (per this
/// feature's own Acceptance Criteria: "user's own presence cleaned up
/// on leave or app close").
///
/// @see IPresenceRepository.removePresence — the delegated port method
/// @see RemovePresenceParams — the input value object
class RemovePresenceUseCase extends UseCase<void, RemovePresenceParams> {
  RemovePresenceUseCase(this._presenceRepository);

  final IPresenceRepository _presenceRepository;

  @override
  Future<Either<Failure, void>> call(RemovePresenceParams params) {
    return _presenceRepository.removePresence(
      roomId: params.roomId,
      userId: params.userId,
    );
  }
}
