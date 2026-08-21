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
/// 1. **State-driven playback execution** (a `BlocListener`): calls
///    [controller]`.play()`/`.pause()` when the bloc transitions to
///    [VideoSyncState.playing]/[VideoSyncState.paused]. This is the
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
/// 2. **Periodic drift/ad reconciliation** (a `Timer`, sampling every
///    [VideoSyncConfig.adDetectionInterval]): reads
///    [controller.getCurrentSample], feeds it to [SyncEngine.detectAd]
///    and [SyncEngine.evaluateReconciliation]/[SyncEngine.computeExpectedPosition],
///    and executes only `seekTo` — never `play()`/`pause()` — against
///    [controller]. Ad transitions are reported to [VideoSyncBloc] via
///    [VideoSyncEvent.adDetected]/[VideoSyncEvent.adEnded] purely for UI
///    state ([VideoSyncState.adInProgress]); the actual catch-up
///    computation and `seekTo` happen here, not in the bloc.
///
/// @see SyncEngine — the pure Dart computation this widget is the sole
///   consumer of
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
      _reconcile(bloc, sample, adInProgress: false);
    } else if (!isAdNow) {
      _reconcile(bloc, sample, adInProgress: false);
    }

    _previousPosition = sample.position;
  }

  void _reconcile(
    VideoSyncBloc bloc,
    PlayerSample sample, {
    required bool adInProgress,
  }) {
    final session = bloc.lastKnownSession;
    if (session == null) return;

    final expected = _syncEngine.computeExpectedPosition(
      leaderPosition: session.currentPosition,
      isPlaying: session.isPlaying,
      elapsedSinceUpdate: DateTime.now().toUtc().difference(session.updatedAt),
    );

    final command = _syncEngine.evaluateReconciliation(
      expectedPosition: expected,
      observedPosition: sample.position,
      adInProgress: adInProgress,
    );

    if (command is SyncCommandSeekTo) {
      widget.controller.seekTo(command.target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VideoSyncBloc, VideoSyncState>(
      listener: (context, state) {
        switch (state) {
          case VideoSyncPlaying():
            widget.controller.play();
          case VideoSyncPaused():
            widget.controller.pause();
          case VideoSyncInitial():
          case VideoSyncLoading():
          case VideoSyncReady():
          case VideoSyncFailure():
          case VideoSyncAdInProgress():
          case VideoSyncBarrierWaiting():
            break;
        }
      },
      child: widget.child,
    );
  }
}
