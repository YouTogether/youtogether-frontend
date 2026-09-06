import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_bloc.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_event.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_state.dart';
import 'package:youtogether/features/video_sync/presentation/widgets/leader_controls.dart';
import 'package:youtogether/l10n/generated/app_localizations.dart';

/// A real [Cubit] standing in for [VideoSyncBloc].
///
/// This file departs from the `MockBloc` + `whenListen` convention used
/// elsewhere in the suite. The departure is a choice, not a necessity:
/// a `Cubit` provides `state` and `stream` through the same code path
/// the production bloc uses, so the tests below exercise `BlocBuilder`
/// exactly as `RoomDetailView` does, with no stubbing layer in between.
/// Either double would work; this one has less to explain.
///
/// `noSuchMethod` covers every `VideoSyncBloc` member this widget never
/// touches. Any access to one of them fails loudly, which is preferable
/// to a silent default.
class FakeVideoSyncBloc extends Cubit<VideoSyncState> implements VideoSyncBloc {
  FakeVideoSyncBloc(super.initialState);

  /// Every event the widget dispatched, in order.
  final List<VideoSyncEvent> added = [];

  @override
  void add(VideoSyncEvent event) => added.add(event);

  /// Emits [state] as the production bloc would.
  void push(VideoSyncState state) => emit(state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Widget tests for [LeaderControls].
///
/// @competency Unit/widget test harness.
/// @competency Test scenario (presentation-layer slice).
void main() {
  late FakeVideoSyncBloc bloc;

  Widget wrap(
    VideoSyncState state, {
    required bool isLeader,
    int durationSeconds = 213,
  }) {
    bloc = FakeVideoSyncBloc(state);
    addTearDown(bloc.close);

    // Wrapped in a Scaffold, not bare inside MaterialApp.home: this is
    // how LeaderControls is actually used in RoomDetailView (whose
    // Scaffold supplies the Material ancestor Slider/IconButton
    // require), and omitting it here previously let a missing-Material
    // regression in the widget itself go undetected — see
    // LeaderControls' own doc comment on the fix.
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider<VideoSyncBloc>.value(
          value: bloc,
          child: LeaderControls(
            isLeader: isLeader,
            durationSeconds: durationSeconds,
          ),
        ),
      ),
    );
  }

  /// Emits [state] and renders the frame it produces.
  ///
  /// Two pumps, not one. A bloc delivers to its stream listeners on a
  /// microtask, and `pump()` decides whether to build a frame *before*
  /// it flushes microtasks. The first pump therefore only runs the
  /// `BlocBuilder`'s listener — which calls `setState` and schedules a
  /// frame — and the second builds that frame. Asserting after a single
  /// pump reads the widget tree from before the emission. That is not
  /// specific to this double: it holds for `MockBloc` + `whenListen`
  /// just the same, and it is how every post-mount assertion in this
  /// file failed inexplicably, or passed vacuously, through three
  /// revisions before the cause was identified.
  Future<void> pushState(WidgetTester tester, VideoSyncState state) async {
    bloc.push(state);
    await tester.pump();
    await tester.pump();
  }

  Slider sliderOf(WidgetTester tester) =>
      tester.widget<Slider>(find.byKey(const Key('leaderControlsSeekSlider')));

  IconButton buttonOf(WidgetTester tester, String key) =>
      tester.widget<IconButton>(find.byKey(Key(key)));

  group('LeaderControls — leader', () {
    testWidgets('shows an enabled play button when paused', (tester) async {
      await tester.pumpWidget(
        wrap(
          const VideoSyncState.paused(position: Duration.zero),
          isLeader: true,
        ),
      );

      expect(buttonOf(tester, 'leaderControlsPlayButton').onPressed, isNotNull);
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

      expect(bloc.added, [const VideoSyncEvent.playRequested()]);
    });

    testWidgets('shows an enabled pause button when playing, and dispatches '
        'pauseRequested on tap', (tester) async {
      await tester.pumpWidget(
        wrap(
          const VideoSyncState.playing(position: Duration.zero),
          isLeader: true,
        ),
      );

      expect(
        buttonOf(tester, 'leaderControlsPauseButton').onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(const Key('leaderControlsPauseButton')));

      expect(bloc.added, [const VideoSyncEvent.pauseRequested()]);
    });
  });

  /// Tests for F-V09-T2, completing ADR-002.
  ///
  /// With the native control surface neutralised, this bar is the
  /// leader's only way to move through the video, so the seek
  /// interaction has to be correct rather than merely present.
  ///
  /// Three defects are covered. `onChanged` dispatched on every frame
  /// of a drag, turning one gesture into dozens of Firebase writes and
  /// as many `seekTo` calls on every viewer. The thumb was rendered
  /// straight from `state.position`, so it could not follow the finger.
  /// And since F-V08-T1 the leader receives a `playing` state every few
  /// seconds, which would pull the thumb away mid-gesture.
  ///
  /// The slider callbacks are invoked directly rather than driven by a
  /// synthesised drag gesture: a `Slider`'s thumb travel depends on the
  /// laid-out track width, so a gesture-based test would assert the
  /// arithmetic of the layout as much as the behaviour under test, and
  /// would break on any change to the surrounding `Row`.
  ///
  /// @competency Unit/widget test harness, TDD cycle.
  /// @competency Accessibility of the seek control.
  /// @competency Test scenario VS-SYN-09.
  group('LeaderControls — seek interaction (F-V09-T2)', () {
    testWidgets('dispatches nothing while the drag is in progress', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const VideoSyncState.paused(position: Duration(seconds: 10)),
          isLeader: true,
        ),
      );

      final slider = sliderOf(tester);
      slider.onChangeStart!(10.0);
      slider.onChanged!(60.0);
      slider.onChanged!(120.0);
      await tester.pump();

      expect(bloc.added, isEmpty);
    });

    testWidgets('dispatches a single seekRequested when the drag ends '
        '(VS-SYN-09)', (tester) async {
      await tester.pumpWidget(
        wrap(
          const VideoSyncState.paused(position: Duration(seconds: 10)),
          isLeader: true,
        ),
      );

      final slider = sliderOf(tester);
      slider.onChangeStart!(10.0);
      slider.onChanged!(60.0);
      slider.onChangeEnd!(120.0);
      await tester.pump();

      expect(bloc.added, [
        const VideoSyncEvent.seekRequested(Duration(seconds: 120)),
      ]);
    });

    testWidgets('follows the finger during the drag', (tester) async {
      await tester.pumpWidget(
        wrap(
          const VideoSyncState.paused(position: Duration(seconds: 10)),
          isLeader: true,
        ),
      );

      sliderOf(tester).onChangeStart!(10.0);
      sliderOf(tester).onChanged!(60.0);
      await tester.pump();

      expect(sliderOf(tester).value, 60.0);
    });

    testWidgets('keeps the thumb under the finger while a heartbeat state '
        'arrives mid-drag', (tester) async {
      await tester.pumpWidget(
        wrap(
          const VideoSyncState.playing(position: Duration(seconds: 10)),
          isLeader: true,
        ),
      );

      sliderOf(tester).onChangeStart!(10.0);
      sliderOf(tester).onChanged!(150.0);
      await tester.pump();

      await pushState(
        tester,
        const VideoSyncState.playing(position: Duration(seconds: 15)),
      );

      // Delivery guard: the pause button is state-driven only, so its
      // being enabled proves the rebuild happened. Without it, the
      // thumb assertion would hold vacuously against a stale tree.
      expect(
        buttonOf(tester, 'leaderControlsPauseButton').onPressed,
        isNotNull,
      );
      expect(sliderOf(tester).value, 150.0);
    });

    testWidgets('holds the released target until the seek echoes back, then '
        'follows the state again', (tester) async {
      await tester.pumpWidget(
        wrap(
          const VideoSyncState.playing(position: Duration(seconds: 10)),
          isLeader: true,
        ),
      );

      sliderOf(tester).onChangeStart!(10.0);
      sliderOf(tester).onChangeEnd!(150.0);
      await tester.pump();

      expect(sliderOf(tester).value, 150.0);

      // Echo position deliberately differs from the released target so
      // that this assertion distinguishes "held" from "expired".
      await pushState(
        tester,
        const VideoSyncState.playing(position: Duration(seconds: 152)),
      );

      expect(sliderOf(tester).value, 152.0);

      await pushState(
        tester,
        const VideoSyncState.playing(position: Duration(seconds: 155)),
      );

      expect(sliderOf(tester).value, 155.0);
    });

    testWidgets('returns the thumb to the real position when the seek write '
        'fails', (tester) async {
      await tester.pumpWidget(
        wrap(
          const VideoSyncState.playing(position: Duration(seconds: 10)),
          isLeader: true,
        ),
      );

      sliderOf(tester).onChangeStart!(10.0);
      sliderOf(tester).onChangeEnd!(150.0);
      await tester.pump();

      await pushState(
        tester,
        const VideoSyncState.failure(Failure.firebase(message: 'refused')),
      );

      // Delivery guard: play becomes enabled once the state is no
      // longer `playing`. This depends only on `isPlaying`, never on
      // the hold logic under test.
      expect(buttonOf(tester, 'leaderControlsPlayButton').onPressed, isNotNull);
      expect(sliderOf(tester).value, 0.0);
    });
  });

  group('LeaderControls — position readout and bounds (F-V09-T2)', () {
    testWidgets('renders the current position against the total duration', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const VideoSyncState.playing(position: Duration(seconds: 125)),
          isLeader: true,
        ),
      );

      expect(find.text('2:05 / 3:33'), findsOneWidget);
    });

    testWidgets('renders hours only when the video is long enough to need '
        'them', (tester) async {
      await tester.pumpWidget(
        wrap(
          const VideoSyncState.playing(position: Duration(seconds: 3725)),
          isLeader: true,
          durationSeconds: 7200,
        ),
      );

      expect(find.text('1:02:05 / 2:00:00'), findsOneWidget);
    });

    testWidgets('reads out the position being aimed at, not the one being '
        'left behind, during a drag', (tester) async {
      await tester.pumpWidget(
        wrap(
          const VideoSyncState.playing(position: Duration(seconds: 10)),
          isLeader: true,
        ),
      );

      sliderOf(tester).onChangeStart!(10.0);
      sliderOf(tester).onChanged!(125.0);
      await tester.pump();

      expect(find.text('2:05 / 3:33'), findsOneWidget);
    });

    testWidgets('announces the seek position as a time, not as a number', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const VideoSyncState.playing(position: Duration(seconds: 125)),
          isLeader: true,
        ),
      );

      expect(sliderOf(tester).semanticFormatterCallback!(125.0), '2:05');
    });

    testWidgets('disables the slider while the duration is still unknown, '
        'without producing a degenerate range', (tester) async {
      await tester.pumpWidget(
        wrap(
          const VideoSyncState.loading(),
          isLeader: true,
          durationSeconds: 0,
        ),
      );

      final slider = sliderOf(tester);
      expect(slider.onChanged, isNull);
      expect(slider.onChangeStart, isNull);
      expect(slider.onChangeEnd, isNull);
      expect(slider.max, greaterThan(slider.min));
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

      expect(buttonOf(tester, 'leaderControlsPlayButton').onPressed, isNull);
      expect(bloc.added, isEmpty);
    });

    testWidgets('disables the pause button', (tester) async {
      await tester.pumpWidget(
        wrap(
          const VideoSyncState.playing(position: Duration.zero),
          isLeader: false,
        ),
      );

      expect(buttonOf(tester, 'leaderControlsPauseButton').onPressed, isNull);
    });

    testWidgets('disables the seek slider', (tester) async {
      await tester.pumpWidget(
        wrap(
          const VideoSyncState.paused(position: Duration.zero),
          isLeader: false,
        ),
      );

      expect(sliderOf(tester).onChanged, isNull);
    });

    testWidgets('disables the drag callbacks as well: onChangeEnd is what '
        'dispatches, so onChanged alone does not close the role gate', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const VideoSyncState.paused(position: Duration.zero),
          isLeader: false,
        ),
      );

      final slider = sliderOf(tester);
      expect(slider.onChangeStart, isNull);
      expect(slider.onChangeEnd, isNull);
    });
  });
}
