import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/video_session_entity.dart';
import '../repositories/i_video_sync_repository.dart';

/// Use case for performing a single read of the current playback state.
///
/// Extends `UseCase<VideoSessionEntity, String>` — the input is simply
/// the room id, mirroring `GetRoomByIdUseCase`. Contains no business
/// logic beyond delegating to
/// `IVideoSyncRepository.getCurrentPlaybackState()`.
///
/// Kept deliberately separate from
/// `SubscribeToPlaybackStateUseCase` rather than folded into a single
/// "subscribe with initial value" use case: `VideoSyncBloc.subscribe`
/// needs the two calls sequenced explicitly (fetch once,
/// seek the player, *then* open the stream for ongoing updates) per
/// this ticket's own Acceptance Criteria — collapsing them into one use
/// case would hide that sequencing inside the domain layer instead of
/// making it an explicit, testable step in the bloc.
///
/// Primary consumer: `VideoSyncBloc.subscribe`, on room entry.
///
/// @see IVideoSyncRepository.getCurrentPlaybackState — the delegated port method
class GetCurrentPlaybackStateUseCase
    extends UseCase<VideoSessionEntity, String> {
  GetCurrentPlaybackStateUseCase(this._videoSyncRepository);

  final IVideoSyncRepository _videoSyncRepository;

  @override
  Future<Either<Failure, VideoSessionEntity>> call(String roomId) {
    return _videoSyncRepository.getCurrentPlaybackState(roomId: roomId);
  }
}
