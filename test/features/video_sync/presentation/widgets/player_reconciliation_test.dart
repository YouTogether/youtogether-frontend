import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/features/video_sync/domain/entities/video_session_entity.dart';
import 'package:youtogether/features/video_sync/domain/value_objects/video_sync_config.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_bloc.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_event.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_state.dart';
import 'package:youtogether/features/video_sync/presentation/widgets/player_reconciliation.dart';
import 'package:youtogether/features/video_sync/presentation/widgets/youtube_player_controller_adapter.dart';

class MockVideoSyncBloc extends MockBloc<VideoSyncEvent, VideoSyncState>
    implements VideoSyncBloc {
  @override
  VideoSessionEntity? lastKnownSession;

  /// The widget's sole source of target positions since F-V07-T2.
  ///
  /// On the real bloc this is derived from [lastKnownSession] through
  /// `SyncEngine.computeExpectedPosition`; here the two are independent
  /// fields, so a test that sets only [lastKnownSession] leaves this
  /// `null`.
  ///
  /// Leaving it `null` is a meaningful case rather than a broken
  /// fixture: the widget must still apply the playback intent carried
  /// by the state and simply skip the seek, so that an unknown position
  /// never costs the user a play or a pause.
  @override
  Duration? expectedPosition;
}

class FakeController implements YoutubePlayerControllerAdapter {
  FakeController({required this.videoId});

  @override
  final String videoId;

  @override
  VoidCallback? onReady;
  @override
  ValueChanged<PlayerAdapterState>? onStateChange;
  @override
  ValueChanged<String>? onError;

  final List<String> calls = [];

  PlayerSample sample = const PlayerSample(
    position: Duration.zero,
    state: PlayerAdapterState.playing,
  );

  /// Number of times [getCurrentSample] was entered, used to assert
  /// that an overlapping tick performed no read at all.
  int sampleReads = 0;

  /// When non-null, [getCurrentSample] throws it instead of returning.
  Object? sampleError;

  /// When non-null, [getCurrentSample] awaits it before returning,
  /// letting a test hold one read open across another tick or past the
  /// timeout.
  Completer<PlayerSample>? sampleGate;

  @override
  Widget buildView() => const SizedBox();

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> seekTo(Duration position) async => calls.add('seekTo:$position');

  @override
  Future<PlayerSample> getCurrentSample() async {
    sampleReads++;
    final error = sampleError;
    if (error != null) throw error;
    final gate = sampleGate;
    if (gate != null) return gate.future;
    return sample;
  }

  @override
  void dispose() {}
}

/// Widget/unit tests for [PlayerReconciliation].
///
/// [PlayerReconciliationState.tick] is invoked directly rather than
/// waiting on a real `Timer.periodic` firing — mirroring
/// `buildPlayerSurface`'s own precedent (`youtube_player_widget_test.dart`)
/// of extracting the platform/timing-sensitive seam into something
/// directly callable in a test, since `flutter_test`'s fake async clock
/// does not reliably drive real-world `Timer.periodic` ticks paired with
/// awaited `Future`s inside them.
///
/// Every group shares the single [mount] helper and the single pair of
/// `bloc`/`controller` fixtures declared here. An earlier draft of this
/// suite redeclared both inside individual groups, shadowing the outer
/// ones: any group-local test reaching for a shared helper would have
/// driven a different bloc than the one it had just configured, and the
/// failure would have read as a widget bug rather than a fixture one.
///
/// @competency Unit/widget test harness.
/// @competency Test scenarios drift/ad reconciliation,
///   presentation-layer slice; non-leader never drives the
///   local player directly.
void main() {
  late MockVideoSyncBloc bloc;
  late FakeController controller;

  setUpAll(() {
    registerFallbackValue(const VideoSyncEvent.adDetected());
  });

  setUp(() {
    bloc = MockVideoSyncBloc();
    controller = FakeController(videoId: 'dQw4w9WgXcQ');
  });

  /// Mounts the widget under test and returns its state.
  ///
  /// [states] drives the `BlocListener`: a `BlocListener` never fires
  /// for the state present at mount time, only for transitions, so a
  /// test exercising state-driven alignment must supply at least one
  /// entry here rather than relying on [initialState] alone.
  Future<PlayerReconciliationState> mount(
    WidgetTester tester, {
    required VideoSyncState initialState,
    List<VideoSyncState> states = const [],
    Duration samplingInterval = VideoSyncConfig.adDetectionInterval,
    ValueChanged<bool>? onReconciliationDegraded,
  }) async {
    whenListen(
      bloc,
      Stream<VideoSyncState>.fromIterable(states),
      initialState: initialState,
    );
    final key = GlobalKey<PlayerReconciliationState>();

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<VideoSyncBloc>.value(
          value: bloc,
          child: PlayerReconciliation(
            key: key,
            controller: controller,
            samplingInterval: samplingInterval,
            onReconciliationDegraded: onReconciliationDegraded,
            child: const SizedBox(),
          ),
        ),
      ),
    );

    // Two frames: the first delivers the state transitions to the
    // listener, the second lets the asynchronous alignment chain each
    // one starts (sample read, then seek, then playback command) run to
    // completion before any assertion reads `controller.calls`.
    await tester.pump();
    await tester.pump();

    return key.currentState!;
  }

  group('BlocListener — playback execution', () {
    testWidgets(
      'calls controller.play() when the bloc transitions to playing, even '
      'with no expected position known',
      (tester) async {
        await mount(
          tester,
          initialState: const VideoSyncState.paused(position: Duration.zero),
          states: const [VideoSyncState.playing(position: Duration.zero)],
        );

        expect(controller.calls, contains('play'));
      },
    );

    testWidgets(
      'calls controller.pause() when the bloc transitions to paused, even '
      'with no expected position known',
      (tester) async {
        await mount(
          tester,
          initialState: const VideoSyncState.playing(position: Duration.zero),
          states: const [VideoSyncState.paused(position: Duration.zero)],
        );

        expect(controller.calls, contains('pause'));
      },
    );

    testWidgets(
      'reads no sample when the expected position is unknown: there is '
      'nothing to compare an observation against',
      (tester) async {
        await mount(
          tester,
          initialState: const VideoSyncState.paused(position: Duration.zero),
          states: const [VideoSyncState.playing(position: Duration.zero)],
        );

        expect(controller.sampleReads, 0);
        expect(controller.calls, ['play']);
      },
    );
  });

  group('Reconciliation tick — drift and ad detection', () {
    testWidgets('T12: no seekTo when drift is below threshold', (tester) async {
      bloc.expectedPosition = const Duration(seconds: 100);
      controller.sample = const PlayerSample(
        position: Duration(seconds: 100, milliseconds: 500),
        state: PlayerAdapterState.playing,
      );

      final state = await mount(
        tester,
        initialState: const VideoSyncState.playing(
          position: Duration(seconds: 100),
        ),
      );
      await state.tick(); // baseline
      await state.tick(); // same position -> would be "ad" if it were,
      // but the assertion below only cares that no seekTo happened.

      expect(controller.calls.where((c) => c.startsWith('seekTo')), isEmpty);
    });

    testWidgets(
      'T03-equivalent: seeks to the expected position once an ad ends',
      (tester) async {
        bloc.expectedPosition = const Duration(seconds: 135);

        final state = await mount(
          tester,
          initialState: const VideoSyncState.playing(
            position: Duration(seconds: 120),
          ),
        );

        // Tick 1: establishes the baseline sample (120s). No event yet.
        controller.sample = const PlayerSample(
          position: Duration(seconds: 120),
          state: PlayerAdapterState.playing,
        );
        await state.tick();
        verifyNever(() => bloc.add(const VideoSyncEvent.adDetected()));

        // Tick 2: still frozen at 120s while PLAYING -> ad detected.
        await state.tick();
        verify(() => bloc.add(const VideoSyncEvent.adDetected())).called(1);

        // Tick 3: timestamp still frozen -> still in ad, no adEnded yet.
        await state.tick();

        // Tick 4: progression resumes -> ad ended, catch-up seekTo.
        controller.sample = const PlayerSample(
          position: Duration(seconds: 121),
          state: PlayerAdapterState.playing,
        );
        await state.tick();

        verify(() => bloc.add(const VideoSyncEvent.adEnded())).called(1);
        expect(controller.calls, contains('seekTo:0:02:15.000000'));
      },
    );

    testWidgets(
      'never calls play() or pause() from the reconciliation tick itself',
      (tester) async {
        bloc.expectedPosition = const Duration(seconds: 200);
        controller.sample = const PlayerSample(
          position: Duration(seconds: 190),
          state: PlayerAdapterState.playing,
        );

        final state = await mount(
          tester,
          initialState: const VideoSyncState.playing(
            position: Duration(seconds: 200),
          ),
        );
        await state.tick(); // baseline
        await state.tick(); // reconciliation pass

        expect(controller.calls, isNot(contains('play')));
        expect(controller.calls, isNot(contains('pause')));
      },
    );
  });

  /// Regression tests for F-V07-T2.
  ///
  /// The `BlocListener` mapped `VideoSyncPlaying` to `play()` and
  /// `VideoSyncPaused` to `pause()`, and treated `VideoSyncReady` as a
  /// no-op. The `position` carried by all three was never applied, so
  /// no player ever moved in response to a state transition. Because
  /// `LeaderControls` renders its slider from that same `position`,
  /// viewers saw their slider follow the leader while their player
  /// stayed where it was — one defect observed as two symptoms.
  ///
  /// @competency Unit/widget test harness, TDD cycle.
  /// @competency Test scenarios VS-SYN-07, VS-SYN-08, VS-SYN-09,
  ///   VS-SYN-10.
  group('PlayerReconciliation — state-driven alignment (F-V07-T2)', () {
    testWidgets('seeks to the expected position and starts playback when the '
        'session is joined mid-playback (VS-SYN-07)', (tester) async {
      bloc.expectedPosition = const Duration(seconds: 220);
      controller.sample = const PlayerSample(
        position: Duration.zero,
        state: PlayerAdapterState.paused,
      );

      await mount(
        tester,
        initialState: const VideoSyncState.loading(),
        states: const [
          VideoSyncState.ready(
            position: Duration(seconds: 220),
            isPlaying: true,
          ),
        ],
      );

      expect(controller.calls, ['seekTo:0:03:40.000000', 'play']);
    });

    testWidgets('seeks to the expected position without starting playback '
        'when the session is joined while paused (VS-SYN-08)', (tester) async {
      bloc.expectedPosition = const Duration(seconds: 90);
      controller.sample = const PlayerSample(
        position: Duration.zero,
        state: PlayerAdapterState.paused,
      );

      await mount(
        tester,
        initialState: const VideoSyncState.loading(),
        states: const [
          VideoSyncState.ready(
            position: Duration(seconds: 90),
            isPlaying: false,
          ),
        ],
      );

      expect(controller.calls, ['seekTo:0:01:30.000000', 'pause']);
    });

    testWidgets('seeks when the leader moves the slider beyond the drift '
        'threshold (VS-SYN-09)', (tester) async {
      bloc.expectedPosition = const Duration(seconds: 400);
      controller.sample = const PlayerSample(
        position: Duration(seconds: 120),
        state: PlayerAdapterState.playing,
      );

      await mount(
        tester,
        initialState: const VideoSyncState.playing(
          position: Duration(seconds: 120),
        ),
        states: const [
          VideoSyncState.playing(position: Duration(seconds: 400)),
        ],
      );

      expect(controller.calls, ['seekTo:0:06:40.000000', 'play']);
    });

    testWidgets('does not seek when the player is already aligned: a leader '
        'heartbeat must not produce a visible jump (VS-SYN-10)', (
      tester,
    ) async {
      bloc.expectedPosition = const Duration(seconds: 300);
      controller.sample = const PlayerSample(
        position: Duration(seconds: 300, milliseconds: 400),
        state: PlayerAdapterState.playing,
      );

      await mount(
        tester,
        initialState: const VideoSyncState.playing(
          position: Duration(seconds: 295),
        ),
        states: const [
          VideoSyncState.playing(position: Duration(seconds: 300)),
        ],
      );

      expect(controller.calls, ['play']);
    });

    testWidgets('aligns a cued player immediately: a loaded video accepts a '
        'seek before playback has ever started (VS-SYN-08)', (tester) async {
      bloc.expectedPosition = const Duration(seconds: 90);
      controller.sample = const PlayerSample(
        position: Duration.zero,
        state: PlayerAdapterState.cued,
      );

      await mount(
        tester,
        initialState: const VideoSyncState.loading(),
        states: const [
          VideoSyncState.ready(
            position: Duration(seconds: 90),
            isPlaying: false,
          ),
        ],
      );

      expect(controller.calls, ['seekTo:0:01:30.000000', 'pause']);
    });

    testWidgets('aligns an unstarted player anyway: a seek lost against a '
        'player still loading is re-issued by the periodic loop', (
      tester,
    ) async {
      bloc.expectedPosition = const Duration(seconds: 220);
      controller.sample = const PlayerSample(
        position: Duration.zero,
        state: PlayerAdapterState.unstarted,
      );

      await mount(
        tester,
        initialState: const VideoSyncState.loading(),
        states: const [
          VideoSyncState.ready(
            position: Duration(seconds: 220),
            isPlaying: true,
          ),
        ],
      );

      // Holding the alignment back until the player looks ready was
      // considered and rejected: a player cued in a paused room never
      // leaves `cued` on its own, so a deferred alignment would never
      // be applied at all. The periodic loop is the retry mechanism.
      expect(controller.calls, ['seekTo:0:03:40.000000', 'play']);
    });

    testWidgets('applies the playback intent when the sample read fails: a '
        'failed read costs the seek, never the play', (tester) async {
      bloc.expectedPosition = const Duration(seconds: 220);
      controller.sampleError = StateError('controller detached');

      await mount(
        tester,
        initialState: const VideoSyncState.loading(),
        states: const [
          VideoSyncState.ready(
            position: Duration(seconds: 220),
            isPlaying: true,
          ),
        ],
      );

      expect(controller.calls, ['play']);
    });

    testWidgets('does not let a sample read failing on the listener path '
        'escape as an unobserved asynchronous error', (tester) async {
      bloc.expectedPosition = const Duration(seconds: 220);
      controller.sampleError = StateError('controller detached');

      final state = await mount(
        tester,
        initialState: const VideoSyncState.loading(),
      );

      await expectLater(
        state.applyState(
          const VideoSyncState.ready(
            position: Duration(seconds: 220),
            isPlaying: true,
          ),
        ),
        completes,
      );
    });

    testWidgets('applies no alignment while an advertisement is in progress '
        'or the ready gate is open', (tester) async {
      bloc.expectedPosition = const Duration(seconds: 220);
      controller.sample = const PlayerSample(
        position: Duration.zero,
        state: PlayerAdapterState.playing,
      );

      await mount(
        tester,
        initialState: const VideoSyncState.loading(),
        states: const [
          VideoSyncState.adInProgress(),
          VideoSyncState.barrierWaiting(readyCount: 1, totalCount: 3),
        ],
      );

      expect(controller.calls, isEmpty);
    });
  });

  /// Regression tests for F-V07-T3.
  ///
  /// `tick()` is `async` and was invoked from
  /// `Timer.periodic(interval, (_) => tick())`, discarding the returned
  /// future. Any exception raised inside — including from the
  /// controller's own sample read, whose getter name the factory's doc
  /// comment records as unverified against the pinned package version —
  /// became an unobserved asynchronous error: reconciliation stopped
  /// with no error state, no banner and no log, which is the most
  /// plausible explanation for drift correction never being observed at
  /// all during acceptance testing. A read slower than the sampling
  /// cadence could additionally start a second tick over the first.
  ///
  /// `expectedPosition` is set for the whole group and the observed
  /// position deliberately left far from it, so that any tick reaching
  /// its reconciliation step issues a visible `seekTo`. Without that,
  /// an assertion of "no call was made" would hold just as well against
  /// an implementation having neither timeout nor in-flight guard.
  ///
  /// @competency Unit/widget test harness, TDD cycle.
  /// @competency Test scenario VS-SYN-13.
  group('PlayerReconciliation — sampling loop robustness (F-V07-T3)', () {
    const fastInterval = Duration(milliseconds: 20);

    setUp(() {
      bloc.expectedPosition = const Duration(seconds: 500);
      controller.sample = const PlayerSample(
        position: Duration(seconds: 10),
        state: PlayerAdapterState.playing,
      );
    });

    Future<PlayerReconciliationState> mountLoop(
      WidgetTester tester, {
      ValueChanged<bool>? onReconciliationDegraded,
    }) {
      return mount(
        tester,
        initialState: const VideoSyncState.playing(
          position: Duration(seconds: 10),
        ),
        samplingInterval: fastInterval,
        onReconciliationDegraded: onReconciliationDegraded,
      );
    }

    testWidgets('does not let a failing sample read escape as an unobserved '
        'asynchronous error', (tester) async {
      final state = await mountLoop(tester);
      controller.sampleError = StateError('controller detached');

      await expectLater(state.tick(), completes);
    });

    testWidgets('keeps sampling after a failure: one bad read must not stop '
        'the loop (VS-SYN-13)', (tester) async {
      final state = await mountLoop(tester);

      controller.sampleError = StateError('controller detached');
      await state.tick();

      // The failure discarded the baseline, so this tick only rebuilds
      // it. The next one must observe genuine progression: a position
      // frozen across two samples of a playing player is the exact
      // signature `SyncEngine.detectAd` reads as an advertisement, and
      // would suppress the reconciliation this test is asserting.
      controller.sampleError = null;
      await state.tick();

      controller.sample = const PlayerSample(
        position: Duration(seconds: 11),
        state: PlayerAdapterState.playing,
      );
      await state.tick();

      expect(controller.sampleReads, 3);
      expect(controller.calls, contains('seekTo:0:08:20.000000'));
    });

    testWidgets('reports degradation once its consecutive failure count '
        'reaches the configured threshold (VS-SYN-13)', (tester) async {
      final reported = <bool>[];
      final state = await mountLoop(
        tester,
        onReconciliationDegraded: reported.add,
      );
      controller.sampleError = StateError('controller detached');

      for (var i = 0; i < VideoSyncConfig.sampleFailureThreshold; i++) {
        await state.tick();
      }

      expect(reported, [true]);
    });

    testWidgets('does not report degradation below the threshold', (
      tester,
    ) async {
      final reported = <bool>[];
      final state = await mountLoop(
        tester,
        onReconciliationDegraded: reported.add,
      );
      controller.sampleError = StateError('controller detached');

      for (var i = 0; i < VideoSyncConfig.sampleFailureThreshold - 1; i++) {
        await state.tick();
      }

      expect(reported, isEmpty);
    });

    testWidgets('reports degradation once only, however long it persists: an '
        'indicator raised every interval is its own kind of noise', (
      tester,
    ) async {
      final reported = <bool>[];
      final state = await mountLoop(
        tester,
        onReconciliationDegraded: reported.add,
      );
      controller.sampleError = StateError('controller detached');

      for (var i = 0; i < VideoSyncConfig.sampleFailureThreshold + 3; i++) {
        await state.tick();
      }

      expect(reported, [true]);
    });

    testWidgets('reports recovery on the first successful read after a '
        'degraded loop: an indicator that never clears is a false one', (
      tester,
    ) async {
      final reported = <bool>[];
      final state = await mountLoop(
        tester,
        onReconciliationDegraded: reported.add,
      );

      controller.sampleError = StateError('controller detached');
      for (var i = 0; i < VideoSyncConfig.sampleFailureThreshold; i++) {
        await state.tick();
      }

      controller.sampleError = null;
      await state.tick();

      expect(reported, [true, false]);
    });

    testWidgets('does not report recovery for a loop that was never degraded', (
      tester,
    ) async {
      final reported = <bool>[];
      final state = await mountLoop(
        tester,
        onReconciliationDegraded: reported.add,
      );

      controller.sampleError = StateError('controller detached');
      for (var i = 0; i < VideoSyncConfig.sampleFailureThreshold - 1; i++) {
        await state.tick();
      }

      controller.sampleError = null;
      await state.tick();

      expect(reported, isEmpty);
    });

    testWidgets('resets the consecutive failure count on a successful read, '
        'so an isolated failure never accumulates towards the threshold', (
      tester,
    ) async {
      final reported = <bool>[];
      final state = await mountLoop(
        tester,
        onReconciliationDegraded: reported.add,
      );

      controller.sampleError = StateError('controller detached');
      for (var i = 0; i < VideoSyncConfig.sampleFailureThreshold - 1; i++) {
        await state.tick();
      }

      controller.sampleError = null;
      await state.tick();

      controller.sampleError = StateError('controller detached');
      await state.tick();

      expect(reported, isEmpty);
    });

    testWidgets('abandons a sample read that outlives the sampling interval', (
      tester,
    ) async {
      final state = await mountLoop(tester);
      controller.sampleGate = Completer<PlayerSample>();

      await tester.runAsync(() => state.tick());

      expect(controller.calls, isEmpty);
    });

    testWidgets('skips a tick while another is still in flight, performing no '
        'second read', (tester) async {
      final state = await mountLoop(tester);
      final gate = Completer<PlayerSample>();
      controller.sampleGate = gate;

      final first = state.tick();
      await state.tick();

      expect(controller.sampleReads, 1);

      controller.sampleGate = null;
      gate.complete(
        const PlayerSample(
          position: Duration(seconds: 10),
          state: PlayerAdapterState.playing,
        ),
      );
      await tester.runAsync(() => first);
    });

    testWidgets('discards the ad-detection baseline after a gap in the '
        'sequence, so the next sample is treated as a fresh baseline', (
      tester,
    ) async {
      final state = await mountLoop(tester);

      controller.sample = const PlayerSample(
        position: Duration(seconds: 10),
        state: PlayerAdapterState.playing,
      );
      await state.tick();

      controller.sampleError = StateError('controller detached');
      await state.tick();

      controller.sampleError = null;
      controller.sample = const PlayerSample(
        position: Duration(seconds: 10),
        state: PlayerAdapterState.playing,
      );
      await state.tick();

      verifyNever(() => bloc.add(const VideoSyncEvent.adDetected()));
    });
  });
}
