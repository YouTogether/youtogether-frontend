import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../bloc/video_sync_bloc.dart';
import '../bloc/video_sync_state.dart';
import 'add_video_form.dart';
import 'leader_controls.dart';
import 'online_participants_indicator.dart';
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
/// ## Degraded reconciliation
/// [PlayerReconciliation] reports through [onReconciliationDegraded]
/// when its sampling loop has stopped producing readings. That is a
/// local player fault, not a Firebase one, so it is deliberately kept
/// out of [SyncStatusBanner]: that banner's retry action re-runs the
/// whole `sessionJoined` sequence, which repairs nothing here and would
/// mislabel the fault. The notice rendered instead is informational and
/// carries no action — playback continues, only automatic drift
/// correction is unavailable, and the user's own recourse is to reload
/// the room.
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
  bool _reconciliationDegraded = false;

  void _handleControllerReady(YoutubePlayerControllerAdapter controller) {
    // Deferred: see this widget's own doc comment for why setState
    // cannot be called synchronously here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _controller = controller);
    });
  }

  void _handleReconciliationDegraded(bool degraded) {
    // Invoked from a Timer callback, never during build, so setState is
    // safe here without deferral — unlike _handleControllerReady, which
    // fires from a descendant's initState.
    if (!mounted || _reconciliationDegraded == degraded) return;
    setState(() => _reconciliationDegraded = degraded);
  }

  Widget _buildDegradedNotice(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      key: const Key('roomVideoSectionDegradedNotice'),
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            Icon(
              Icons.sync_problem_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.syncReconciliationDegraded,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
        // nothing to render but the banner — and, for the leader, the
        // form that resolves exactly that situation.
        if (bloc.youtubeVideoId.isEmpty) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SyncStatusBanner(),
              if (bloc.isLeader)
                const AddVideoForm()
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    AppLocalizations.of(context).videoSyncNoVideoYetMessage,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          );
        }

        final controller = _controller;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SyncStatusBanner(),
            // The live participant count sits with the player, not with
            // the room's metadata below: it describes the broadcast
            // session, and is only meaningful while one is on screen.
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OnlineParticipantsIndicator(),
              ),
            ),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: YouTubePlayerWidget(
                key: const Key('roomVideoSectionPlayer'),
                videoId: bloc.youtubeVideoId,
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
                onReconciliationDegraded: _handleReconciliationDegraded,
                child: LeaderControls(
                  isLeader: bloc.isLeader,
                  durationSeconds: bloc.durationSeconds,
                ),
              ),
            if (_reconciliationDegraded) _buildDegradedNotice(context),
          ],
        );
      },
    );
  }
}
