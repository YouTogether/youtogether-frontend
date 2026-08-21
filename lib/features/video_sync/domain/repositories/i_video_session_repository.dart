import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../entities/video_session_metadata_entity.dart';

/// Domain port for the Video Synchronisation bounded context's REST
/// (NestJS backend) access — the metadata side, backed by.
///
/// Named distinctly from `IVideoSyncRepository` (the Firebase-backed
/// port for live playback state): the two talk to entirely different
/// backends and can fail in different ways ([ServerFailure]/
/// [NetworkFailure]/[NotFoundFailure] here, [FirebaseFailure] there) —
/// see `IVideoSyncRepository`'s own doc comment for that split's
/// rationale, which applies symmetrically here.
///
/// @see VideoSessionRepositoryImpl — the data-layer implementation
/// @see GetVideoSessionUseCase — primary consumer
abstract class IVideoSessionRepository {
  /// Fetches the room's current video session metadata via
  /// `GET /rooms/:id/video-session`.
  ///
  /// - `Left(NotFoundFailure)` — the room does not exist, or exists but
  ///   has no video session yet.
  Future<Either<Failure, VideoSessionMetadataEntity>> getByRoomId({
    required String roomId,
  });
}
