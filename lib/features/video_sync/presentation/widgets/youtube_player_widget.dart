import 'package:flutter/widgets.dart';

import 'youtube_player_controller_adapter.dart';
import 'youtube_player_controller_factory.dart';

/// Factory signature for constructing the [YoutubePlayerControllerAdapter]
/// backing a [YouTubePlayerWidget] instance.
///
/// Exposed as a constructor parameter (defaulting to
/// [createYoutubePlayerControllerAdapter]) specifically so widget tests
/// can inject a `FakeYoutubePlayerControllerAdapter` instead of a real
/// `youtube_player_iframe` controller — mirroring how `RegisterPage`
/// takes its use case via the constructor rather than resolving it from
/// `get_it` internally.
typedef YoutubePlayerControllerFactory =
    YoutubePlayerControllerAdapter Function({
      required String videoId,
      required bool showNativeControls,
    });

/// Embeds a single YouTube video via `youtube_player_iframe`, which
/// supports Web, Android, iOS, and macOS through the same controller
/// and widget API — this widget contains no platform-conditional code
/// of its own; see [YoutubePlayerControllerAdapter]'s doc comment for
/// the correction this design went through.
///
/// Native player controls (YouTube's own play/pause/seek bar overlay)
/// are shown only when [isLeader] is `true` — for a non-leader viewer,
/// playback must be driven exclusively by [PlayerReconciliation]
/// reacting to `VideoSyncState`, never by the viewer directly
/// interacting with the embedded player's own UI (Acceptance Criteria:
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
class YouTubePlayerWidget extends StatefulWidget {
  const YouTubePlayerWidget({
    super.key,
    required this.videoId,
    required this.isLeader,
    this.onReady,
    this.onStateChange,
    this.onError,
    this.controllerFactory = createYoutubePlayerControllerAdapter,
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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _controller.buildView();
}
