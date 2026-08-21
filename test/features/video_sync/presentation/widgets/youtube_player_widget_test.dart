import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:youtogether/features/video_sync/presentation/widgets/youtube_player_controller_adapter.dart';
import 'package:youtogether/features/video_sync/presentation/widgets/youtube_player_widget.dart';

class FakeYoutubePlayerControllerAdapter
    implements YoutubePlayerControllerAdapter {
  FakeYoutubePlayerControllerAdapter({
    required this.videoId,
    required this.showNativeControls,
  });

  final bool showNativeControls;

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
/// @competency Unit test harness.
void main() {
  group('YouTubePlayerWidget — native controls gating', () {
    testWidgets('should request native controls when isLeader is true', (
      tester,
    ) async {
      bool? capturedShowNativeControls;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: YouTubePlayerWidget(
            videoId: 'dQw4w9WgXcQ',
            isLeader: true,
            controllerFactory:
                ({required videoId, required showNativeControls}) {
                  capturedShowNativeControls = showNativeControls;
                  return FakeYoutubePlayerControllerAdapter(
                    videoId: videoId,
                    showNativeControls: showNativeControls,
                  );
                },
          ),
        ),
      );

      expect(capturedShowNativeControls, isTrue);
      expect(find.byKey(const Key('fakePlayerView')), findsOneWidget);
    });

    testWidgets(
      'should request native controls hidden when isLeader is false',
      (tester) async {
        bool? capturedShowNativeControls;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: YouTubePlayerWidget(
              videoId: 'dQw4w9WgXcQ',
              isLeader: false,
              controllerFactory:
                  ({required videoId, required showNativeControls}) {
                    capturedShowNativeControls = showNativeControls;
                    return FakeYoutubePlayerControllerAdapter(
                      videoId: videoId,
                      showNativeControls: showNativeControls,
                    );
                  },
            ),
          ),
        );

        expect(capturedShowNativeControls, isFalse);
      },
    );
  });

  group('YouTubePlayerWidget — callback wiring', () {
    late FakeYoutubePlayerControllerAdapter capturedController;

    Future<void> pump(
      WidgetTester tester, {
      VoidCallback? onReady,
      ValueChanged<PlayerAdapterState>? onStateChange,
      ValueChanged<String>? onError,
    }) {
      return tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: YouTubePlayerWidget(
            videoId: 'dQw4w9WgXcQ',
            isLeader: true,
            onReady: onReady,
            onStateChange: onStateChange,
            onError: onError,
            controllerFactory:
                ({required videoId, required showNativeControls}) {
                  capturedController = FakeYoutubePlayerControllerAdapter(
                    videoId: videoId,
                    showNativeControls: showNativeControls,
                  );
                  return capturedController;
                },
          ),
        ),
      );
    }

    testWidgets(
      'should invoke widget.onReady when the controller fires its ready callback',
      (tester) async {
        var readyCalled = false;
        await pump(tester, onReady: () => readyCalled = true);

        capturedController.fireReady();

        expect(readyCalled, isTrue);
      },
    );

    testWidgets(
      'should invoke widget.onStateChange with the mapped PlayerAdapterState',
      (tester) async {
        PlayerAdapterState? received;
        await pump(tester, onStateChange: (state) => received = state);

        capturedController.fireStateChange(PlayerAdapterState.playing);

        expect(received, PlayerAdapterState.playing);
      },
    );

    testWidgets('should invoke widget.onError with the reported message', (
      tester,
    ) async {
      String? received;
      await pump(tester, onError: (message) => received = message);

      capturedController.fireError('Video unavailable');

      expect(received, 'Video unavailable');
    });

    testWidgets('should dispose the controller when the widget is disposed', (
      tester,
    ) async {
      await pump(tester);

      await tester.pumpWidget(const SizedBox());

      expect(capturedController.disposed, isTrue);
    });
  });
}
