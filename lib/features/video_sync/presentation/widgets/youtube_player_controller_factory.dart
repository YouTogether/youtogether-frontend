import 'package:flutter/widgets.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'youtube_player_controller_adapter.dart';

/// Concrete [YoutubePlayerControllerAdapter], wrapping
/// `youtube_player_iframe`'s [YoutubePlayerController].
///
/// A single implementation for every platform: `youtube_player_iframe`
/// (built on `webview_flutter`, with its own `youtube_player_iframe_web`
/// companion package) already supports Web, Android, iOS, and macOS
/// through this same controller and the [YoutubePlayer] widget — see
/// https://pub.dev/packages/youtube_player_iframe. No
/// platform-conditional code is needed in this application at all.
///
/// API verified directly against the package's published class
/// documentation (v6.0.2), correcting two errors from earlier drafts of
/// this file:
/// - Playback methods are [YoutubePlayerController.playVideo] and
///   [YoutubePlayerController.pauseVideo] — not the plain `play()`/
///   `pause()` names that appeared in one README code sample. The
///   authoritative class reference
///   (pub.dev/documentation/.../YoutubePlayerController-class.html)
///   lists only `playVideo()`/`pauseVideo()`; there is no `play()`/
///   `pause()` method on this class.
/// - [YoutubePlayerValue] has **no** `isReady` property. Its actual
///   properties are `playerState`, `hasError`, `error`, `metaData`,
///   `playbackQuality`, `playbackRate`, `fullScreenOption` — confirmed
///   against the same class reference
///   (pub.dev/documentation/.../YoutubePlayerValue-class.html).
///   Readiness is instead inferred from [PlayerState] itself: the
///   controller's initial value is `PlayerState.unknown` ("No video has
///   been loaded. Initial state."), and the first state reported
///   thereafter is `PlayerState.unStarted` ("Player is ready but
///   playback has not started.") — so "ready" is defined here as the
///   first [listen] callback where `playerState != PlayerState.unknown`.
/// - The player widget is [YoutubePlayer] — not `YoutubePlayerIFrame`
///   (that name belongs to unrelated community forks, not this
///   package).
class _YoutubePlayerControllerAdapterImpl
    implements YoutubePlayerControllerAdapter {
  _YoutubePlayerControllerAdapterImpl({
    required this.videoId,
    required bool showNativeControls,
  }) : _controller = YoutubePlayerController.fromVideoId(
         videoId: videoId,
         autoPlay: false,
         params: YoutubePlayerParams(
           showControls: showNativeControls,
           showFullscreenButton: false,
           mute: false,
         ),
       ) {
    _controller.listen(_handlePlayerValue);
  }

  final YoutubePlayerController _controller;

  @override
  final String videoId;

  @override
  VoidCallback? onReady;

  @override
  ValueChanged<PlayerAdapterState>? onStateChange;

  @override
  ValueChanged<String>? onError;

  bool _readyFired = false;

  void _handlePlayerValue(YoutubePlayerValue value) {
    if (!_readyFired && value.playerState != PlayerState.unknown) {
      _readyFired = true;
      onReady?.call();
    }

    onStateChange?.call(_mapState(value.playerState));

    if (value.hasError) {
      onError?.call(value.error.toString());
    }
  }

  PlayerAdapterState _mapState(PlayerState state) {
    return switch (state) {
      PlayerState.unknown => PlayerAdapterState.unstarted,
      PlayerState.unStarted => PlayerAdapterState.unstarted,
      PlayerState.ended => PlayerAdapterState.ended,
      PlayerState.playing => PlayerAdapterState.playing,
      PlayerState.paused => PlayerAdapterState.paused,
      PlayerState.buffering => PlayerAdapterState.buffering,
      PlayerState.cued => PlayerAdapterState.cued,
    };
  }

  @override
  Widget buildView() {
    return YoutubePlayer(controller: _controller, aspectRatio: 16 / 9);
  }

  @override
  Future<void> play() => _controller.playVideo();

  @override
  Future<void> pause() => _controller.pauseVideo();

  @override
  Future<void> seekTo(Duration position) {
    return _controller.seekTo(
      seconds: position.inMilliseconds / 1000,
      allowSeekAhead: true,
    );
  }

  @override
  void dispose() => _controller.close();
}

/// Default [YoutubePlayerControllerFactory] (see
/// `youtube_player_widget.dart`), used on every platform.
YoutubePlayerControllerAdapter createYoutubePlayerControllerAdapter({
  required String videoId,
  required bool showNativeControls,
}) {
  return _YoutubePlayerControllerAdapterImpl(
    videoId: videoId,
    showNativeControls: showNativeControls,
  );
}
