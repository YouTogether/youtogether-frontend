import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'youtube_player_controller_adapter.dart';

/// Player parameters, identical for every participant.
///
/// Applies ADR-002: `LeaderControls` is the sole entry point for
/// playback intent, so the embedded player must answer no native input
/// from anyone. Three parameters carry that decision, and each closes a
/// distinct hole:
///
/// - [YoutubePlayerParams.showControls] hides the overlay. On its own
///   it only hides: the player still answers clicks on the video
///   surface.
/// - [YoutubePlayerParams.enableKeyboard] defaults to `kIsWeb`, leaving
///   space-bar and arrow-key control active on the web build.
/// - [YoutubePlayerParams.pointerEvents] is what actually makes the
///   embed inert. It is also what unblocks page scrolling: the platform
///   view otherwise consumes wheel events before the enclosing
///   `Scrollable` ever sees them.
///
/// [YoutubePlayerParams.strictRelatedVideos] is set because the
/// end screen cannot be suppressed through this API. Restricting its
/// suggestions to the originating channel is the closest available
/// behaviour; with pointer events disabled they are in any case not
/// actionable.
YoutubePlayerParams buildYoutubePlayerParams() {
  return const YoutubePlayerParams(
    showControls: false,
    enableKeyboard: false,
    pointerEvents: PointerEvents.none,
    showFullscreenButton: false,
    showVideoAnnotations: false,
    strictRelatedVideos: true,
    mute: false,
  );
}

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
/// ## Reading the player
/// Readiness is inferred from [PlayerState] itself: the controller's
/// initial value is `PlayerState.unknown` ("No video has been loaded.
/// Initial state."), and the first state reported thereafter is
/// `PlayerState.unStarted` ("Player is ready but playback has not
/// started.") — so "ready" is defined here as the first [listen]
/// callback where `playerState != PlayerState.unknown`.
/// [YoutubePlayerValue] carries no `isReady` property of its own.
///
/// ## Seeking
/// [seekTo] does not use the package's own `seekTo`. The package sends
/// `player.seekTo(seconds, allowSeekAhead)` to the iframe, whose
/// embedded script (`assets/player.html`, `_safeCall`) passes the whole
/// argument list through a single `JSON.parse` and forwards the result
/// as one argument. Two comma-separated arguments are not valid JSON;
/// the call throws inside the iframe, the exception is swallowed, and
/// the player never moves. This holds on every platform, since the
/// script is shared. The single-argument form `player.seekTo(seconds)`
/// parses, and the IFrame Player API treats an omitted `allowSeekAhead`
/// as permission to seek outside the buffered range. See ADR-003 for
/// the evidence and the retirement criterion.
///
/// Play and pause go through the package's own methods: they carry no
/// arguments, so the same script executes them correctly, and the
/// package's readiness gate is preserved. [seekTo] reconstitutes that
/// gate with [_ready], because `runJavaScript` bypasses it.
class _YoutubePlayerControllerAdapterImpl
    implements YoutubePlayerControllerAdapter {
  _YoutubePlayerControllerAdapterImpl({required this.videoId})
    : _controller = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: false,
        params: buildYoutubePlayerParams(),
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

  /// Completes on the first value whose state is not `unknown`: the
  /// player has loaded and is accepting commands. Commands sent before
  /// that point through `runJavaScript` are posted to an iframe with no
  /// listener yet and are lost.
  final Completer<void> _ready = Completer<void>();

  PlayerAdapterState _lastState = PlayerAdapterState.unstarted;

  void _handlePlayerValue(YoutubePlayerValue value) {
    if (!_ready.isCompleted && value.playerState != PlayerState.unknown) {
      _ready.complete();
      onReady?.call();
    }

    _lastState = _mapState(value.playerState);
    onStateChange?.call(_lastState);

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

  /// Bounds a command's wait.
  ///
  /// A command carries no return value the caller could act on, so a
  /// transport that stops acknowledging must not suspend the caller:
  /// `PlayerReconciliation` issues `play()`/`pause()` only once the
  /// seek that precedes them has returned. Logged on timeout rather
  /// than swallowed, so the condition stays visible.
  Future<void> _bounded(String name, Future<void> command) async {
    try {
      await command.timeout(const Duration(seconds: 1));
    } on TimeoutException {
      developer.log(
        'Player command $name was not acknowledged within 1 s',
        name: 'video_sync',
        level: 900,
      );
    }
  }

  @override
  Future<void> play() => _bounded('play', _controller.playVideo());

  @override
  Future<void> pause() => _bounded('pause', _controller.pauseVideo());

  @override
  Future<void> seekTo(Duration position) async {
    await _ready.future;

    // One argument only — see the class comment. Milliseconds rather
    // than `inSeconds`, which truncates: the precision
    // `computeExpectedPosition` produces is not worth discarding.
    final seconds = position.inMilliseconds / Duration.millisecondsPerSecond;
    await _bounded(
      'seekTo',
      _controller.webViewController.runJavaScript('player.seekTo($seconds)'),
    );
  }

  @override
  Future<PlayerSample> getCurrentSample() async {
    final seconds = await _controller.currentTime;
    return PlayerSample(
      position: Duration(milliseconds: (seconds * 1000).round()),
      state: _lastState,
    );
  }

  @override
  void dispose() => _controller.close();
}

/// Default [YoutubePlayerControllerFactory] (see
/// `youtube_player_widget.dart`), used on every platform.
YoutubePlayerControllerAdapter createYoutubePlayerControllerAdapter({
  required String videoId,
}) {
  return _YoutubePlayerControllerAdapterImpl(videoId: videoId);
}
