import '../../presentation/widgets/youtube_player_controller_adapter.dart';
import '../value_objects/ready_gate_result.dart';
import '../value_objects/sync_command.dart';
import '../value_objects/video_sync_config.dart';

/// Pure Dart domain service computing advertisement-aware
/// synchronisation decisions.
///
/// Deliberately has no dependency on Flutter, Firebase, or the YouTube
/// player SDK — every method here is a pure function over plain
/// [Duration]/[PlayerAdapterState] values, taking timestamps and player
/// states as input and returning [SyncCommand]/[ReadyGateResult]/`bool`
/// values. `PlayerReconciliation` (presentation layer) is the only
/// consumer that touches an actual player or Firebase; this class
/// never does, which is what makes the whole ad-recovery/ready-gate
/// logic exhaustively unit-testable per the source document's own
/// stated rationale ("This design enables comprehensive unit testing
/// under TDD methodology").
///
/// @see VideoSyncConfig — the configurable thresholds this service
///   defaults to
/// @see PlayerReconciliation — the presentation-layer consumer
class SyncEngine {
  /// Computes the position a player *should* be at right now, given the
  /// leader's last known [leaderPosition] and whether it was playing at
  /// the time it was reported.
  ///
  /// When playing, the elapsed wall-clock time since that report is
  /// added — this is the same formula used for drift correction after
  /// a mid-roll advertisement, app backgrounding,
  /// and late join: all three scenarios reduce
  /// to "how far should content have advanced since the last known
  /// leader state," so one formula serves all of them rather than a
  /// distinct code path per scenario, per the source document's own
  /// statement that backgrounding recovery "is identical to the
  /// mid-roll recovery workflow and does not require a distinct code
  /// path."
  Duration computeExpectedPosition({
    required Duration leaderPosition,
    required bool isPlaying,
    required Duration elapsedSinceUpdate,
  }) {
    if (!isPlaying) {
      return leaderPosition;
    }
    return leaderPosition + elapsedSinceUpdate;
  }

  /// Detection heuristic for an in-progress advertisement:
  /// the player reports [PlayerAdapterState.playing], but
  /// [currentTime] has not advanced by more than
  /// [VideoSyncConfig.adDetectionMinDelta] relative to [previousTime].
  ///
  /// Always returns `false` while [playerState] is
  /// [PlayerAdapterState.buffering] — a frozen timestamp during
  /// buffering is a network condition, not an advertisement, per the
  /// source document's own explicit guidance against that false
  /// positive.
  ///
  /// The caller (`PlayerReconciliation`) is responsible for sampling
  /// [currentTime] at [VideoSyncConfig.adDetectionInterval] and
  /// supplying the previous sample here — this method itself holds no
  /// state between calls, consistent with every other method on this
  /// class being a pure function.
  bool detectAd({
    required PlayerAdapterState playerState,
    required Duration currentTime,
    required Duration previousTime,
    Duration minDelta = VideoSyncConfig.adDetectionMinDelta,
  }) {
    if (playerState == PlayerAdapterState.buffering) {
      return false;
    }
    if (playerState != PlayerAdapterState.playing) {
      return false;
    }

    final delta = (currentTime - previousTime).abs();
    return delta <= minDelta;
  }

  /// Decides what the presentation layer should do given the currently
  /// [expectedPosition] (from [computeExpectedPosition]), the
  /// [observedPosition] actually reported by the local player, and
  /// whether an advertisement is currently believed to be in progress
  /// (from [detectAd]).
  ///
  /// - [adInProgress] takes priority: [SyncCommand.wait] is returned
  ///   regardless of drift — the leader's timestamp is still tracked,
  ///   but never applied to a player mid-advertisement.
  /// - Otherwise, a [SyncCommand.seekTo] is returned only once drift
  ///   exceeds [driftThreshold]; [SyncCommand.none] otherwise.
  SyncCommand evaluateReconciliation({
    required Duration expectedPosition,
    required Duration observedPosition,
    required bool adInProgress,
    Duration driftThreshold = VideoSyncConfig.syncDriftThreshold,
  }) {
    if (adInProgress) {
      return const SyncCommand.wait();
    }

    final drift = (expectedPosition - observedPosition).abs();
    if (drift > driftThreshold) {
      return SyncCommand.seekTo(expectedPosition);
    }

    return const SyncCommand.none();
  }

  /// Evaluates the `sync_barrier` ready-gate state machine,
  /// given the current [readyCount]/[totalCount] (read from Firebase)
  /// and how long the barrier has existed ([elapsedSinceCreated]).
  ///
  /// [ReadyGateResult.allReady] takes priority over
  /// [ReadyGateResult.timedOut] when both conditions hold simultaneously
  /// — every participant actually becoming ready is always preferable
  /// to a forced start, even if that happens to occur at or after the
  /// timeout instant.
  ReadyGateResult evaluateReadyGate({
    required int readyCount,
    required int totalCount,
    required Duration elapsedSinceCreated,
    Duration timeout = VideoSyncConfig.readyGateTimeout,
  }) {
    if (readyCount >= totalCount) {
      return ReadyGateResult.allReady;
    }
    if (elapsedSinceCreated >= timeout) {
      return ReadyGateResult.timedOut;
    }
    return ReadyGateResult.waiting;
  }
}
