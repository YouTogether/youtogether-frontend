import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/l10n/generated/app_localizations.dart';
import 'package:youtogether/features/video_sync/domain/entities/video_session_metadata_entity.dart';
import 'package:youtogether/features/video_sync/domain/value_objects/youtube_video_id.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_bloc.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_event.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_state.dart';
import 'package:youtogether/features/video_sync/presentation/cubit/add_video_cubit.dart';
import 'package:youtogether/features/video_sync/presentation/cubit/add_video_state.dart';
import 'package:youtogether/features/video_sync/presentation/widgets/add_video_form.dart';

const testRoomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';

class MockVideoSyncBloc extends MockBloc<VideoSyncEvent, VideoSyncState>
    implements VideoSyncBloc {
  @override
  bool get isLeader => true;

  @override
  String get youtubeVideoId => '';

  @override
  int get durationSeconds => 0;

  @override
  String get roomId => testRoomId;
}

class MockAddVideoCubit extends MockCubit<AddVideoState>
    implements AddVideoCubit {}

/// Widget tests for [AddVideoForm].
///
/// Two assertions carry the weight of this suite.
///
/// First, malformed input must never reach the cubit: the value object
/// exists so that no request is issued for something that cannot be a
/// video id, and only a widget test can prove the validator is actually
/// wired to the submit path.
///
/// Second, a successful submission must dispatch
/// `VideoSyncEvent.sessionJoined`. That single dispatch is what turns a
/// created session into a mounted player, and nothing else in the
/// codebase does it — without it the leader would add a video and stare
/// at the same empty state.
///
/// ## On matchers
/// `VideoSyncEvent` is a `@freezed` sealed union, so it cannot be
/// subclassed by a `Fake` and `registerFallbackValue` has nothing to
/// register. Every assertion against `VideoSyncBloc.add` therefore
/// names the concrete event, which is also the stronger claim: "this
/// exact event was dispatched", not "something was".
///
/// [YoutubeVideoId] is a plain value object, so a real instance serves
/// as the fallback for the one `any(named:)` matcher that needs one.
///
/// @competency Unit/widget test harness, TDD cycle.
/// @competency Test scenarios VS-ADD-01, VS-ADD-02, VS-ADD-04.
void main() {
  late MockVideoSyncBloc videoSyncBloc;
  late MockAddVideoCubit addVideoCubit;

  final session = VideoSessionMetadataEntity(
    id: 'session-uuid',
    roomId: testRoomId,
    youtubeVideoId: 'dQw4w9WgXcQ',
    title: 'Never Gonna Give You Up',
    thumbnailUrl: null,
    durationSeconds: 213,
    addedBy: '550e8400-e29b-41d4-a716-446655440000',
    createdAt: DateTime.utc(2026, 1, 5),
  );

  setUpAll(() {
    registerFallbackValue(YoutubeVideoId.parse('dQw4w9WgXcQ'));
  });

  setUp(() {
    videoSyncBloc = MockVideoSyncBloc();
    whenListen(
      videoSyncBloc,
      const Stream<VideoSyncState>.empty(),
      initialState: const VideoSyncState.failure(Failure.notFound()),
    );

    addVideoCubit = MockAddVideoCubit();
    when(
      () => addVideoCubit.submit(
        roomId: any(named: 'roomId'),
        youtubeVideoId: any(named: 'youtubeVideoId'),
      ),
    ).thenAnswer((_) async {});
  });

  Widget buildSubject() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<VideoSyncBloc>.value(value: videoSyncBloc),
            BlocProvider<AddVideoCubit>.value(value: addVideoCubit),
          ],
          child: const AddVideoForm(),
        ),
      ),
    );
  }

  Widget wrap(AddVideoState state) {
    whenListen(
      addVideoCubit,
      const Stream<AddVideoState>.empty(),
      initialState: state,
    );

    return buildSubject();
  }

  testWidgets('renders the field and the submit button', (tester) async {
    await tester.pumpWidget(wrap(const AddVideoState.initial()));

    expect(find.byKey(const Key('addVideoFormField')), findsOneWidget);
    expect(find.byKey(const Key('addVideoFormSubmitButton')), findsOneWidget);
  });

  testWidgets('submits a bare video id (VS-ADD-01)', (tester) async {
    await tester.pumpWidget(wrap(const AddVideoState.initial()));

    await tester.enterText(
      find.byKey(const Key('addVideoFormField')),
      'dQw4w9WgXcQ',
    );
    await tester.tap(find.byKey(const Key('addVideoFormSubmitButton')));
    await tester.pump();

    verify(
      () => addVideoCubit.submit(
        roomId: testRoomId,
        youtubeVideoId: YoutubeVideoId.parse('dQw4w9WgXcQ'),
      ),
    ).called(1);
  });

  testWidgets('extracts the id from a pasted watch URL (VS-ADD-01)', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const AddVideoState.initial()));

    await tester.enterText(
      find.byKey(const Key('addVideoFormField')),
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42s',
    );
    await tester.tap(find.byKey(const Key('addVideoFormSubmitButton')));
    await tester.pump();

    verify(
      () => addVideoCubit.submit(
        roomId: testRoomId,
        youtubeVideoId: YoutubeVideoId.parse('dQw4w9WgXcQ'),
      ),
    ).called(1);
  });

  testWidgets('rejects malformed input inline and issues no request '
      '(VS-ADD-02)', (tester) async {
    await tester.pumpWidget(wrap(const AddVideoState.initial()));

    await tester.enterText(
      find.byKey(const Key('addVideoFormField')),
      'not a video',
    );
    await tester.tap(find.byKey(const Key('addVideoFormSubmitButton')));
    await tester.pump();

    verifyNever(
      () => addVideoCubit.submit(
        roomId: any(named: 'roomId'),
        youtubeVideoId: any(named: 'youtubeVideoId'),
      ),
    );
  });

  testWidgets('rejects an empty field and issues no request (VS-ADD-02)', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const AddVideoState.initial()));

    await tester.tap(find.byKey(const Key('addVideoFormSubmitButton')));
    await tester.pump();

    verifyNever(
      () => addVideoCubit.submit(
        roomId: any(named: 'roomId'),
        youtubeVideoId: any(named: 'youtubeVideoId'),
      ),
    );
  });

  testWidgets('replaces the button with an indicator while submitting', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const AddVideoState.submitting()));

    expect(
      find.byKey(const Key('addVideoFormSubmittingIndicator')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('addVideoFormSubmitButton')), findsNothing);
  });

  testWidgets('dispatches sessionJoined once the session is created '
      '(VS-ADD-01)', (tester) async {
    whenListen(
      addVideoCubit,
      Stream<AddVideoState>.fromIterable([AddVideoState.success(session)]),
      initialState: const AddVideoState.submitting(),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    verify(
      () => videoSyncBloc.add(const VideoSyncEvent.sessionJoined()),
    ).called(1);
  });

  testWidgets('shows a snack bar when the backend rejects the video '
      '(VS-ADD-04)', (tester) async {
    whenListen(
      addVideoCubit,
      Stream<AddVideoState>.fromIterable([
        const AddVideoState.failure(
          Failure.server(statusCode: 400, message: 'video not found'),
        ),
      ]),
      initialState: const AddVideoState.submitting(),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    verifyNever(() => videoSyncBloc.add(const VideoSyncEvent.sessionJoined()));
  });
}
