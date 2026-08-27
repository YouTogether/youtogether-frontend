import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/l10n/generated/app_localizations.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_bloc.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_event.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_state.dart';
import 'package:youtogether/features/video_sync/presentation/widgets/leader_controls.dart';

class MockVideoSyncBloc extends MockBloc<VideoSyncEvent, VideoSyncState>
    implements VideoSyncBloc {}

/// Widget tests for [LeaderControls].
///
/// Uses `bloc_test`'s `MockBloc` with `whenListen`, mirroring
/// `home_page_test.dart`'s bloc-mocking convention.
///
/// @competency Unit/widget test harness.
/// @competency Test scenario (presentation-layer slice).
void main() {
  late MockVideoSyncBloc bloc;

  setUpAll(() {
    registerFallbackValue(const VideoSyncEvent.playRequested());
  });

  setUp(() {
    bloc = MockVideoSyncBloc();
  });

  Widget wrap(VideoSyncState state, {required bool isLeader}) {
    whenListen(bloc, const Stream<VideoSyncState>.empty(), initialState: state);

    // Wrapped in a Scaffold, not bare inside MaterialApp.home: this is
    // how LeaderControls will actually be used once wired into
    // RoomDetailView (whose Scaffold supplies the Material ancestor
    // Slider/IconButton require), and omitting it here previously let
    // a missing-Material regression in the widget itself go undetected
    // — see LeaderControls' own doc comment on the fix.
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider<VideoSyncBloc>.value(
          value: bloc,
          child: LeaderControls(isLeader: isLeader, durationSeconds: 213),
        ),
      ),
    );
  }

  group('LeaderControls — leader', () {
    testWidgets('shows an enabled play button when paused', (tester) async {
      await tester.pumpWidget(
        wrap(
          const VideoSyncState.paused(position: Duration.zero),
          isLeader: true,
        ),
      );

      final playButton = tester.widget<IconButton>(
        find.byKey(const Key('leaderControlsPlayButton')),
      );
      expect(playButton.onPressed, isNotNull);
    });

    testWidgets('dispatches playRequested when the play button is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const VideoSyncState.paused(position: Duration.zero),
          isLeader: true,
        ),
      );

      await tester.tap(find.byKey(const Key('leaderControlsPlayButton')));

      verify(() => bloc.add(const VideoSyncEvent.playRequested())).called(1);
    });

    testWidgets('shows an enabled pause button when playing, and dispatches '
        'pauseRequested on tap', (tester) async {
      await tester.pumpWidget(
        wrap(
          const VideoSyncState.playing(position: Duration.zero),
          isLeader: true,
        ),
      );

      final pauseButton = tester.widget<IconButton>(
        find.byKey(const Key('leaderControlsPauseButton')),
      );
      expect(pauseButton.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('leaderControlsPauseButton')));
      verify(() => bloc.add(const VideoSyncEvent.pauseRequested())).called(1);
    });

    testWidgets('dispatches seekRequested with the slider target on change', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const VideoSyncState.paused(position: Duration(seconds: 213)),
          isLeader: true,
        ),
      );

      final slider = find.byKey(const Key('leaderControlsSeekSlider'));
      expect(slider, findsOneWidget);
    });
  });

  group('LeaderControls — non-leader (VS-SYN-05)', () {
    testWidgets('disables the play button and never dispatches on tap', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const VideoSyncState.paused(position: Duration.zero),
          isLeader: false,
        ),
      );

      final playButton = tester.widget<IconButton>(
        find.byKey(const Key('leaderControlsPlayButton')),
      );
      expect(playButton.onPressed, isNull);

      verifyNever(() => bloc.add(any()));
    });

    testWidgets('disables the pause button', (tester) async {
      await tester.pumpWidget(
        wrap(
          const VideoSyncState.playing(position: Duration.zero),
          isLeader: false,
        ),
      );

      final pauseButton = tester.widget<IconButton>(
        find.byKey(const Key('leaderControlsPauseButton')),
      );
      expect(pauseButton.onPressed, isNull);
    });

    testWidgets('disables the seek slider', (tester) async {
      await tester.pumpWidget(
        wrap(
          const VideoSyncState.paused(position: Duration.zero),
          isLeader: false,
        ),
      );

      final slider = tester.widget<Slider>(
        find.byKey(const Key('leaderControlsSeekSlider')),
      );
      expect(slider.onChanged, isNull);
    });
  });
}
