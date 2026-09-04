import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/features/video_sync/domain/entities/video_session_entity.dart';
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
  /// `null` and the widget will — correctly — issue no seek at all.
  /// Every test that expects a seek must set this one.
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

  @override
  Widget buildView() => const SizedBox();

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> seekTo(Duration position) async => calls.add('seekTo:$position');

  @override
  Future<PlayerSample> getCurrentSample() async => sample;

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

  Future<PlayerReconciliationState> pump(
    WidgetTester tester,
    VideoSyncState initialState,
  ) async {
    whenListen(
      bloc,
      const Stream<VideoSyncState>.empty(),
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
            child: const SizedBox(),
          ),
        ),
      ),
    );

    return key.currentState!;
  }

  Future<void> pumpWithStates(
    WidgetTester tester, {
    required VideoSyncState initialState,
    required List<VideoSyncState> states,
  }) async {
    whenListen(bloc, Stream.fromIterable(states), initialState: initialState);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<VideoSyncBloc>.value(
          value: bloc,
          child: PlayerReconciliation(
            controller: controller,
            child: const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('BlocListener — play/pause execution', () {
    testWidgets(
      'calls controller.play() when the bloc transitions to playing, even '
      'with no expected position known',
      (tester) async {
        await pumpWithStates(
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
        await pumpWithStates(
          tester,
          initialState: const VideoSyncState.playing(position: Duration.zero),
          states: const [VideoSyncState.paused(position: Duration.zero)],
        );

        expect(controller.calls, contains('pause'));
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

      final state = await pump(
        tester,
        const VideoSyncState.playing(position: Duration(seconds: 100)),
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

        final state = await pump(
          tester,
          const VideoSyncState.playing(position: Duration(seconds: 120)),
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

        final state = await pump(
          tester,
          const VideoSyncState.playing(position: Duration(seconds: 200)),
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
    late MockVideoSyncBloc bloc;
    late FakeController controller;

    setUp(() {
      bloc = MockVideoSyncBloc();
      controller = FakeController(videoId: 'dQw4w9WgXcQ');
    });

    Future<void> pumpWithStates(
      WidgetTester tester, {
      required VideoSyncState initialState,
      required List<VideoSyncState> states,
    }) async {
      whenListen(bloc, Stream.fromIterable(states), initialState: initialState);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<VideoSyncBloc>.value(
            value: bloc,
            child: PlayerReconciliation(
              controller: controller,
              child: const SizedBox(),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('seeks to the expected position and starts playback when the '
        'session is joined mid-playback (VS-SYN-07)', (tester) async {
      bloc.expectedPosition = const Duration(seconds: 220);
      controller.sample = const PlayerSample(
        position: Duration.zero,
        state: PlayerAdapterState.paused,
      );

      await pumpWithStates(
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

      await pumpWithStates(
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

      await pumpWithStates(
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

      await pumpWithStates(
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

    testWidgets('aligns a player that has never started, in a paused room: '
        'the seek must not leave playback running (VS-SYN-08)', (tester) async {
      bloc.expectedPosition = const Duration(seconds: 90);
      controller.sample = const PlayerSample(
        position: Duration.zero,
        state: PlayerAdapterState.cued,
      );

      await pumpWithStates(
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

    testWidgets('applies no alignment while an advertisement is in progress '
        'or the ready gate is open', (tester) async {
      bloc.expectedPosition = const Duration(seconds: 220);
      controller.sample = const PlayerSample(
        position: Duration.zero,
        state: PlayerAdapterState.playing,
      );

      await pumpWithStates(
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
}
