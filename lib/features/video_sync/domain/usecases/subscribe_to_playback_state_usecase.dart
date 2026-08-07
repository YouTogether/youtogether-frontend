import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/stream_usecase.dart';
import '../entities/video_session_entity.dart';
import '../repositories/i_video_sync_repository.dart';

/// Use case for subscribing to live playback state updates.
///
/// Extends `StreamUseCase<VideoSessionEntity, String>` — the input is
/// simply the room id, mirroring `GetRoomByIdUseCase`'s no-dedicated-
/// Params-wrapper convention. Contains no business logic beyond
/// delegating to `IVideoSyncRepository.subscribeToPlaybackState()` and
/// returning its stream unchanged.
///
/// Primary consumer: `VideoSyncBloc.subscribe`, which chains
/// this after an initial `GetCurrentPlaybackStateUseCase` fetch — see
/// that use case's own doc comment for why the two are kept
/// as separate use cases rather than one that does both.
///
/// @see IVideoSyncRepository.subscribeToPlaybackState — the delegated port method
class SubscribeToPlaybackStateUseCase
    extends StreamUseCase<VideoSessionEntity, String> {
  SubscribeToPlaybackStateUseCase(this._videoSyncRepository);

  final IVideoSyncRepository _videoSyncRepository;

  @override
  Stream<Either<Failure, VideoSessionEntity>> call(String roomId) {
    return _videoSyncRepository.subscribeToPlaybackState(roomId: roomId);
  }
}
