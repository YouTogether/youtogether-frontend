import 'package:freezed_annotation/freezed_annotation.dart';

part 'video_sync_event.freezed.dart';

/// Event hierarchy for [VideoSyncBloc].
///
/// Declared `@freezed` as a sealed union, mirroring `RoomEvent`.
///
/// Only the leader-command events (`playRequested`, `pauseRequested`,
/// `seekRequested`) are handled. `sessionJoined` and
/// `sessionUpdated` — needed for the initial-sync and real-time viewer
/// listener behaviour;
/// declaring the full event set upfront was considered and rejected
/// here (unlike `VideoSyncState`, see that file's own doc comment for
/// why states differ).
@freezed
sealed class VideoSyncEvent with _$VideoSyncEvent {
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
}
