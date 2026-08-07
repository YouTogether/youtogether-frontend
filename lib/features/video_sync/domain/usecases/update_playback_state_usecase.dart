import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/i_video_sync_repository.dart';
import 'update_playback_state_params.dart';

/// Use case for writing a new playback state (leader only).
///
/// Extends `UseCase<void, UpdatePlaybackStateParams>`. Contains no
/// business logic beyond unpacking [UpdatePlaybackStateParams] into the
/// named-parameter call expected by
/// `IVideoSyncRepository.updatePlaybackState()` and returning its
/// result unchanged — mirroring `UpdateRoomUseCase`.
///
/// The leader-only check is deliberately **not** this use case's
/// concern: by the time `VideoSyncBloc` calls this use case, its own
/// `isLeader` guard has already prevented the call for a non-leader
/// (see F-V02's Acceptance Criteria), and Firebase security rules are
/// the actual server-side enforcement — mirroring how
/// `UpdateRoomUseCase` defers ownership authorization to
/// `OwnershipGuard`.
///
/// @see IVideoSyncRepository.updatePlaybackState — the delegated port method
/// @see UpdatePlaybackStateParams — the input value object
class UpdatePlaybackStateUseCase
    extends UseCase<void, UpdatePlaybackStateParams> {
  UpdatePlaybackStateUseCase(this._videoSyncRepository);

  final IVideoSyncRepository _videoSyncRepository;

  @override
  Future<Either<Failure, void>> call(UpdatePlaybackStateParams params) {
    return _videoSyncRepository.updatePlaybackState(
      roomId: params.roomId,
      isPlaying: params.isPlaying,
      position: params.position,
    );
  }
}
