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

  /// Creates the room's video session via
  /// `POST /rooms/:id/video-session`, returning the metadata the
  /// backend resolved and cached.
  ///
  /// Owner-only: the backend enforces this with `OwnershipGuard`, and
  /// the same call also writes the room's `playback_state` node in
  /// Firebase, with `leader_id` taken from the room's persisted owner
  /// (B-V03). A caller that observes a `Right` here can therefore
  /// assume the real-time node exists, and dispatch
  /// `VideoSyncEvent.sessionJoined` without waiting for anything else.
  ///
  /// Adding a video to a room that already has one is allowed and
  /// replaces the current session: `video_sessions` is append-only and
  /// the backend returns the most recent row, while the Firebase node
  /// is overwritten wholesale so every connected viewer re-synchronises.
  ///
  /// Failure mapping, following `RoomRepositoryImpl.updateRoom`'s
  /// existing conventions for the same status codes:
  /// - `Left(NotFoundFailure)` — the room does not exist or was deleted.
  /// - A 403 (the authenticated user is not the room owner) maps to the
  ///   same failure `updateRoom` already produces for a non-owner.
  /// - Anything else — a malformed id the backend rejected, an
  ///   unreachable YouTube Data API, or a failed Realtime Database
  ///   write — surfaces as [ServerFailure] carrying the status code, so
  ///   the form can distinguish "this video does not exist" (400) from
  ///   "try again shortly" (502).
  /// - `Left(NetworkFailure)` — the request never reached the backend.
  ///
  /// [youtubeVideoId] is an already-validated 11-character id; parsing
  /// belongs to `YoutubeVideoId`, which the use case unwraps before
  /// reaching this port. The port takes a `String` rather than the
  /// value object so that the data layer has no dependency on a domain
  /// value object it would only immediately unwrap.
  Future<Either<Failure, VideoSessionMetadataEntity>> create({
    required String roomId,
    required String youtubeVideoId,
  });
}
