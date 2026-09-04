import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/services/sync_engine.dart';
import '../../domain/value_objects/sync_command.dart';
import '../../domain/value_objects/video_sync_config.dart';
import '../bloc/video_sync_bloc.dart';
import '../bloc/video_sync_event.dart';
import '../bloc/video_sync_state.dart';
import 'youtube_player_controller_adapter.dart';

/// Wraps [child] (expected to be the room's `YouTubePlayerWidget`) and
/// drives the local player from the ancestor [VideoSyncBloc]'s state,
/// per `YouTogether_Ad_Synchronisation_Strategy.docx`.
///
/// Has two independent responsibilities:
///
/// 1. **State-driven alignment** (a `BlocListener`): brings the local
///    player to the position and playback state the bloc has settled
///    on, whenever it transitions to [VideoSyncState.ready],
///    [VideoSyncState.playing] or [VideoSyncState.paused]. This is the
///    *only* place in the application that calls `play()`/`pause()` on
///    the local player — never `LeaderControls` or
///    `YouTubePlayerWidget` directly, and never in response to a
///    non-leader's tap: those are structurally prevented from ever
///    reaching this point (`YouTubePlayerWidget` hides native controls
///    for non-leaders; `LeaderControls` disables its buttons
///    for non-leaders; `VideoSyncBloc`'s command handlers are
///    themselves leader-gated no-ops) — every play/pause the
///    local player ever performs originates from a leader's action,
///    written to Firebase, and arrives back here as a
///    [VideoSyncState] transition, for the leader's own player exactly
///    as much as every viewer's.
///
///    The position carried by those states was, until F-V07-T2, never
///    applied: the listener issued `play()`/`pause()` and nothing else,
///    so no player ever moved in response to a state transition. Since
///    `LeaderControls` renders its slider from that same `position`,
///    the defect was observed as two apparently distinct symptoms — a
///    late joiner stuck at zero, and viewers whose slider followed the
///    leader's seek while their player did not. Both are this one
///    missing call site.
///
/// 2. **Periodic drift/ad reconciliation** (a `Timer`, sampling every
///    [VideoSyncConfig.adDetectionInterval]): reads
///    [controller.getCurrentSample], feeds it to [SyncEngine.detectAd]
///    and [SyncEngine.evaluateReconciliation], and executes only
///    `seekTo` — never `play()`/`pause()` — against [controller]. Ad
///    transitions are reported to [VideoSyncBloc] via
///    [VideoSyncEvent.adDetected]/[VideoSyncEvent.adEnded] purely for UI
///    state ([VideoSyncState.adInProgress]); the actual catch-up
///    `seekTo` happens here, not in the bloc.
///
/// Both responsibilities take their target position from
/// [VideoSyncBloc.expectedPosition], never from a
/// [VideoSyncState]'s own `position` field and never by extrapolating
/// locally. The bloc owns that rule — including its clock, its
/// clock-skew guard and its duration bound — so that the listener and
/// the timer cannot disagree about where this player is supposed to be,
/// and so that neither reaches for `DateTime.now()` on its own.
/// A state's `position` remains a presentation value, frozen at the
/// instant it was emitted, and is consumed as such by `LeaderControls`
/// for its slider.
///
/// @see SyncEngine — the pure Dart computation this widget is the sole
///   consumer of
/// @see VideoSyncBloc.expectedPosition — the single definition of the
///   target position
class PlayerReconciliation extends StatefulWidget {
  const PlayerReconciliation({
    super.key,
    required this.controller,
    required this.child,
    SyncEngine? syncEngine,
    this.samplingInterval = VideoSyncConfig.adDetectionInterval,
  }) : _syncEngine = syncEngine;

  final YoutubePlayerControllerAdapter controller;
  final Widget child;
  final Duration samplingInterval;

  /// Overridable for tests; defaults to a real [SyncEngine] otherwise.
  final SyncEngine? _syncEngine;

  @override
  State<PlayerReconciliation> createState() => PlayerReconciliationState();
}

class PlayerReconciliationState extends State<PlayerReconciliation> {
  late final SyncEngine _syncEngine = widget._syncEngine ?? SyncEngine();
  Timer? _timer;
  Duration? _previousPosition;
  bool _adInProgress = false;
  bool _readySignalled = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.samplingInterval, (_) => tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Performs a single sampling/reconciliation pass. Exposed
  /// (`@visibleForTesting` in spirit, though this class is already
  /// prefixed `PlayerReconciliationState` rather than private,
  /// specifically so tests can call it directly via a `GlobalKey`
  /// rather than waiting on the real [Timer] — see this file's own test
  /// suite for why).
  Future<void> tick() async {
    final bloc = context.read<VideoSyncBloc>();
    final sample = await widget.controller.getCurrentSample();

    final previous = _previousPosition;
    if (previous == null) {
      // First sample only establishes the baseline: with no prior
      // reading to compare against, treating position-equals-itself as
      // "stagnant" would flag every reconciliation session as starting
      // mid-advertisement, which is never actually the case.
      _previousPosition = sample.position;
      return;
    }

    final isAdNow = _syncEngine.detectAd(
      playerState: sample.state,
      currentTime: sample.position,
      previousTime: previous,
    );

    if (isAdNow && !_adInProgress) {
      _adInProgress = true;
      bloc.add(const VideoSyncEvent.adDetected());
    } else if (!isAdNow && _adInProgress) {
      _adInProgress = false;
      bloc.add(const VideoSyncEvent.adEnded());
      // Awaited, as is every other call to `_reconcile`: the method
      // became asynchronous in F-V07-T2, when the `seekTo` it issues
      // started being awaited rather than fired and forgotten.
      // Omitting the `await` here leaves that `seekTo` pending past the
      // end of the enclosing `tick()` — invisible in production, and
      // immediately fatal to any test that awaits a tick and then
      // asserts on the calls it produced.
      await _reconcile(bloc, sample, adInProgress: false);
    } else if (!isAdNow) {
      // while the ready gate is open, confirmed
      // *content* progression (not an ad) is exactly the signal that
      // this participant is past its pre-roll. Signalled once per
      // barrier — `_readySignalled` guards against re-incrementing
      // `ready_count` on every subsequent tick, which would otherwise
      // drive the count past `total_count` on its own and resolve the
      // barrier spuriously.
      if (bloc.state is VideoSyncBarrierWaiting && !_readySignalled) {
        _readySignalled = true;
        bloc.add(const VideoSyncEvent.readySignalled());
      }
      await _reconcile(bloc, sample, adInProgress: false);
    }

    _previousPosition = sample.position;
  }

  Future<void> _reconcile(
    VideoSyncBloc bloc,
    PlayerSample sample, {
    required bool adInProgress,
  }) async {
    final expected = bloc.expectedPosition;
    if (expected == null) return;

    await _executeCommand(
      _syncEngine.evaluateReconciliation(
        expectedPosition: expected,
        observedPosition: sample.position,
        adInProgress: adInProgress,
      ),
    );
  }

  /// Brings the local player in line with [state]: seeks to the
  /// expected position if it has drifted, then applies the playback
  /// intent that state carries.
  ///
  /// Public for the same reason [tick] is — the `BlocListener`'s
  /// callback cannot itself be `async`, so this is the seam the test
  /// suite drives directly.
  ///
  /// The two halves are deliberately independent. Playback intent is
  /// carried by the state itself and is therefore applied
  /// unconditionally; only the seek depends on
  /// [VideoSyncBloc.expectedPosition] being known. An earlier revision
  /// returned early whenever no expected position was available, which
  /// silently dropped the play/pause along with the seek — a state
  /// saying "play" must still start the player even when there is no
  /// authoritative position to align it to.
  ///
  /// The seek is gated by [SyncEngine.evaluateReconciliation] rather
  /// than issued unconditionally. Once F-V08-T1 adds the leader's
  /// position heartbeat, [VideoSyncState.playing] transitions arrive on
  /// a fixed cadence and not only on the leader's commands; seeking to
  /// a position the player already holds would then produce a visible
  /// stutter every few seconds. `adInProgress: false` is correct here
  /// because [_playbackIntentFor] yields `null` for
  /// [VideoSyncState.adInProgress], so an advertisement never reaches
  /// this method.
  ///
  /// Seek before play/pause, deliberately. The IFrame Player API starts
  /// playback when `seekTo` is called from any state other than
  /// `paused`, so a seek issued against a freshly cued player in a
  /// paused room would start it; the `pause()` that immediately follows
  /// settles it. The reverse order would leave that unwanted playback
  /// running until the next timer tick.
  ///
  /// No attempt is made to detect whether the player is ready to honour
  /// the seek. If one is lost — against a player still loading, say —
  /// the periodic loop re-issues it within one sampling interval, which
  /// is precisely what that loop is for. Holding the alignment in a
  /// field until the player looks ready was considered and rejected: a
  /// player cued in a paused room never leaves `cued` on its own, so
  /// the deferred alignment would never be applied at all.
  Future<void> applyState(VideoSyncState state) async {
    final shouldPlay = _playbackIntentFor(state);
    if (shouldPlay == null) return;

    final bloc = context.read<VideoSyncBloc>();
    final expected = bloc.expectedPosition;

    if (expected != null) {
      final sample = await widget.controller.getCurrentSample();

      await _executeCommand(
        _syncEngine.evaluateReconciliation(
          expectedPosition: expected,
          observedPosition: sample.position,
          adInProgress: false,
        ),
      );
    }

    if (shouldPlay) {
      await widget.controller.play();
    } else {
      await widget.controller.pause();
    }
  }

  /// Whether [state] demands that the local player be playing (`true`),
  /// paused (`false`), or that it be left entirely alone (`null`).
  ///
  /// [VideoSyncAdInProgress] yields `null` deliberately: leader updates
  /// keep arriving during a local advertisement and are stored on the
  /// bloc, but applying them would fight the advertisement currently
  /// occupying the player. Catch-up happens once progression resumes,
  /// through [VideoSyncEvent.adEnded] and the state that follows it.
  /// [VideoSyncBarrierWaiting] likewise yields `null` — the entire
  /// purpose of the ready gate is that no participant moves until it
  /// resolves.
  bool? _playbackIntentFor(VideoSyncState state) {
    return switch (state) {
      VideoSyncReady(:final isPlaying) => isPlaying,
      VideoSyncPlaying() => true,
      VideoSyncPaused() => false,
      VideoSyncInitial() ||
      VideoSyncLoading() ||
      VideoSyncFailure() ||
      VideoSyncAdInProgress() ||
      VideoSyncBarrierWaiting() => null,
    };
  }

  /// Executes a [SyncCommand] against the local player.
  ///
  /// Shared by [applyState] and [_reconcile] so that the one place
  /// translating a domain command into a player call stays one place.
  Future<void> _executeCommand(SyncCommand command) async {
    if (command is SyncCommandSeekTo) {
      await widget.controller.seekTo(command.target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VideoSyncBloc, VideoSyncState>(
      listener: (context, state) => unawaited(applyState(state)),
      child: widget.child,
    );
  }
}
