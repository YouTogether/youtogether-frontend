import 'package:flutter/widgets.dart';

/// Playback state reported by the underlying YouTube IFrame Player API.
///
/// Mirrors the IFrame Player API's own `PlayerState` enum values
/// (`-1 unstarted`, `0 ended`, `1 playing`, `2 paused`, `3 buffering`,
/// `5 cued`) under application-native names, so
/// `VideoSyncBloc`/`PlayerReconciliation` never needs to know
/// the platform SDK's own integer encoding.
enum PlayerAdapterState { unstarted, ended, playing, paused, buffering, cued }

/// Contract for driving a single embedded YouTube player instance,
/// wrapping `youtube_player_iframe`'s `YoutubePlayerController`.
///
/// A single implementation now covers every platform — see
/// `youtube_player_controller_factory.dart`'s own doc comment for why
/// the web/mobile split originally planned turned out to
/// be unnecessary. This abstraction is kept regardless: it is what
/// keeps [YouTubePlayerWidget]'s gating logic (native controls hidden
/// for non-leaders) and callback wiring unit-testable against a
/// `FakeYoutubePlayerControllerAdapter`, without constructing a real
/// `YoutubePlayerController` (which requires a real WebView) in a
/// widget test.
///
/// @see createYoutubePlayerControllerAdapter — the default
///   implementation
abstract class YoutubePlayerControllerAdapter {
  /// The video currently loaded.
  String get videoId;

  /// Builds the embeddable player widget.
  Widget buildView();

  /// Invoked once the player has finished loading and is ready to
  /// receive commands.
  VoidCallback? onReady;

  /// Invoked whenever the player's playback state changes.
  ValueChanged<PlayerAdapterState>? onStateChange;

  /// Invoked when the player reports an error (e.g. video unavailable,
  /// embedding disabled by the video's owner).
  ValueChanged<String>? onError;

  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);

  /// Reads the player's current playback position
  /// (`getCurrentTime()`), and its current [PlayerAdapterState].
  ///
  /// Added for F-V04's `PlayerReconciliation`: `SyncEngine.detectAd`
  /// needs periodic samples of both together (Section 5.1's detection
  /// heuristic checks the player state *and* timestamp progression
  /// jointly), and the two must come from a single read — sampling
  /// `getCurrentTime()` and the last `onStateChange` value separately,
  /// moments apart, could observe a state transition between the two
  /// reads and misclassify a sample.
  Future<PlayerSample> getCurrentSample();

  /// Releases any platform resources (the underlying WebView) held by
  /// this controller. Called from `_YouTubePlayerWidgetState.dispose()`.
  void dispose();
}

/// A single joint (position, state) reading from a player, returned by
/// [YoutubePlayerControllerAdapter.getCurrentSample].
class PlayerSample {
  const PlayerSample({required this.position, required this.state});

  final Duration position;
  final PlayerAdapterState state;
}
