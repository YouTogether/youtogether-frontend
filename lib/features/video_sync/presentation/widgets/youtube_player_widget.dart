import 'package:flutter/widgets.dart';

import 'youtube_player_controller_adapter.dart';
import 'youtube_player_controller_factory.dart' as default_factory;

/// Factory signature for constructing the [YoutubePlayerControllerAdapter]
/// backing a [YouTubePlayerWidget] instance.
///
/// Exposed as a constructor parameter (defaulting to
/// [default_factory.createYoutubePlayerControllerAdapter]) specifically
/// so widget tests can inject a `FakeYoutubePlayerControllerAdapter`
/// instead of a real `YoutubePlayerController` (which requires a real
/// WebView to construct) — mirroring how `RegisterPage` takes its use
/// case via the constructor rather than resolving it from `get_it`
/// internally.
typedef YoutubePlayerControllerFactory =
    YoutubePlayerControllerAdapter Function({
      required String videoId,
      required bool showNativeControls,
    });

/// Embeds a single YouTube video via `youtube_player_iframe`, which
/// supports every platform this application targets through one
/// controller and widget — see
/// `youtube_player_controller_factory.dart`'s own doc comment.
///
/// Native player controls (YouTube's own play/pause/seek bar overlay)
/// are shown only when [isLeader] is `true` — for a non-leader viewer,
/// playback must be driven exclusively by [PlayerReconciliation]
/// reacting to `VideoSyncState`, never by the viewer directly
/// interacting with the embedded player's own UI (Acceptance Criteria,
/// "Play/pause/seek buttons disabled for non-leader viewers" —
/// this widget is the first line of enforcement for that rule at the
/// player-chrome level; `LeaderControls` is the second, for the
/// app's own control bar).
///
/// This widget only embeds and reports on playback — it never itself
/// decides *what* to play or *when*: `videoId` is provided by the
/// caller (ultimately from `RoomEntity`/`VideoSessionEntity`), and
/// [onStateChange] merely reports what the player is doing so
/// `VideoSyncBloc` can act on it. Leader-driven writes to Firebase
/// happen in `LeaderControls`/`VideoSyncBloc`, not here.
///
/// @see YoutubePlayerControllerAdapter — the abstraction this widget
///   depends on
class YouTubePlayerWidget extends StatefulWidget {
  /// The production controller factory, exposed as a named constant so
  /// callers that forward an *optional* factory of their own
  /// (`RoomVideoSection`) can fall back to it explicitly rather than
  /// duplicating the `default_factory.` import path.
  static const YoutubePlayerControllerFactory defaultControllerFactory =
      default_factory.createYoutubePlayerControllerAdapter;

  const YouTubePlayerWidget({
    super.key,
    required this.videoId,
    required this.isLeader,
    this.onReady,
    this.onStateChange,
    this.onError,
    this.onControllerReady,
    this.controllerFactory = defaultControllerFactory,
  });

  /// The YouTube video id to load.
  final String videoId;

  /// Whether the current user is this room's leader. Controls whether
  /// the embedded player's own native controls are shown — see this
  /// class's own doc comment.
  final bool isLeader;

  /// Invoked once the player has finished loading.
  final VoidCallback? onReady;

  /// Invoked whenever the player's playback state changes.
  final ValueChanged<PlayerAdapterState>? onStateChange;

  /// Invoked when the player reports an error.
  final ValueChanged<String>? onError;

  /// Invoked exactly once, synchronously in `initState`, with the
  /// controller this widget constructed — so
  /// `PlayerReconciliation` can be given the *same* controller instance
  /// this widget drives internally, rather than constructing a second,
  /// disconnected one. `RoomDetailView`'s integration wraps this widget
  /// in `PlayerReconciliation`, capturing the controller here and
  /// passing it down.
  final ValueChanged<YoutubePlayerControllerAdapter>? onControllerReady;

  /// Constructs the controller backing this widget. Overridable for
  /// tests — see [YoutubePlayerControllerFactory]'s own doc comment.
  @visibleForTesting
  final YoutubePlayerControllerFactory controllerFactory;

  @override
  State<YouTubePlayerWidget> createState() => _YouTubePlayerWidgetState();
}

class _YouTubePlayerWidgetState extends State<YouTubePlayerWidget> {
  late final YoutubePlayerControllerAdapter _controller;

  @override
  void initState() {
    super.initState();

    _controller =
        widget.controllerFactory(
            videoId: widget.videoId,
            showNativeControls: widget.isLeader,
          )
          ..onReady = widget.onReady
          ..onStateChange = widget.onStateChange
          ..onError = widget.onError;

    widget.onControllerReady?.call(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.buildView();
  }
}
