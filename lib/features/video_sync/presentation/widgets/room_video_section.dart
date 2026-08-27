import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/video_sync_bloc.dart';
import '../bloc/video_sync_state.dart';
import 'leader_controls.dart';
import 'player_reconciliation.dart';
import 'sync_status_banner.dart';
import 'youtube_player_controller_adapter.dart';
import 'youtube_player_widget.dart';

/// Composes the room's whole video-synchronisation UI —
/// [SyncStatusBanner], [YouTubePlayerWidget], [PlayerReconciliation],
/// and [LeaderControls] — into one widget `RoomDetailView` can drop into
/// its body without itself becoming stateful.
///
/// ## Why this widget is stateful
/// [PlayerReconciliation] needs the *same* controller instance
/// [YouTubePlayerWidget] drives internally — constructing a second one
/// would poll a player nobody is watching. [YouTubePlayerWidget] hands
/// its controller over via `onControllerReady`, which fires during that
/// widget's own `initState`, i.e. while this widget's build is still
/// mounting. Calling `setState` at that moment throws
/// ("setState() called during build"), so the rebuild is deferred to a
/// post-frame callback: the first frame renders the player alone, and
/// the frame immediately after adds [PlayerReconciliation] around
/// [LeaderControls].
///
/// [PlayerReconciliation] wraps [LeaderControls] rather than the player
/// itself, which may look odd at first glance. It is deliberate: that
/// widget's `child` is purely compositional — its two real jobs (a
/// `BlocListener` driving `play()`/`pause()`, and a periodic sampling
/// timer) act on the controller it was *given*, not on whatever it
/// happens to wrap. Wrapping the controls keeps the player's own
/// subtree from rebuilding on every `VideoSyncState` transition.
///
/// ## Localisation
/// This widget and its children use hard-coded English strings rather
/// than `AppLocalizations`, unlike the rest of `RoomDetailView`. Every
/// video-sync string introduced across F-V01 to F-V04 is new, and the
/// ARB files were not available to add keys to when these widgets were
/// written — adding `l10n.` references to keys that do not exist would
/// not compile. These strings need extracting into the ARB files before
/// this ships; flagged rather than silently left inconsistent.
class RoomVideoSection extends StatefulWidget {
  const RoomVideoSection({super.key, this.controllerFactory});

  /// Forwarded to [YouTubePlayerWidget] when non-null, so widget tests
  /// can mount this whole composition against a fake controller — the
  /// real default factory constructs a `YoutubePlayerController`, which
  /// needs a platform WebView and cannot be built under
  /// `flutter test`. Same seam, same reason as
  /// [YouTubePlayerWidget.controllerFactory] itself.
  @visibleForTesting
  final YoutubePlayerControllerFactory? controllerFactory;

  @override
  State<RoomVideoSection> createState() => _RoomVideoSectionState();
}

class _RoomVideoSectionState extends State<RoomVideoSection> {
  YoutubePlayerControllerAdapter? _controller;

  void _handleControllerReady(YoutubePlayerControllerAdapter controller) {
    // Deferred: see this widget's own doc comment for why setState
    // cannot be called synchronously here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _controller = controller);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VideoSyncBloc, VideoSyncState>(
      builder: (context, state) {
        final bloc = context.read<VideoSyncBloc>();

        // Before `sessionJoined` resolves there is no video id to load,
        // and no duration to bound the seek bar with.
        if (state is VideoSyncInitial || state is VideoSyncLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(
                key: Key('roomVideoSectionLoadingIndicator'),
              ),
            ),
          );
        }

        // A failure before any session was ever loaded (e.g. the room
        // has no video session yet, `NotFoundFailure` from B-V02) leaves
        // nothing to render but the banner and its retry action.
        if (bloc.youtubeVideoId.isEmpty) {
          return const SyncStatusBanner();
        }

        final controller = _controller;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SyncStatusBanner(),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: YouTubePlayerWidget(
                key: const Key('roomVideoSectionPlayer'),
                videoId: bloc.youtubeVideoId,
                isLeader: bloc.isLeader,
                onControllerReady: _handleControllerReady,
                controllerFactory:
                    widget.controllerFactory ??
                    YouTubePlayerWidget.defaultControllerFactory,
              ),
            ),
            if (controller == null)
              LeaderControls(
                isLeader: bloc.isLeader,
                durationSeconds: bloc.durationSeconds,
              )
            else
              PlayerReconciliation(
                controller: controller,
                child: LeaderControls(
                  isLeader: bloc.isLeader,
                  durationSeconds: bloc.durationSeconds,
                ),
              ),
          ],
        );
      },
    );
  }
}
