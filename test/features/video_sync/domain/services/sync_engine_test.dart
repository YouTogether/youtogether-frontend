import 'package:flutter_test/flutter_test.dart';

import 'package:youtogether/features/video_sync/domain/services/sync_engine.dart';
import 'package:youtogether/features/video_sync/domain/value_objects/ready_gate_result.dart';
import 'package:youtogether/features/video_sync/domain/value_objects/sync_command.dart';
import 'package:youtogether/features/video_sync/domain/value_objects/video_sync_config.dart';
import 'package:youtogether/features/video_sync/presentation/widgets/youtube_player_controller_adapter.dart';

/// Unit tests for [SyncEngine].
///
/// [SyncEngine] is a pure Dart service (no Flutter, Firebase, or
/// YouTube player dependency) — every test below
/// constructs plain [Duration]/[PlayerAdapterState] inputs and asserts
/// on the returned [SyncCommand]/[ReadyGateResult], with no mocking
/// required.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios.
void main() {
  late SyncEngine engine;

  setUp(() {
    engine = SyncEngine();
  });

  group('SyncEngine.computeExpectedPosition', () {
    test('should return leaderPosition unchanged when not playing', () {
      final result = engine.computeExpectedPosition(
        leaderPosition: const Duration(seconds: 120),
        isPlaying: false,
        elapsedSinceUpdate: const Duration(seconds: 30),
      );

      expect(result, const Duration(seconds: 120));
    });

    test(
      'should add elapsed wall-clock time when playing (T08: background/resume)',
      () {
        final result = engine.computeExpectedPosition(
          leaderPosition: const Duration(seconds: 300),
          isPlaying: true,
          elapsedSinceUpdate: const Duration(seconds: 20),
        );

        expect(result, const Duration(seconds: 320));
      },
    );
  });

  group('SyncEngine.detectAd', () {
    test('T02: should report no ad when the timestamp progresses normally', () {
      final isAd = engine.detectAd(
        playerState: PlayerAdapterState.playing,
        currentTime: const Duration(seconds: 10, milliseconds: 500),
        previousTime: const Duration(seconds: 10),
      );

      expect(isAd, isFalse);
    });

    test(
      'T01/T03: should report an ad when PLAYING but the timestamp is frozen',
      () {
        final isAd = engine.detectAd(
          playerState: PlayerAdapterState.playing,
          currentTime: const Duration(seconds: 120),
          previousTime: const Duration(seconds: 120),
        );

        expect(isAd, isTrue);
      },
    );

    test(
      'T11: should not report an ad while BUFFERING, even with a frozen timestamp',
      () {
        final isAd = engine.detectAd(
          playerState: PlayerAdapterState.buffering,
          currentTime: const Duration(milliseconds: 500),
          previousTime: const Duration(milliseconds: 500),
        );

        expect(isAd, isFalse);
      },
    );

    test(
      'should classify a change smaller than adDetectionMinDelta as stagnation (ad)',
      () {
        // A 0.05s change is below the 0.1s adDetectionMinDelta threshold,
        // so it is still classified as stagnant per the spec's literal
        // wording ("has not changed by more than 0.1 seconds").
        final isAd = engine.detectAd(
          playerState: PlayerAdapterState.playing,
          currentTime: const Duration(milliseconds: 50),
          previousTime: Duration.zero,
        );

        expect(isAd, isTrue);
      },
    );
  });

  group('SyncEngine.evaluateReconciliation', () {
    test(
      'T12: should return SyncCommand.none when drift is below the threshold (0.8s < 1.5s)',
      () {
        final command = engine.evaluateReconciliation(
          expectedPosition: const Duration(seconds: 100, milliseconds: 800),
          observedPosition: const Duration(seconds: 100),
          adInProgress: false,
        );

        expect(command, const SyncCommand.none());
      },
    );

    test(
      'T03: should return SyncCommand.seekTo(expected) when drift exceeds the threshold and no ad',
      () {
        final command = engine.evaluateReconciliation(
          expectedPosition: const Duration(seconds: 135),
          observedPosition: const Duration(seconds: 120),
          adInProgress: false,
        );

        expect(command, const SyncCommand.seekTo(Duration(seconds: 135)));
      },
    );

    test(
      'should return SyncCommand.wait when an ad is in progress, regardless of drift',
      () {
        final command = engine.evaluateReconciliation(
          expectedPosition: const Duration(seconds: 135),
          observedPosition: const Duration(seconds: 120),
          adInProgress: true,
        );

        expect(command, const SyncCommand.wait());
      },
    );

    test('should use a custom drift threshold when provided', () {
      final command = engine.evaluateReconciliation(
        expectedPosition: const Duration(seconds: 101),
        observedPosition: const Duration(seconds: 100),
        adInProgress: false,
        driftThreshold: const Duration(milliseconds: 500),
      );

      expect(command, const SyncCommand.seekTo(Duration(seconds: 101)));
    });

    test(
      'defaults the drift threshold to VideoSyncConfig.syncDriftThreshold',
      () {
        final justUnderThreshold = engine.evaluateReconciliation(
          expectedPosition:
              VideoSyncConfig.syncDriftThreshold -
              const Duration(milliseconds: 1),
          observedPosition: Duration.zero,
          adInProgress: false,
        );
        final justOverThreshold = engine.evaluateReconciliation(
          expectedPosition:
              VideoSyncConfig.syncDriftThreshold +
              const Duration(milliseconds: 1),
          observedPosition: Duration.zero,
          adInProgress: false,
        );

        expect(justUnderThreshold, const SyncCommand.none());
        expect(justOverThreshold, isA<SyncCommandSeekTo>());
      },
    );
  });

  group('SyncEngine.evaluateReadyGate', () {
    test(
      'T05: should return allReady once readyCount >= totalCount, well within timeout',
      () {
        final result = engine.evaluateReadyGate(
          readyCount: 3,
          totalCount: 3,
          elapsedSinceCreated: const Duration(seconds: 5),
        );

        expect(result, ReadyGateResult.allReady);
      },
    );

    test(
      'should return waiting when not every participant is ready yet and timeout has not elapsed',
      () {
        final result = engine.evaluateReadyGate(
          readyCount: 2,
          totalCount: 3,
          elapsedSinceCreated: const Duration(seconds: 10),
        );

        expect(result, ReadyGateResult.waiting);
      },
    );

    test(
      'T06: should return timedOut when the timeout elapses before every participant is ready',
      () {
        final result = engine.evaluateReadyGate(
          readyCount: 2,
          totalCount: 3,
          elapsedSinceCreated: const Duration(seconds: 20),
        );

        expect(result, ReadyGateResult.timedOut);
      },
    );

    test(
      'should prioritise allReady over timedOut when both conditions hold',
      () {
        final result = engine.evaluateReadyGate(
          readyCount: 3,
          totalCount: 3,
          elapsedSinceCreated: const Duration(seconds: 25),
        );

        expect(result, ReadyGateResult.allReady);
      },
    );

    test('should use a custom timeout when provided', () {
      final result = engine.evaluateReadyGate(
        readyCount: 0,
        totalCount: 2,
        elapsedSinceCreated: const Duration(seconds: 3),
        timeout: const Duration(seconds: 2),
      );

      expect(result, ReadyGateResult.timedOut);
    });
  });
}
