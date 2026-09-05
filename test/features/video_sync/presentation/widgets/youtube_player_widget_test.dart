import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtogether/features/video_sync/presentation/widgets/youtube_player_controller_adapter.dart';
import 'package:youtogether/features/video_sync/presentation/widgets/youtube_player_widget.dart';

class FakeYoutubePlayerControllerAdapter
    implements YoutubePlayerControllerAdapter {
  FakeYoutubePlayerControllerAdapter({required this.videoId});

  @override
  final String videoId;

  @override
  VoidCallback? onReady;

  @override
  ValueChanged<PlayerAdapterState>? onStateChange;

  @override
  ValueChanged<String>? onError;

  bool disposed = false;
  final List<String> calls = [];

  @override
  Widget buildView() => const SizedBox(key: Key('fakePlayerView'));

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> seekTo(Duration position) async => calls.add('seekTo:$position');

  /// Test-controllable value returned by [getCurrentSample].
  PlayerSample sample = const PlayerSample(
    position: Duration.zero,
    state: PlayerAdapterState.unstarted,
  );

  @override
  Future<PlayerSample> getCurrentSample() async => sample;

  @override
  void dispose() => disposed = true;

  /// Test helper simulating the underlying SDK firing its ready
  /// callback.
  void fireReady() => onReady?.call();

  /// Test helper simulating a playback-state change reported by the SDK.
  void fireStateChange(PlayerAdapterState state) => onStateChange?.call(state);

  /// Test helper simulating an SDK-reported error.
  void fireError(String message) => onError?.call(message);
}

/// Unit and widget tests for [YouTubePlayerWidget].
///
/// Since F-V09-T1 applied ADR-002, this widget carries no notion of
/// role: the embedded player is constructed identically for every
/// participant and answers no native input. The assertion that used to
/// live here — that the leader and a viewer get the same player — is no
/// longer expressible at this level, because there is no longer a
/// parameter to vary. It is carried directly by
/// `youtube_player_controller_factory_test.dart`, against
/// `buildYoutubePlayerParams` itself.
///
/// What remains this widget's own responsibility, and what these tests
/// cover, is the wiring: it constructs exactly one controller from the
/// video id it was given, hands that same instance to its caller, keeps
/// the SDK callbacks connected, and releases the controller when it
/// leaves the tree.
///
/// @competency Unit/widget test harness.
void main() {
  late FakeYoutubePlayerControllerAdapter fake;
  late List<String> requestedVideoIds;

  setUp(() {
    requestedVideoIds = [];
  });

  YoutubePlayerControllerAdapter factory({required String videoId}) {
    requestedVideoIds.add(videoId);
    return fake = FakeYoutubePlayerControllerAdapter(videoId: videoId);
  }

  Widget subject({
    String videoId = 'dQw4w9WgXcQ',
    VoidCallback? onReady,
    ValueChanged<PlayerAdapterState>? onStateChange,
    ValueChanged<String>? onError,
    ValueChanged<YoutubePlayerControllerAdapter>? onControllerReady,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: YouTubePlayerWidget(
        videoId: videoId,
        onReady: onReady,
        onStateChange: onStateChange,
        onError: onError,
        onControllerReady: onControllerReady,
        controllerFactory: factory,
      ),
    );
  }

  group('YouTubePlayerWidget — controller construction', () {
    testWidgets('builds a single controller from the given video id and '
        'renders its view', (tester) async {
      await tester.pumpWidget(subject());

      expect(requestedVideoIds, ['dQw4w9WgXcQ']);
      expect(find.byKey(const Key('fakePlayerView')), findsOneWidget);
    });

    testWidgets('hands the controller it built to onControllerReady, so '
        'PlayerReconciliation drives the same instance rather than a '
        'second, disconnected one', (tester) async {
      YoutubePlayerControllerAdapter? published;

      await tester.pumpWidget(subject(onControllerReady: (c) => published = c));

      expect(published, same(fake));
    });

    testWidgets('disposes the controller when it leaves the tree', (
      tester,
    ) async {
      await tester.pumpWidget(subject());
      expect(fake.disposed, isFalse);

      await tester.pumpWidget(const SizedBox());

      expect(fake.disposed, isTrue);
    });
  });

  group('YouTubePlayerWidget — SDK callback forwarding', () {
    testWidgets('forwards the ready callback', (tester) async {
      var readyCount = 0;
      await tester.pumpWidget(subject(onReady: () => readyCount++));

      fake.fireReady();

      expect(readyCount, 1);
    });

    testWidgets('forwards playback state changes', (tester) async {
      final observed = <PlayerAdapterState>[];
      await tester.pumpWidget(subject(onStateChange: observed.add));

      fake.fireStateChange(PlayerAdapterState.buffering);
      fake.fireStateChange(PlayerAdapterState.playing);

      expect(observed, [
        PlayerAdapterState.buffering,
        PlayerAdapterState.playing,
      ]);
    });

    testWidgets('forwards player errors', (tester) async {
      final observed = <String>[];
      await tester.pumpWidget(subject(onError: observed.add));

      fake.fireError('embedding disabled');

      expect(observed, ['embedding disabled']);
    });
  });
}
