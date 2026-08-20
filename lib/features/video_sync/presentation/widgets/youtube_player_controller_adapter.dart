import 'package:flutter/widgets.dart';

/// Playback state reported by the underlying YouTube IFrame Player API,
/// normalised under application-native names so
/// `VideoSyncBloc`/`PlayerReconciliation` never needs to
/// depend on `youtube_player_iframe`'s own `PlayerState` enum directly.
enum PlayerAdapterState { unstarted, ended, playing, paused, buffering, cued }

/// Thin contract wrapping a single embedded YouTube player instance.
///
/// [YouTubePlayerWidget] depends on this abstraction rather than
/// directly on `youtube_player_iframe`'s `YoutubePlayerController` —
/// this is what keeps the widget's native-controls gating and callback
/// wiring unit-testable against a `FakeYoutubePlayerControllerAdapter`,
/// without needing a real WebView instance inside the widget test tree
/// (the real controller ultimately drives one via `webview_flutter`,
/// which has no meaningful behaviour to assert on inside `flutter
/// test`'s Dart-VM environment).
///
/// CORRECTION (see commit history): this class previously also exposed
/// a `webViewType` getter and a `buildMobileView()` method, on the
/// assumption that web and mobile needed genuinely different embedding
/// strategies (a hand-rolled `HtmlElementView`/`postMessage` bridge for
/// web, `youtube_player_iframe` for mobile). That assumption was wrong:
/// `youtube_player_iframe` already supports Web, Android, iOS, and
/// macOS through the same `YoutubePlayerController`/`YoutubePlayer`
/// API, via its own `youtube_player_iframe_web` companion package
/// (built on `webview_flutter` everywhere, not a hand-rolled `iframe`
/// integration). There is exactly one implementation now, and this
/// interface exposes exactly the surface `YouTubePlayerWidget` needs:
/// [buildView] instead of two platform-specific build methods.
///
/// @see createYoutubePlayerControllerAdapter — the concrete factory
abstract class YoutubePlayerControllerAdapter {
  /// The video currently loaded.
  String get videoId;

  /// Builds the embeddable player widget. Identical across every
  /// supported platform — the platform split lives inside
  /// `youtube_player_iframe` itself, not in this application's code.
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

  /// Releases the underlying `YoutubePlayerController`. Called from
  /// `_YouTubePlayerWidgetState.dispose()`.
  void dispose();
}
