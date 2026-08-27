import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_bloc.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_event.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_state.dart';
import 'package:youtogether/features/video_sync/presentation/widgets/leader_controls.dart';
import 'package:youtogether/features/video_sync/presentation/widgets/player_reconciliation.dart';
import 'package:youtogether/features/video_sync/presentation/widgets/room_video_section.dart';
import 'package:youtogether/features/video_sync/presentation/widgets/sync_status_banner.dart';
import 'package:youtogether/features/video_sync/presentation/widgets/youtube_player_controller_adapter.dart';

class MockVideoSyncBloc extends MockBloc<VideoSyncEvent, VideoSyncState>
    implements VideoSyncBloc {
  MockVideoSyncBloc({
    this.leader = false,
    this.videoId = 'dQw4w9WgXcQ',
    this.duration = 213,
  });

  final bool leader;
  final String videoId;
  final int duration;

  @override
  bool get isLeader => leader;

  @override
  String get youtubeVideoId => videoId;

  @override
  int get durationSeconds => duration;
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

  @override
  Widget buildView() => const SizedBox(key: Key('fakePlayerView'));

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  Future<PlayerSample> getCurrentSample() async => const PlayerSample(
    position: Duration.zero,
    state: PlayerAdapterState.playing,
  );

  @override
  void dispose() {}
}

/// Widget tests for [RoomVideoSection] — the composition wired into
/// `RoomDetailView`.
///
/// A fake controller is injected via `controllerFactory` so the real
/// composition (player + reconciliation + controls) can be mounted
/// without a platform WebView.
///
/// @competency Unit/widget test harness.
void main() {
  Widget wrap(MockVideoSyncBloc bloc, VideoSyncState state) {
    whenListen(bloc, const Stream<VideoSyncState>.empty(), initialState: state);

    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<VideoSyncBloc>.value(
          value: bloc,
          child: RoomVideoSection(
            controllerFactory:
                ({required videoId, required showNativeControls}) =>
                    FakeController(videoId: videoId),
          ),
        ),
      ),
    );
  }

  testWidgets('shows a loading indicator before the session resolves', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(MockVideoSyncBloc(), const VideoSyncState.loading()),
    );

    expect(
      find.byKey(const Key('roomVideoSectionLoadingIndicator')),
      findsOneWidget,
    );
    expect(find.byType(LeaderControls), findsNothing);
  });

  testWidgets('shows only the status banner when no video id is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        MockVideoSyncBloc(videoId: ''),
        const VideoSyncState.failure(Failure.notFound()),
      ),
    );

    expect(find.byType(SyncStatusBanner), findsOneWidget);
    expect(find.byKey(const Key('roomVideoSectionPlayer')), findsNothing);
    expect(find.byType(LeaderControls), findsNothing);
  });

  testWidgets(
    'renders banner, player, and leader controls once a session is loaded',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          MockVideoSyncBloc(leader: true),
          const VideoSyncState.ready(position: Duration.zero, isPlaying: false),
        ),
      );

      expect(find.byType(SyncStatusBanner), findsOneWidget);
      expect(find.byKey(const Key('roomVideoSectionPlayer')), findsOneWidget);
      expect(find.byType(LeaderControls), findsOneWidget);
    },
  );

  testWidgets(
    'mounts PlayerReconciliation only after the controller arrives via the '
    'post-frame callback',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          MockVideoSyncBloc(leader: true),
          const VideoSyncState.ready(position: Duration.zero, isPlaying: false),
        ),
      );

      // First frame: controller handover is still pending.
      expect(find.byType(PlayerReconciliation), findsNothing);

      // Let the post-frame callback run and rebuild.
      await tester.pump();

      expect(find.byType(PlayerReconciliation), findsOneWidget);
      // LeaderControls is still present exactly once — now wrapped
      // rather than standalone.
      expect(find.byType(LeaderControls), findsOneWidget);
    },
  );

  testWidgets('passes the leader flag down to LeaderControls', (tester) async {
    await tester.pumpWidget(
      wrap(
        MockVideoSyncBloc(leader: false),
        const VideoSyncState.ready(position: Duration.zero, isPlaying: false),
      ),
    );

    final controls = tester.widget<LeaderControls>(find.byType(LeaderControls));
    expect(controls.isLeader, isFalse);
    expect(controls.durationSeconds, 213);
  });
}
