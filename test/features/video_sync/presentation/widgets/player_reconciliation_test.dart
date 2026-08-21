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

  group('BlocListener — play/pause execution', () {
    testWidgets(
      'calls controller.play() when the bloc transitions to playing',
      (tester) async {
        whenListen(
          bloc,
          Stream.fromIterable([
            const VideoSyncState.playing(position: Duration.zero),
          ]),
          initialState: const VideoSyncState.paused(position: Duration.zero),
        );

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

        expect(controller.calls, contains('play'));
      },
    );

    testWidgets(
      'calls controller.pause() when the bloc transitions to paused',
      (tester) async {
        whenListen(
          bloc,
          Stream.fromIterable([
            const VideoSyncState.paused(position: Duration.zero),
          ]),
          initialState: const VideoSyncState.playing(position: Duration.zero),
        );

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

        expect(controller.calls, contains('pause'));
      },
    );
  });

  group('Reconciliation tick — drift and ad detection', () {
    testWidgets('T12: no seekTo when drift is below threshold', (tester) async {
      bloc.lastKnownSession = VideoSessionEntity(
        roomId: 'room',
        youtubeVideoId: 'dQw4w9WgXcQ',
        isPlaying: true,
        currentPosition: const Duration(seconds: 100),
        leaderId: 'leader',
        updatedAt: DateTime.now().toUtc(),
      );
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
        final updatedAt = DateTime.now().toUtc().subtract(
          const Duration(seconds: 15),
        );
        bloc.lastKnownSession = VideoSessionEntity(
          roomId: 'room',
          youtubeVideoId: 'dQw4w9WgXcQ',
          isPlaying: true,
          currentPosition: const Duration(seconds: 120),
          leaderId: 'leader',
          updatedAt: updatedAt,
        );

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
        expect(controller.calls.any((c) => c.startsWith('seekTo')), isTrue);
      },
    );

    testWidgets(
      'never calls play() or pause() from the reconciliation tick itself',
      (tester) async {
        bloc.lastKnownSession = VideoSessionEntity(
          roomId: 'room',
          youtubeVideoId: 'dQw4w9WgXcQ',
          isPlaying: true,
          currentPosition: const Duration(seconds: 200),
          leaderId: 'leader',
          updatedAt: DateTime.now().toUtc(),
        );
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
}
