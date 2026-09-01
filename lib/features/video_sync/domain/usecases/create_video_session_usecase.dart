import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/video_session_metadata_entity.dart';
import '../repositories/i_video_session_repository.dart';
import 'create_video_session_params.dart';

/// Use case for creating a room's video session via
/// `POST /rooms/:id/video-session`.
///
/// Extends `UseCase<VideoSessionMetadataEntity, CreateVideoSessionParams>`.
/// Contains no business logic beyond unpacking
/// [CreateVideoSessionParams] into the named-parameter call expected by
/// `IVideoSessionRepository.create()` and returning its result
/// unchanged — mirroring `UpdatePlaybackStateUseCase` and
/// `SetPresenceUseCase`.
///
/// Format validation is deliberately **not** this use case's concern:
/// by the time it runs, `YoutubeVideoId.parse` has already rejected
/// anything malformed, and the backend re-validates independently.
/// Ownership authorization is likewise not checked here — `OwnershipGuard`
/// is the enforcement point, and `RoomVideoSection` hides the form from
/// non-owners as defence in depth, not as the source of truth. A request
/// that somehow still reaches this use case for a non-owner resolves to
/// a `Left` failure carrying the backend's 403.
///
/// The returned [VideoSessionMetadataEntity] carries `durationSeconds`,
/// which `VideoSyncBloc` needs to bound seek targets. It is returned
/// rather than discarded so that the caller can dispatch
/// `VideoSyncEvent.sessionJoined` immediately, without a second round
/// trip: the backend has already written the room's `playback_state`
/// node by the time this resolves, so the subsequent Firebase
/// read is guaranteed to find it.
///
/// @see IVideoSessionRepository.create — the delegated port method
/// @see CreateVideoSessionParams — the input value object
class CreateVideoSessionUseCase
    extends UseCase<VideoSessionMetadataEntity, CreateVideoSessionParams> {
  CreateVideoSessionUseCase(this._videoSessionRepository);

  final IVideoSessionRepository _videoSessionRepository;

  @override
  Future<Either<Failure, VideoSessionMetadataEntity>> call(
    CreateVideoSessionParams params,
  ) {
    return _videoSessionRepository.create(
      roomId: params.roomId,
      youtubeVideoId: params.youtubeVideoId.value,
    );
  }
}
