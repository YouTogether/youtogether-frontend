import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failures.dart';

part 'video_sync_state.freezed.dart';

/// State hierarchy for [VideoSyncBloc].
///
/// Declared `@freezed` as a sealed union, mirroring `RoomState`. Unlike
/// [VideoSyncEvent] (see that file's own doc comment), the full state
/// shape this bounded context will eventually need is declared here
/// upfront, rather than grown state-by-state:
/// [VideoSyncBloc] must already `switch` exhaustively over every state
/// to compile at all (Dart sealed-class exhaustiveness checking), so
/// every consumer written against this type — most
/// importantly `YouTubePlayerWidget`'s callers and `RoomDetailView`'s
/// eventual `BlocBuilder` — only ever needs to be written once. Adding
/// a state case later would be a breaking change to every existing
/// `switch`; adding a case that already exists but is simply unused
/// until a later ticket wires it is not.
@freezed
sealed class VideoSyncState with _$VideoSyncState {
  /// No session has been joined yet. Never actually emitted by
  /// [VideoSyncBloc] — the bloc is constructed already
  /// holding a known position/isPlaying pair (see that class's own doc
  /// comment) — but kept as the union's starting case, mirroring
  /// `RoomState.initial()`, for `sessionJoined` to emit
  /// before its first fetch begins.
  const factory VideoSyncState.initial() = VideoSyncInitial;

  /// The initial fetch of the current playback state
  /// (`GetCurrentPlaybackStateUseCase`) is in flight. Reserved for
  /// `sessionJoined` handler.
  const factory VideoSyncState.loading() = VideoSyncLoading;

  /// The initial fetch succeeded and the live Firebase subscription is
  /// being opened, but the first `sessionUpdated` event has not yet
  /// arrived to settle into [playing] or [paused].
  const factory VideoSyncState.ready({
    required Duration position,
    required bool isPlaying,
  }) = VideoSyncReady;

  /// Video is currently playing at [position] (the position last
  /// written or received, not a live-updating clock — the embedded
  /// player itself advances visually between writes).
  const factory VideoSyncState.playing({required Duration position}) =
      VideoSyncPlaying;

  /// Video is currently paused at [position].
  const factory VideoSyncState.paused({required Duration position}) =
      VideoSyncPaused;

  /// A playback command or the live subscription failed. Carries the
  /// [Failure] so the UI can offer a retry —
  /// already part of the union here since [VideoSyncBloc]'s command
  /// handlers can themselves fail against
  /// [UpdatePlaybackStateUseCase] and need somewhere to report that.
  const factory VideoSyncState.failure(Failure failure) = VideoSyncFailure;
}
