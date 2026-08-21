import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/video_session_metadata_entity.dart';
import '../repositories/i_video_session_repository.dart';

/// Use case for fetching a room's video session metadata via
/// `GET /rooms/:id/video-session`.
///
/// Extends `UseCase<VideoSessionMetadataEntity, String>` — the input is
/// simply the room id, mirroring `GetRoomByIdUseCase` and
/// `GetCurrentPlaybackStateUseCase`. Contains no business logic beyond
/// delegation.
///
/// Primary consumer: `VideoSyncBloc.sessionJoined`, which
/// calls this once, before `GetCurrentPlaybackStateUseCase` and
/// `subscribeToPlaybackState` — see that handler's own doc comment for
/// the full sequencing and why `durationSeconds` specifically has to
/// come from here rather than Firebase.
///
/// @see IVideoSessionRepository.getByRoomId — the delegated port method
class GetVideoSessionUseCase
    extends UseCase<VideoSessionMetadataEntity, String> {
  GetVideoSessionUseCase(this._videoSessionRepository);

  final IVideoSessionRepository _videoSessionRepository;

  @override
  Future<Either<Failure, VideoSessionMetadataEntity>> call(String roomId) {
    return _videoSessionRepository.getByRoomId(roomId: roomId);
  }
}
