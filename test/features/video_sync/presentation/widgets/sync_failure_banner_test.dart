import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_bloc.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_event.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_state.dart';
import 'package:youtogether/features/video_sync/presentation/widgets/sync_failure_banner.dart';

class MockVideoSyncBloc extends MockBloc<VideoSyncEvent, VideoSyncState>
    implements VideoSyncBloc {}

/// Widget tests for [SyncFailureBanner].
///
/// @competency Unit/widget test harness.
/// @competency Test scenario VS-SYN-06.
void main() {
  late MockVideoSyncBloc bloc;

  setUpAll(() {
    registerFallbackValue(const VideoSyncEvent.retryRequested());
  });

  setUp(() {
    bloc = MockVideoSyncBloc();
  });

  Widget wrap(VideoSyncState state) {
    whenListen(bloc, const Stream<VideoSyncState>.empty(), initialState: state);

    return MaterialApp(
      home: BlocProvider<VideoSyncBloc>.value(
        value: bloc,
        child: const SyncFailureBanner(),
      ),
    );
  }

  testWidgets('renders nothing when the bloc is not in a failure state', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const VideoSyncState.playing(position: Duration.zero)),
    );

    expect(find.byKey(const Key('syncFailureBanner')), findsNothing);
  });

  testWidgets(
    'renders the banner with a retry button on VideoSyncState.failure',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          const VideoSyncState.failure(
            Failure.firebase(message: 'disconnected'),
          ),
        ),
      );

      expect(find.byKey(const Key('syncFailureBanner')), findsOneWidget);
      expect(
        find.byKey(const Key('syncFailureBannerRetryButton')),
        findsOneWidget,
      );
    },
  );

  testWidgets('dispatches retryRequested when the retry button is tapped', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const VideoSyncState.failure(Failure.firebase(message: 'disconnected')),
      ),
    );

    await tester.tap(find.byKey(const Key('syncFailureBannerRetryButton')));

    verify(() => bloc.add(const VideoSyncEvent.retryRequested())).called(1);
  });
}
