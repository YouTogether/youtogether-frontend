import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/video_sync/presentation/cubit/add_video_cubit.dart';
import 'package:youtogether/features/video_sync/presentation/cubit/add_video_state.dart';
import 'package:youtogether/features/video_sync/presentation/widgets/add_video_form.dart';
import 'package:youtogether/l10n/generated/app_localizations.dart';
import 'package:youtogether/features/video_sync/domain/entities/presence_entity.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_bloc.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_event.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_state.dart';
import 'package:youtogether/features/video_sync/presentation/widgets/leader_controls.dart';
import 'package:youtogether/features/video_sync/presentation/widgets/player_reconciliation.dart';
import 'package:youtogether/features/video_sync/presentation/widgets/room_video_section.dart';
import 'package:youtogether/features/video_sync/presentation/cubit/presence_cubit.dart';
import 'package:youtogether/features/video_sync/presentation/cubit/presence_state.dart';
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

  @override
  String get roomId => '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';
}

class MockPresenceCubit extends MockCubit<PresenceState>
    implements PresenceCubit {}

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

class MockAddVideoCubit extends MockCubit<AddVideoState>
    implements AddVideoCubit {}

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

    final presenceCubit = MockPresenceCubit();
    whenListen(
      presenceCubit,
      const Stream<PresenceState>.empty(),
      initialState: const PresenceState.loaded(<PresenceEntity>[]),
    );

    final addVideoCubit = MockAddVideoCubit();
    whenListen(
      addVideoCubit,
      const Stream<AddVideoState>.empty(),
      initialState: const AddVideoState.initial(),
    );

    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<VideoSyncBloc>.value(value: bloc),
            BlocProvider<PresenceCubit>.value(value: presenceCubit),
            BlocProvider<AddVideoCubit>.value(value: addVideoCubit),
          ],
          child: SingleChildScrollView(
            child: RoomVideoSection(
              controllerFactory:
                  ({required videoId, required showNativeControls}) =>
                      FakeController(videoId: videoId),
            ),
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
    expect(find.byType(AddVideoForm), findsNothing);
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

  group('RoomVideoSection — empty state (F-V06-T3)', () {
    testWidgets('offers the add-video form to the leader when the room has '
        'no session yet (VS-ADD-01)', (tester) async {
      await tester.pumpWidget(
        wrap(
          MockVideoSyncBloc(leader: true, videoId: ''),
          const VideoSyncState.failure(Failure.notFound()),
        ),
      );

      expect(find.byType(AddVideoForm), findsOneWidget);
      expect(find.byKey(const Key('roomVideoSectionPlayer')), findsNothing);
    });

    testWidgets('does not offer the form to a non-leader (VS-ADD-03)', (
      tester,
    ) async {
      // Hiding the form is defence in depth, not the enforcement point:
      // OwnershipGuard rejects the request server-side regardless. This
      // asserts the client does not invite an action it knows will fail.
      await tester.pumpWidget(
        wrap(
          MockVideoSyncBloc(videoId: ''),
          const VideoSyncState.failure(Failure.notFound()),
        ),
      );

      expect(find.byType(AddVideoForm), findsNothing);
      expect(find.byType(SyncStatusBanner), findsOneWidget);
    });

    testWidgets('does not offer the form once a session is loaded', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          MockVideoSyncBloc(leader: true),
          const VideoSyncState.ready(position: Duration.zero, isPlaying: false),
        ),
      );

      expect(find.byType(AddVideoForm), findsNothing);
      expect(find.byKey(const Key('roomVideoSectionPlayer')), findsOneWidget);
    });

    testWidgets('shows the loading indicator, not the form, while the join '
        'sequence runs', (tester) async {
      // The leader submits, sessionJoined is dispatched, and the bloc
      // returns to `loading`. Rendering the form again at that point
      // would invite a second submission for a session already being
      // created.
      await tester.pumpWidget(
        wrap(
          MockVideoSyncBloc(leader: true, videoId: ''),
          const VideoSyncState.loading(),
        ),
      );

      expect(find.byType(AddVideoForm), findsNothing);
      expect(
        find.byKey(const Key('roomVideoSectionLoadingIndicator')),
        findsOneWidget,
      );
    });
  });
}
