import 'dart:async';
import 'dart:developer' as developer;

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
    this.onReconciliationDegraded,
  }) : _syncEngine = syncEngine;

  final YoutubePlayerControllerAdapter controller;
  final Widget child;
  final Duration samplingInterval;

  /// Reports whether the reconciliation loop is currently degraded,
  /// once per transition in either direction.
  ///
  /// `true` when [VideoSyncConfig.sampleFailureThreshold] consecutive
  /// sample reads have failed, `false` again on the first successful
  /// read thereafter. Both edges matter: an indicator raised on failure
  /// and never lowered would keep reporting a fault that has since
  /// cleared.
  ///
  /// Deliberately a callback rather than a [VideoSyncState] transition.
  /// `VideoSyncState.failure` drives `SyncStatusBanner`, whose retry
  /// re-runs the whole `sessionJoined` sequence — which repairs nothing
  /// when the fault is a detached local player, and would present a
  /// local player fault as a Firebase outage.
  final ValueChanged<bool>? onReconciliationDegraded;

  /// Overridable for tests; defaults to a real [SyncEngine] otherwise.
  final SyncEngine? _syncEngine;

  @override
  State<PlayerReconciliation> createState() => PlayerReconciliationState();
}

class PlayerReconciliationState extends State<PlayerReconciliation> {
  late final SyncEngine _syncEngine = widget._syncEngine ?? SyncEngine();
  Timer? _timer;
  Duration? _previousPosition;

  /// Guards against a second [tick] starting while the first is still
  /// awaiting its sample. Overlapping ticks would interleave their
  /// writes to [_previousPosition] and hand `SyncEngine.detectAd` a
  /// comparison between two readings taken in the wrong order.
  bool _tickInFlight = false;

  /// Consecutive failed sample reads, reset by any successful one.
  int _consecutiveSampleFailures = 0;

  /// Whether the degraded transition has already been reported, so the
  /// callback fires on crossings only and not on every tick.
  bool _degraded = false;
  bool _adInProgress = false;
  bool _readySignalled = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.samplingInterval, (_) => unawaited(tick()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Performs a single sampling/reconciliation pass.
  ///
  /// Never completes with an error: every failure path is handled
  /// internally, because the only caller is a [Timer] callback whose
  /// returned future nobody can observe.
  Future<void> tick() async {
    if (_tickInFlight) {
      // Time has passed without a reading; the next successful sample
      // is no longer one interval away from [_previousPosition].
      _previousPosition = null;
      return;
    }

    _tickInFlight = true;
    try {
      await _performTick();
    } finally {
      _tickInFlight = false;
    }
  }

  Future<void> _performTick() async {
    if (!mounted) return;

    // Captured before the first suspension point: reading the context
    // after an await risks doing so on an unmounted element, the same
    // failure mode corrected on the authentication cubits in Sprint 2.
    final bloc = context.read<VideoSyncBloc>();

    final PlayerSample sample;
    try {
      sample = await widget.controller.getCurrentSample().timeout(
        widget.samplingInterval,
      );
    } catch (error, stackTrace) {
      _handleSampleFailure(error, stackTrace);
      return;
    }

    if (!mounted) return;
    _consecutiveSampleFailures = 0;
    if (_degraded) {
      _degraded = false;
      widget.onReconciliationDegraded?.call(false);
    }

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
      // Forwarded unconditionally: the bloc discards it unless this
      // participant is the leader and content is actually progressing,
      // and throttles it to the heartbeat interval. Deciding any of that
      // here would put the leader-gating rule in a second place.
      //
      // This branch, and not the ad-recovery one above it: reaching here
      // means `detectAd` has cleared this reading, so a position frozen
      // by an advertisement is never republished. The ad-recovery branch
      // is excluded for a different reason — the position observed at
      // that exact instant is still the pre-catch-up one, since
      // `_reconcile` has not yet run.
      bloc.add(VideoSyncEvent.heartbeatTicked(position: sample.position));
      await _reconcile(bloc, sample, adInProgress: false);
    }

    _previousPosition = sample.position;
  }

  void _handleSampleFailure(Object error, StackTrace stackTrace) {
    // A gap in the sequence invalidates the ad-detection baseline: the
    // next successful reading is more than one interval away from the
    // last one, so it must be treated as a fresh baseline rather than
    // compared against a stale predecessor.
    _previousPosition = null;
    _consecutiveSampleFailures++;

    // Logged through `dart:developer`, deliberately not through
    // `FlutterError.reportError`. The latter routes into
    // `FlutterError.onError`, which `flutter_test` overrides to record
    // every reported error as a test failure — `silent: true` only
    // suppresses the console output, not the recording. Every test that
    // exercises a deliberate read failure would therefore fail on the
    // report rather than on its own assertion. A failed sample read is
    // a handled, recoverable condition, not a framework error, so
    // `FlutterError` is the wrong channel for it in any case.
    developer.log(
      'Player sample read failed during reconciliation',
      name: 'video_sync',
      error: error,
      stackTrace: stackTrace,
      level: 900,
    );

    // Reported on the crossing only. Repeating it every sampling
    // interval would replace a silent failure with an equally useless
    // flood; a successful read resets the counter, so a later
    // degradation reports again.
    if (!_degraded &&
        _consecutiveSampleFailures >= VideoSyncConfig.sampleFailureThreshold) {
      _degraded = true;
      widget.onReconciliationDegraded?.call(true);
    }
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
  /// authoritative position to align it to. The same independence
  /// holds when the sample read fails: the failure costs the seek,
  /// never the play or the pause.
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
      // Contained exactly as the periodic loop's own read is, and for
      // the same reason: this method is called through `unawaited` from
      // a `BlocListener` callback, which cannot be `async`. An
      // exception escaping here would become an unobserved asynchronous
      // error — the silent-failure mode F-V07-T3 removed from [tick],
      // walking back in through the other door.
      PlayerSample? sample;
      try {
        sample = await widget.controller.getCurrentSample().timeout(
          widget.samplingInterval,
        );
      } catch (error, stackTrace) {
        _handleSampleFailure(error, stackTrace);
      }

      if (!mounted) return;

      if (sample != null) {
        await _executeCommand(
          _syncEngine.evaluateReconciliation(
            expectedPosition: expected,
            observedPosition: sample.position,
            adInProgress: false,
          ),
        );
      }
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
