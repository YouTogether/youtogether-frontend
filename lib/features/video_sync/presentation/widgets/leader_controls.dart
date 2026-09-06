import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../bloc/video_sync_bloc.dart';
import '../bloc/video_sync_event.dart';
import '../bloc/video_sync_state.dart';

/// Play/pause/seek control bar for a room's video session, reading and
/// dispatching against the ancestor [VideoSyncBloc].
///
/// Since ADR-002 this bar is the *only* way anyone influences playback:
/// the embedded player answers no native input from any participant, so
/// a leader with no working slider here has no way to move through the
/// video at all. That raises the bar on this widget's correctness
/// relative to when it merely duplicated YouTube's own overlay.
///
/// [isLeader] gates every control here to disabled — `onPressed`/
/// `onChanged` set to `null` rather than merely hidden, so a non-leader
/// still sees the transport controls (for orientation: "here is where
/// playback stands") without being able to act on them. This is the
/// first of the two remaining enforcement points for the leader role
/// (VS-SYN-05); disabling here means a non-leader's tap never reaches
/// [VideoSyncBloc.add] at all, rather than relying solely on the bloc's
/// own `isLeader` no-op check as the only line of defence.
/// `YouTubePlayerWidget` was formerly named as an enforcement point; it
/// is no longer one, since ADR-002 made its player identical and inert
/// for every role.
///
/// [durationSeconds] is required separately from the bloc's own state
/// (which carries only [Duration] `position`, not the video's total
/// duration) so the seek slider has an upper bound to render against —
/// supplied by whichever caller already has it to construct
/// [VideoSyncBloc] in the first place.
///
/// ## Why this widget is stateful
/// A [Slider] rendered straight from `VideoSyncState.position` cannot
/// follow a finger: every rebuild during the gesture returns the thumb
/// to the position the bloc last emitted. Since F-V08-T1 the leader
/// also receives a `playing` state on the heartbeat cadence, so a drag
/// lasting longer than one heartbeat interval would be interrupted by
/// the leader's own republication of its position.
///
/// The state kept here is deliberately minimal, and the rule governing
/// it is *derived in [build]* rather than maintained by an effect. An
/// earlier revision cleared the held value from a `BlocListener`
/// wrapped around the `BlocBuilder`; that made correctness depend on a
/// second subscription to `bloc.stream` being delivered, which is a
/// detail of `flutter_bloc` and of whatever stubs the bloc under test.
/// Deriving the rule from the state the builder already receives
/// removes the subscription, the `setState`, and the ordering question
/// together.
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
///
/// [Slider.semanticFormatterCallback] is supplied so the seek control
/// announces "2:05" rather than the bare number 125, which is what an
/// unconfigured slider reports. A position in seconds is not a
/// meaningful announcement for a value the user perceives as a time.
class LeaderControls extends StatefulWidget {
  const LeaderControls({
    super.key,
    required this.isLeader,
    required this.durationSeconds,
  });

  final bool isLeader;
  final int durationSeconds;

  /// Renders [value] as `M:SS`, extended to `H:MM:SS` only when the
  /// value warrants it.
  ///
  /// Not delegated to `intl`: this is an elapsed duration, not a time
  /// of day, and its rendering is identical across every locale this
  /// application supports. The convention matches what the embedded
  /// player's own overlay displayed before ADR-002 removed it, so the
  /// readout is not a new visual language for the user to learn.
  ///
  /// Static and public so the widget test can assert the formatting
  /// itself without pumping a tree for each case.
  static String formatPosition(Duration value) {
    final total = value.inSeconds;
    final seconds = (total % 60).toString().padLeft(2, '0');
    final minutes = (total ~/ 60) % 60;
    final hours = total ~/ 3600;

    if (hours == 0) return '$minutes:$seconds';
    return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
  }

  @override
  State<LeaderControls> createState() => _LeaderControlsState();
}

class _LeaderControlsState extends State<LeaderControls> {
  /// The value the user is manipulating, or last released.
  double? _thumbValue;

  /// Whether a drag is currently in progress.
  bool _isDragging = false;

  /// The bloc state as it stood when the drag was released.
  ///
  /// What makes the held value expire. `seekRequested` writes to
  /// Firebase before [VideoSyncBloc] emits anything, so dropping the
  /// held value at release would return the thumb to its previous
  /// position for a frame before sending it to the target — a visible
  /// bounce on every seek. Keeping it until the state moves on covers
  /// that round trip without any timer or echo matching: the next
  /// state, whatever it is, supersedes the gesture.
  ///
  /// A failed write emits [VideoSyncState.failure], which is a
  /// different state and therefore expires the held value too. That is
  /// correct rather than incidental: the seek did not happen, so the
  /// thumb belongs at the position that actually holds.
  VideoSyncState? _stateAtRelease;

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

        // `durationSeconds` is 0 until `sessionJoined` completes. A
        // Slider whose min equals its max divides by zero computing the
        // thumb's fraction, so the range is widened artificially and the
        // control disabled until a real duration is known. The defect is
        // latent today only because this bar is mounted after `ready`;
        // it should not depend on that ordering.
        final hasDuration = widget.durationSeconds > 0;
        final maximum = hasDuration ? widget.durationSeconds.toDouble() : 1.0;
        final canSeek = widget.isLeader && hasDuration;

        final held = _thumbValue;
        final holdApplies =
            held != null && (_isDragging || state == _stateAtRelease);

        final thumb = holdApplies
            ? held
            : position.inSeconds.clamp(0, widget.durationSeconds).toDouble();
        final thumbPosition = Duration(seconds: thumb.round());

        return Row(
          children: [
            IconButton(
              key: const Key('leaderControlsPlayButton'),
              icon: const Icon(Icons.play_arrow),
              tooltip: l10n.videoSyncPlayButtonTooltip,
              onPressed: (!widget.isLeader || isPlaying)
                  ? null
                  : () => context.read<VideoSyncBloc>().add(
                      const VideoSyncEvent.playRequested(),
                    ),
            ),
            IconButton(
              key: const Key('leaderControlsPauseButton'),
              icon: const Icon(Icons.pause),
              tooltip: l10n.videoSyncPauseButtonTooltip,
              onPressed: (!widget.isLeader || !isPlaying)
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
                  max: maximum,
                  value: thumb.clamp(0, maximum),
                  semanticFormatterCallback: (value) =>
                      LeaderControls.formatPosition(
                        Duration(seconds: value.round()),
                      ),
                  onChangeStart: !canSeek
                      ? null
                      : (value) => setState(() {
                          _isDragging = true;
                          _thumbValue = value;
                        }),
                  // Only updates the local value. Dispatching here — as
                  // this widget previously did — turned a single gesture
                  // into dozens of Firebase writes, each one propagated
                  // to every viewer and executed there as a separate
                  // seekTo.
                  onChanged: !canSeek
                      ? null
                      : (value) => setState(() => _thumbValue = value),
                  onChangeEnd: !canSeek
                      ? null
                      : (value) {
                          final bloc = context.read<VideoSyncBloc>();
                          setState(() {
                            _isDragging = false;
                            _thumbValue = value;
                            _stateAtRelease = bloc.state;
                          });
                          bloc.add(
                            VideoSyncEvent.seekRequested(
                              Duration(seconds: value.round()),
                            ),
                          );
                        },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                // Follows the thumb rather than the state: during a drag
                // the user needs to read the position being aimed at,
                // not the one being left behind.
                '${LeaderControls.formatPosition(thumbPosition)}'
                ' / '
                '${LeaderControls.formatPosition(Duration(seconds: widget.durationSeconds))}',
                key: const Key('leaderControlsPositionReadout'),
              ),
            ),
          ],
        );
      },
    );
  }
}
