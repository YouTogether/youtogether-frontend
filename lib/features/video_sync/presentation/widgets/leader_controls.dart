import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../bloc/video_sync_bloc.dart';
import '../bloc/video_sync_event.dart';
import '../bloc/video_sync_state.dart';

/// Play/pause/seek control bar for a room's video session, reading and
/// dispatching against the ancestor [VideoSyncBloc].
///
/// [isLeader] gates every control here to disabled — `onPressed`/
/// `onChanged` set to `null` rather than merely hidden, so a non-leader
/// still sees the transport controls (for orientation: "here is where
/// playback stands") without being able to act on them. This is the
/// second of the two enforcement points named in
/// `YouTubePlayerWidget`'s own doc comment (VS-SYN-05); disabling here
/// means a non-leader's tap never reaches [VideoSyncBloc.add] at all,
/// rather than relying solely on the bloc's own `isLeader` no-op check
/// as the only line of defence.
///
/// [durationSeconds] is required separately from the bloc's own state
/// (which carries only [Duration] `position`, not the video's total
/// duration) so the seek slider has an upper bound to render against —
/// supplied by whichever caller already has it to construct
/// [VideoSyncBloc] in the first place.
///
/// ## Accessibility
/// Both buttons carry a localised `tooltip`, which Flutter also exposes
/// as the semantics label — an [IconButton] with neither label nor
/// tooltip is announced as an unnamed button by a screen reader, which
/// is a WCAG 2.1 failure (4.1.2 Name, Role, Value). The slider is
/// wrapped in a labelled [Semantics] for the same reason. Tooltip
/// wording ("Play for everyone") deliberately states the collective
/// effect: a leader pressing play changes what every participant sees,
/// and that is not obvious from a play icon alone.
class LeaderControls extends StatelessWidget {
  const LeaderControls({
    super.key,
    required this.isLeader,
    required this.durationSeconds,
  });

  final bool isLeader;
  final int durationSeconds;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocBuilder<VideoSyncBloc, VideoSyncState>(
      builder: (context, state) {
        final position = switch (state) {
          VideoSyncPlaying(:final position) => position,
          VideoSyncPaused(:final position) => position,
          VideoSyncReady(:final position) => position,
          VideoSyncInitial() ||
          VideoSyncLoading() ||
          VideoSyncFailure() ||
          VideoSyncAdInProgress() ||
          VideoSyncBarrierWaiting() => Duration.zero,
        };
        final isPlaying = state is VideoSyncPlaying;

        return Row(
          children: [
            IconButton(
              key: const Key('leaderControlsPlayButton'),
              icon: const Icon(Icons.play_arrow),
              tooltip: l10n.videoSyncPlayButtonTooltip,
              onPressed: (!isLeader || isPlaying)
                  ? null
                  : () => context.read<VideoSyncBloc>().add(
                      const VideoSyncEvent.playRequested(),
                    ),
            ),
            IconButton(
              key: const Key('leaderControlsPauseButton'),
              icon: const Icon(Icons.pause),
              tooltip: l10n.videoSyncPauseButtonTooltip,
              onPressed: (!isLeader || !isPlaying)
                  ? null
                  : () => context.read<VideoSyncBloc>().add(
                      const VideoSyncEvent.pauseRequested(),
                    ),
            ),
            Expanded(
              child: Semantics(
                label: l10n.videoSyncSeekSliderLabel,
                child: Slider(
                  key: const Key('leaderControlsSeekSlider'),
                  min: 0,
                  max: durationSeconds.toDouble(),
                  value: position.inSeconds
                      .clamp(0, durationSeconds)
                      .toDouble(),
                  onChanged: !isLeader
                      ? null
                      : (value) => context.read<VideoSyncBloc>().add(
                          VideoSyncEvent.seekRequested(
                            Duration(seconds: value.round()),
                          ),
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
