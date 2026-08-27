import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/l10n/generated/app_localizations.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_bloc.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_event.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_state.dart';
import 'package:youtogether/features/video_sync/presentation/widgets/sync_status_banner.dart';

class MockVideoSyncBloc extends MockBloc<VideoSyncEvent, VideoSyncState>
    implements VideoSyncBloc {
  MockVideoSyncBloc({this.leader = false});

  final bool leader;

  @override
  bool get isLeader => leader;
}

/// Widget tests for [SyncStatusBanner] — the consolidation of the former
/// `SyncFailureBanner` with the ready-gate indicator.
///
/// @competency Unit/widget test harness.
/// @competency Test scenarios failure + retry,
///   ready-gate progress and force start.
void main() {
  setUpAll(() {
    registerFallbackValue(const VideoSyncEvent.retryRequested());
  });

  Widget wrap(MockVideoSyncBloc bloc, VideoSyncState state) {
    whenListen(bloc, const Stream<VideoSyncState>.empty(), initialState: state);

    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider<VideoSyncBloc>.value(
          value: bloc,
          child: const SyncStatusBanner(),
        ),
      ),
    );
  }

  group('Idle states', () {
    testWidgets('renders nothing while playing', (tester) async {
      await tester.pumpWidget(
        wrap(
          MockVideoSyncBloc(),
          const VideoSyncState.playing(position: Duration.zero),
        ),
      );

      expect(find.byKey(const Key('syncStatusBanner')), findsNothing);
    });

    testWidgets('renders nothing while paused', (tester) async {
      await tester.pumpWidget(
        wrap(
          MockVideoSyncBloc(),
          const VideoSyncState.paused(position: Duration.zero),
        ),
      );

      expect(find.byKey(const Key('syncStatusBanner')), findsNothing);
    });
  });

  group('Failure state (VS-SYN-06)', () {
    testWidgets('renders the banner with a retry button', (tester) async {
      await tester.pumpWidget(
        wrap(
          MockVideoSyncBloc(),
          const VideoSyncState.failure(
            Failure.firebase(message: 'disconnected'),
          ),
        ),
      );

      expect(find.byKey(const Key('syncStatusBanner')), findsOneWidget);
      expect(
        find.byKey(const Key('syncStatusBannerRetryButton')),
        findsOneWidget,
      );
    });

    testWidgets('dispatches retryRequested when retry is tapped', (
      tester,
    ) async {
      final bloc = MockVideoSyncBloc();
      await tester.pumpWidget(
        wrap(
          bloc,
          const VideoSyncState.failure(Failure.firebase(message: 'x')),
        ),
      );

      await tester.tap(find.byKey(const Key('syncStatusBannerRetryButton')));

      verify(() => bloc.add(const VideoSyncEvent.retryRequested())).called(1);
    });

    testWidgets(
      'shows no force-start button in the failure state, even for a leader',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            MockVideoSyncBloc(leader: true),
            const VideoSyncState.failure(Failure.firebase(message: 'x')),
          ),
        );

        expect(
          find.byKey(const Key('syncStatusBannerForceStartButton')),
          findsNothing,
        );
      },
    );
  });

  group('Ready-gate state (Section 4.2)', () {
    testWidgets('shows the readiness progress as "n/m ready"', (tester) async {
      await tester.pumpWidget(
        wrap(
          MockVideoSyncBloc(),
          const VideoSyncState.barrierWaiting(readyCount: 3, totalCount: 5),
        ),
      );

      expect(find.byKey(const Key('syncStatusBanner')), findsOneWidget);
      expect(find.textContaining('3/5'), findsOneWidget);
    });

    testWidgets('shows a force-start button for the leader', (tester) async {
      await tester.pumpWidget(
        wrap(
          MockVideoSyncBloc(leader: true),
          const VideoSyncState.barrierWaiting(readyCount: 3, totalCount: 5),
        ),
      );

      expect(
        find.byKey(const Key('syncStatusBannerForceStartButton')),
        findsOneWidget,
      );
    });

    testWidgets('hides the force-start button for a non-leader viewer', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          MockVideoSyncBloc(leader: false),
          const VideoSyncState.barrierWaiting(readyCount: 3, totalCount: 5),
        ),
      );

      expect(
        find.byKey(const Key('syncStatusBannerForceStartButton')),
        findsNothing,
      );
    });

    testWidgets(
      'dispatches forceStartRequested when the leader taps force start',
      (tester) async {
        final bloc = MockVideoSyncBloc(leader: true);
        await tester.pumpWidget(
          wrap(
            bloc,
            const VideoSyncState.barrierWaiting(readyCount: 3, totalCount: 5),
          ),
        );

        await tester.tap(
          find.byKey(const Key('syncStatusBannerForceStartButton')),
        );

        verify(
          () => bloc.add(const VideoSyncEvent.forceStartRequested()),
        ).called(1);
      },
    );

    testWidgets('shows no retry button in the ready-gate state', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          MockVideoSyncBloc(leader: true),
          const VideoSyncState.barrierWaiting(readyCount: 3, totalCount: 5),
        ),
      );

      expect(
        find.byKey(const Key('syncStatusBannerRetryButton')),
        findsNothing,
      );
    });
  });

  group('Advertisement state', () {
    testWidgets(
      'shows an informational banner with neither retry nor force start',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            MockVideoSyncBloc(leader: true),
            const VideoSyncState.adInProgress(),
          ),
        );

        expect(find.byKey(const Key('syncStatusBanner')), findsOneWidget);
        expect(
          find.byKey(const Key('syncStatusBannerRetryButton')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('syncStatusBannerForceStartButton')),
          findsNothing,
        );
      },
    );
  });
}
