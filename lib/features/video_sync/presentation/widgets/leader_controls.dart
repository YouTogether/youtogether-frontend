import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/video_sync_bloc.dart';
import '../bloc/video_sync_event.dart';
import '../bloc/video_sync_state.dart';

/// Play/pause/seek control bar for a room's video session, reading and
/// dispatching against the ancestor [VideoSyncBloc] (provided by
/// `RoomDetailView` once that integration ticket lands — see
/// `VideoSyncBloc`'s own doc comment for why that wiring is not yet
/// part of this codebase).
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
/// ## Material ancestor (fix)
/// `Slider` and `IconButton` both require a `Material` ancestor to
/// render — normally supplied for free by the `Scaffold` this widget
/// will eventually sit inside once wired into `RoomDetailView`. Until
/// that integration lands, and to keep this widget safe to embed
/// anywhere without the caller needing to remember that requirement,
/// [build] wraps its content in its own `Material` (`type:
/// MaterialType.transparency`, so it paints nothing extra and cannot
/// visually clash with whatever real `Scaffold`/`Card` background
/// eventually surrounds it). Caught by `leader_controls_test.dart`
/// failing with "No Material widget found" the first time it actually
/// ran — the test itself also lacked a `Scaffold` and has been
/// corrected alongside this fix, but a reusable widget should not
/// depend on every caller remembering that requirement either.
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
    return BlocBuilder<VideoSyncBloc, VideoSyncState>(
      builder: (context, state) {
        final position = switch (state) {
          VideoSyncPlaying(:final position) => position,
          VideoSyncPaused(:final position) => position,
          VideoSyncReady(:final position) => position,
          VideoSyncInitial() ||
          VideoSyncLoading() ||
          VideoSyncFailure() => Duration.zero,
        };
        final isPlaying = state is VideoSyncPlaying;

        return Material(
          type: MaterialType.transparency,
          child: Row(
            children: [
              IconButton(
                key: const Key('leaderControlsPlayButton'),
                icon: const Icon(Icons.play_arrow),
                onPressed: (!isLeader || isPlaying)
                    ? null
                    : () => context.read<VideoSyncBloc>().add(
                        const VideoSyncEvent.playRequested(),
                      ),
              ),
              IconButton(
                key: const Key('leaderControlsPauseButton'),
                icon: const Icon(Icons.pause),
                onPressed: (!isLeader || !isPlaying)
                    ? null
                    : () => context.read<VideoSyncBloc>().add(
                        const VideoSyncEvent.pauseRequested(),
                      ),
              ),
              Expanded(
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
            ],
          ),
        );
      },
    );
  }
}
