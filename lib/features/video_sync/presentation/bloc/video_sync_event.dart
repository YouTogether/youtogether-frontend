import 'package:either_dart/either.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/sync_barrier_entity.dart';
import '../../domain/entities/video_session_entity.dart';

part 'video_sync_event.freezed.dart';

/// Event hierarchy for [VideoSyncBloc].
///
/// Declared `@freezed` as a sealed union, mirroring `RoomEvent`.
///
/// `sessionJoined`, `sessionUpdated`, and `retryRequested` are added
/// here — the previous revision of this file
/// documented these as deliberately deferred rather than declared
/// upfront unused; that reasoning still holds for events genuinely out
/// of scope, so they belong here now, not as placeholders.
@freezed
sealed class VideoSyncEvent with _$VideoSyncEvent {
  /// Dispatched once on room entry. Fetches the room's video session
  /// metadata (`GetVideoSessionUseCase`, `durationSeconds`), then the
  /// current Firebase playback state (`GetCurrentPlaybackStateUseCase`),
  /// derives `isLeader` by comparing the fetched `leaderId` to
  /// [ownerId], and opens the live subscription
  /// (`SubscribeToPlaybackStateUseCase`). See
  /// `VideoSyncBloc._onSessionJoined`'s own doc comment for the full
  /// sequencing.
  const factory VideoSyncEvent.sessionJoined() = VideoSyncSessionJoined;

  /// Internal event: forwards each value emitted by the live Firebase
  /// subscription opened by `sessionJoined`. Never dispatched directly
  /// by UI code — only `VideoSyncBloc` itself calls
  /// `add(VideoSyncEvent.sessionUpdated(...))`, from the subscription's
  /// listener callback.
  const factory VideoSyncEvent.sessionUpdated(
    Either<Failure, VideoSessionEntity> result,
  ) = VideoSyncSessionUpdated;

  /// Dispatched when the user taps the retry action on
  /// `SyncStatusBanner` after a `VideoSyncState.failure`.
  /// Re-runs the full `sessionJoined` flow from scratch.
  const factory VideoSyncEvent.retryRequested() = VideoSyncRetryRequested;

  /// Leader command: start playback from the bloc's current position.
  /// No-op if the bloc's `isLeader` flag is `false` (VS-SYN-05).
  const factory VideoSyncEvent.playRequested() = VideoSyncPlayRequested;

  /// Leader command: pause playback at the bloc's current position.
  /// No-op if the bloc's `isLeader` flag is `false` (VS-SYN-05).
  const factory VideoSyncEvent.pauseRequested() = VideoSyncPauseRequested;

  /// Leader command: move playback to [target]. Rejected client-side,
  /// with no Firebase write attempted, if [target] falls outside
  /// `[0, duration]` — see `PlaybackTimestamp`, which this
  /// event's handler constructs to enforce that bound. No-op if the
  /// bloc's `isLeader` flag is `false`.
  const factory VideoSyncEvent.seekRequested(Duration target) =
      VideoSyncSeekRequested;

  /// Internal event: dispatched by `PlayerReconciliation` when
  /// `SyncEngine.detectAd` transitions from `false` to `true` — the
  /// local player is believed to have entered an advertisement.
  /// Never dispatched by other UI code.
  const factory VideoSyncEvent.adDetected() = VideoSyncAdDetected;

  /// Internal event: dispatched by `PlayerReconciliation` once
  /// `SyncEngine.detectAd` reports progression has resumed — the
  /// advertisement is believed to have ended. Never dispatched by other
  /// UI code.
  const factory VideoSyncEvent.adEnded() = VideoSyncAdEnded;

  /// Internal event: forwards each value emitted by the live
  /// `sync_barrier` subscription opened when the ready gate starts.
  /// Never dispatched directly by UI code.
  const factory VideoSyncEvent.barrierUpdated(
    Either<Failure, SyncBarrierEntity> result,
  ) = VideoSyncBarrierUpdated;

  /// Internal event: forwards the online-participant count from the
  /// live presence subscription, used by the leader to keep the
  /// barrier's `total_count` current while it is open.
  /// Never dispatched directly by UI code.
  const factory VideoSyncEvent.presenceCountUpdated(int onlineCount) =
      VideoSyncPresenceCountUpdated;

  /// Dispatched by `PlayerReconciliation` when this participant's own
  /// player is confirmed to be progressing through *content* (not an
  /// advertisement) while the ready gate is open — i.e. this
  /// participant is past its pre-roll. Increments
  /// `ready_count` atomically.
  const factory VideoSyncEvent.readySignalled() = VideoSyncReadySignalled;

  /// Dispatched when the leader taps "force start" after the ready gate
  /// has timed out. Leader-only; a no-op otherwise.
  const factory VideoSyncEvent.forceStartRequested() =
      VideoSyncForceStartRequested;
}
