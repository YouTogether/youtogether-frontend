import 'package:bloc_test/bloc_test.dart';
import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/room/domain/entities/room_entity.dart';
import 'package:youtogether/features/room/domain/usecases/get_room_by_id_usecase.dart';
import 'package:youtogether/features/video_sync/domain/entities/presence_entity.dart';
import 'package:youtogether/features/video_sync/domain/entities/sync_barrier_entity.dart';
import 'package:youtogether/features/video_sync/domain/entities/video_session_entity.dart';
import 'package:youtogether/features/video_sync/domain/entities/video_session_metadata_entity.dart';
import 'package:youtogether/features/video_sync/domain/usecases/create_sync_barrier_params.dart';
import 'package:youtogether/features/video_sync/domain/usecases/create_sync_barrier_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/delete_sync_barrier_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/get_current_playback_state_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/get_video_session_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/increment_ready_count_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/set_all_ready_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/subscribe_to_playback_state_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/subscribe_to_presence_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/subscribe_to_sync_barrier_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/update_barrier_total_count_params.dart';
import 'package:youtogether/features/video_sync/domain/usecases/update_barrier_total_count_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/update_playback_state_params.dart';
import 'package:youtogether/features/video_sync/domain/usecases/update_playback_state_usecase.dart';
import 'package:youtogether/features/video_sync/domain/value_objects/video_sync_config.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_bloc.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_event.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_state.dart';

class MockGetRoomByIdUseCase extends Mock implements GetRoomByIdUseCase {}

class MockGetVideoSessionUseCase extends Mock
    implements GetVideoSessionUseCase {}

class MockGetCurrentPlaybackStateUseCase extends Mock
    implements GetCurrentPlaybackStateUseCase {}

class MockSubscribeToPlaybackStateUseCase extends Mock
    implements SubscribeToPlaybackStateUseCase {}

class MockUpdatePlaybackStateUseCase extends Mock
    implements UpdatePlaybackStateUseCase {}

class MockCreateSyncBarrierUseCase extends Mock
    implements CreateSyncBarrierUseCase {}

class MockSubscribeToSyncBarrierUseCase extends Mock
    implements SubscribeToSyncBarrierUseCase {}

class MockIncrementReadyCountUseCase extends Mock
    implements IncrementReadyCountUseCase {}

class MockUpdateBarrierTotalCountUseCase extends Mock
    implements UpdateBarrierTotalCountUseCase {}

class MockSetAllReadyUseCase extends Mock implements SetAllReadyUseCase {}

class MockDeleteSyncBarrierUseCase extends Mock
    implements DeleteSyncBarrierUseCase {}

class MockSubscribeToPresenceUseCase extends Mock
    implements SubscribeToPresenceUseCase {}

/// Unit tests for [VideoSyncBloc].
///
/// Uses `bloc_test`'s `blocTest`, mirroring `room_bloc_test.dart`.
/// Extended for: `sessionJoined`'s three-step sequencing
/// (metadata fetch, initial playback fetch, live subscription),
/// disconnect handling, and `retryRequested`. The
/// play/pause/seek suites are carried over, adapted to the bloc's new
/// constructor shape (no more `isLeader`/`durationSeconds`/
/// `initialPosition` constructor params — those are now populated by
/// `sessionJoined`).
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios VS-SYN-01 through VS-SYN-06.
void main() {
  late MockGetRoomByIdUseCase getRoomByIdUseCase;
  late MockGetVideoSessionUseCase getVideoSessionUseCase;
  late MockGetCurrentPlaybackStateUseCase getCurrentPlaybackStateUseCase;
  late MockSubscribeToPlaybackStateUseCase subscribeToPlaybackStateUseCase;
  late MockUpdatePlaybackStateUseCase updatePlaybackStateUseCase;
  late MockCreateSyncBarrierUseCase createSyncBarrierUseCase;
  late MockSubscribeToSyncBarrierUseCase subscribeToSyncBarrierUseCase;
  late MockIncrementReadyCountUseCase incrementReadyCountUseCase;
  late MockUpdateBarrierTotalCountUseCase updateBarrierTotalCountUseCase;
  late MockSetAllReadyUseCase setAllReadyUseCase;
  late MockDeleteSyncBarrierUseCase deleteSyncBarrierUseCase;
  late MockSubscribeToPresenceUseCase subscribeToPresenceUseCase;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';
  const leaderId = '550e8400-e29b-41d4-a716-446655440000';
  const viewerId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

  final room = RoomEntity(
    id: roomId,
    name: 'Friday Movie Night',
    description: 'Weekly watch party',
    ownerId: leaderId,
    isPublic: true,
    memberCount: 2,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  final metadata = VideoSessionMetadataEntity(
    id: 'session-uuid',
    roomId: roomId,
    youtubeVideoId: 'dQw4w9WgXcQ',
    title: 'Never Gonna Give You Up',
    thumbnailUrl: null,
    durationSeconds: 213,
    addedBy: leaderId,
    createdAt: DateTime.utc(2026, 1, 5),
  );

  /// Fixed wall-clock instant for every bloc built by [buildBloc], and
  /// the default `updatedAt` of every session built by [buildSession].
  ///
  /// Since F-V07-T1, `_performSessionJoin` extrapolates the leader's
  /// last written position by the interval between `updatedAt` and the
  /// bloc's clock. With a real clock and a hardcoded `updatedAt`, that
  /// interval is months wide, every join extrapolates past the end of
  /// the video, and the duration bound turns every expected position
  /// into `metadata.durationSeconds` — which is exactly what happened
  /// when this constant did not exist. Pinning both ends of the
  /// interval to the same instant gives an elapsed time of zero, so
  /// every test that is not specifically about extrapolation observes
  /// the position it wrote, unchanged.
  final testNow = DateTime.utc(2026, 3, 1, 12);

  /// [buildSession]'s default `leaderId`.
  ///
  /// Declared separately because a parameter named `leaderId` shadows
  /// the constant of the same name inside its own default expression:
  /// `String leaderId = leaderId` resolves to the parameter referring to
  /// itself, which is not a constant expression and does not compile.
  const defaultSessionLeaderId = leaderId;

  VideoSessionEntity buildSession({
    required bool isPlaying,
    Duration position = const Duration(seconds: 42),
    String leaderId = defaultSessionLeaderId,
    DateTime? updatedAt,
  }) {
    return VideoSessionEntity(
      roomId: roomId,
      youtubeVideoId: 'dQw4w9WgXcQ',
      isPlaying: isPlaying,
      currentPosition: position,
      leaderId: leaderId,
      updatedAt: updatedAt ?? testNow,
    );
  }

  setUpAll(() {
    registerFallbackValue(
      const CreateSyncBarrierParams(
        roomId: roomId,
        targetTimestamp: Duration.zero,
        totalCount: 0,
      ),
    );
    registerFallbackValue(
      const UpdateBarrierTotalCountParams(roomId: roomId, totalCount: 0),
    );
    registerFallbackValue(
      const UpdatePlaybackStateParams(
        roomId: roomId,
        isPlaying: false,
        position: Duration.zero,
      ),
    );
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    getRoomByIdUseCase = MockGetRoomByIdUseCase();
    getVideoSessionUseCase = MockGetVideoSessionUseCase();
    getCurrentPlaybackStateUseCase = MockGetCurrentPlaybackStateUseCase();
    subscribeToPlaybackStateUseCase = MockSubscribeToPlaybackStateUseCase();
    updatePlaybackStateUseCase = MockUpdatePlaybackStateUseCase();
    createSyncBarrierUseCase = MockCreateSyncBarrierUseCase();
    subscribeToSyncBarrierUseCase = MockSubscribeToSyncBarrierUseCase();
    incrementReadyCountUseCase = MockIncrementReadyCountUseCase();
    updateBarrierTotalCountUseCase = MockUpdateBarrierTotalCountUseCase();
    setAllReadyUseCase = MockSetAllReadyUseCase();
    deleteSyncBarrierUseCase = MockDeleteSyncBarrierUseCase();
    subscribeToPresenceUseCase = MockSubscribeToPresenceUseCase();

    when(() => getRoomByIdUseCase(roomId)).thenAnswer((_) async => Right(room));
    when(
      () => subscribeToPresenceUseCase(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => subscribeToSyncBarrierUseCase(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => createSyncBarrierUseCase(any()),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => updateBarrierTotalCountUseCase(any()),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => incrementReadyCountUseCase(any()),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => setAllReadyUseCase(any()),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => deleteSyncBarrierUseCase(any()),
    ).thenAnswer((_) async => const Right(null));
  });

  VideoSyncBloc buildBloc({
    required String currentUserId,
    DateTime Function()? now,
  }) {
    return VideoSyncBloc(
      roomId: roomId,
      currentUserId: currentUserId,
      getRoomByIdUseCase: getRoomByIdUseCase,
      getVideoSessionUseCase: getVideoSessionUseCase,
      getCurrentPlaybackStateUseCase: getCurrentPlaybackStateUseCase,
      subscribeToPlaybackStateUseCase: subscribeToPlaybackStateUseCase,
      updatePlaybackStateUseCase: updatePlaybackStateUseCase,
      createSyncBarrierUseCase: createSyncBarrierUseCase,
      subscribeToSyncBarrierUseCase: subscribeToSyncBarrierUseCase,
      incrementReadyCountUseCase: incrementReadyCountUseCase,
      updateBarrierTotalCountUseCase: updateBarrierTotalCountUseCase,
      setAllReadyUseCase: setAllReadyUseCase,
      deleteSyncBarrierUseCase: deleteSyncBarrierUseCase,
      subscribeToPresenceUseCase: subscribeToPresenceUseCase,
      now: now ?? () => testNow,
    );
  }

  group('VideoSyncEvent.sessionJoined — VS-SYN-01', () {
    blocTest<VideoSyncBloc, VideoSyncState>(
      'emits loading, then ready with the fetched position/isPlaying, '
      'derives isLeader true for the leader, and opens the subscription',
      build: () {
        when(
          () => getVideoSessionUseCase(roomId),
        ).thenAnswer((_) async => Right(metadata));
        when(
          () => getCurrentPlaybackStateUseCase(roomId),
        ).thenAnswer((_) async => Right(buildSession(isPlaying: true)));
        when(
          () => subscribeToPlaybackStateUseCase(roomId),
        ).thenAnswer((_) => const Stream.empty());
        return buildBloc(currentUserId: leaderId);
      },
      act: (bloc) => bloc.add(const VideoSyncEvent.sessionJoined()),
      expect: () => [
        const VideoSyncState.loading(),
        const VideoSyncState.ready(
          position: Duration(seconds: 42),
          isPlaying: true,
        ),
      ],
      verify: (_) {
        verify(() => getVideoSessionUseCase(roomId)).called(1);
        verify(() => getCurrentPlaybackStateUseCase(roomId)).called(1);
        verify(() => subscribeToPlaybackStateUseCase(roomId)).called(1);
      },
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'exposes isLeader, durationSeconds, and youtubeVideoId via public '
      'getters once sessionJoined completes',
      build: () {
        when(
          () => getVideoSessionUseCase(roomId),
        ).thenAnswer((_) async => Right(metadata));
        when(
          () => getCurrentPlaybackStateUseCase(roomId),
        ).thenAnswer((_) async => Right(buildSession(isPlaying: true)));
        when(
          () => subscribeToPlaybackStateUseCase(roomId),
        ).thenAnswer((_) => const Stream.empty());
        return buildBloc(currentUserId: leaderId);
      },
      act: (bloc) => bloc.add(const VideoSyncEvent.sessionJoined()),
      verify: (bloc) {
        expect(bloc.isLeader, isTrue);
        expect(bloc.durationSeconds, 213);
        expect(bloc.youtubeVideoId, 'dQw4w9WgXcQ');
      },
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'fetches metadata before fetching playback state (sequencing)',
      build: () {
        final callOrder = <String>[];
        when(() => getVideoSessionUseCase(roomId)).thenAnswer((_) async {
          callOrder.add('metadata');
          return Right(metadata);
        });
        when(() => getCurrentPlaybackStateUseCase(roomId)).thenAnswer((
          _,
        ) async {
          callOrder.add('playbackState');
          return Right(buildSession(isPlaying: false));
        });
        when(
          () => subscribeToPlaybackStateUseCase(roomId),
        ).thenAnswer((_) => const Stream.empty());
        addTearDown(() => expect(callOrder, ['metadata', 'playbackState']));
        return buildBloc(currentUserId: leaderId);
      },
      act: (bloc) => bloc.add(const VideoSyncEvent.sessionJoined()),
      expect: () => [
        const VideoSyncState.loading(),
        const VideoSyncState.ready(
          position: Duration(seconds: 42),
          isPlaying: false,
        ),
      ],
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'emits failure when the metadata fetch fails, without calling the '
      'playback-state or subscription use cases',
      build: () {
        when(
          () => getVideoSessionUseCase(roomId),
        ).thenAnswer((_) async => const Left(Failure.notFound()));
        return buildBloc(currentUserId: leaderId);
      },
      act: (bloc) => bloc.add(const VideoSyncEvent.sessionJoined()),
      expect: () => [
        const VideoSyncState.loading(),
        const VideoSyncState.failure(Failure.notFound()),
      ],
      verify: (_) {
        verifyNever(() => getCurrentPlaybackStateUseCase(any()));
        verifyNever(() => subscribeToPlaybackStateUseCase(any()));
      },
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'emits failure when the initial playback-state fetch fails',
      build: () {
        when(
          () => getVideoSessionUseCase(roomId),
        ).thenAnswer((_) async => Right(metadata));
        when(() => getCurrentPlaybackStateUseCase(roomId)).thenAnswer(
          (_) async => const Left(Failure.firebase(message: 'unreachable')),
        );
        return buildBloc(currentUserId: leaderId);
      },
      act: (bloc) => bloc.add(const VideoSyncEvent.sessionJoined()),
      expect: () => [
        const VideoSyncState.loading(),
        const VideoSyncState.failure(Failure.firebase(message: 'unreachable')),
      ],
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'derives isLeader false for a viewer whose id does not match leaderId',
      build: () {
        when(
          () => getVideoSessionUseCase(roomId),
        ).thenAnswer((_) async => Right(metadata));
        when(
          () => getCurrentPlaybackStateUseCase(roomId),
        ).thenAnswer((_) async => Right(buildSession(isPlaying: true)));
        when(
          () => subscribeToPlaybackStateUseCase(roomId),
        ).thenAnswer((_) => const Stream.empty());
        return buildBloc(currentUserId: viewerId);
      },
      act: (bloc) async {
        bloc.add(const VideoSyncEvent.sessionJoined());
        await Future<void>.delayed(Duration.zero);
        // A non-leader's playRequested must remain a no-op — this
        // indirectly proves isLeader was derived as false.
        bloc.add(const VideoSyncEvent.playRequested());
      },
      expect: () => [
        const VideoSyncState.loading(),
        const VideoSyncState.ready(
          position: Duration(seconds: 42),
          isPlaying: true,
        ),
      ],
      verify: (_) {
        verifyNever(() => updatePlaybackStateUseCase(any()));
      },
    );
  });

  group('VideoSyncEvent.sessionUpdated (live subscription forwarding)', () {
    blocTest<VideoSyncBloc, VideoSyncState>(
      'emits playing/paused according to the forwarded session\'s isPlaying',
      build: () => buildBloc(currentUserId: leaderId),
      act: (bloc) => bloc.add(
        VideoSyncEvent.sessionUpdated(
          Right(
            buildSession(
              isPlaying: true,
              position: const Duration(seconds: 55),
            ),
          ),
        ),
      ),
      expect: () => [
        const VideoSyncState.playing(position: Duration(seconds: 55)),
      ],
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'emits VideoSyncState.failure(FirebaseFailure) on a forwarded '
      'disconnect event (VS-SYN-06)',
      build: () => buildBloc(currentUserId: leaderId),
      act: (bloc) => bloc.add(
        const VideoSyncEvent.sessionUpdated(
          Left(Failure.firebase(message: 'disconnected')),
        ),
      ),
      expect: () => [
        const VideoSyncState.failure(Failure.firebase(message: 'disconnected')),
      ],
    );
  });

  group('VideoSyncEvent.retryRequested', () {
    blocTest<VideoSyncBloc, VideoSyncState>(
      're-runs the full sessionJoined flow',
      build: () {
        when(
          () => getVideoSessionUseCase(roomId),
        ).thenAnswer((_) async => Right(metadata));
        when(
          () => getCurrentPlaybackStateUseCase(roomId),
        ).thenAnswer((_) async => Right(buildSession(isPlaying: false)));
        when(
          () => subscribeToPlaybackStateUseCase(roomId),
        ).thenAnswer((_) => const Stream.empty());
        return buildBloc(currentUserId: leaderId);
      },
      act: (bloc) => bloc.add(const VideoSyncEvent.retryRequested()),
      expect: () => [
        const VideoSyncState.loading(),
        const VideoSyncState.ready(
          position: Duration(seconds: 42),
          isPlaying: false,
        ),
      ],
    );
  });

  group('VideoSyncEvent.playRequested (leader) — VS-SYN-02', () {
    // NOTE: the leader's *first* playRequested no longer writes
    // playback state directly — it opens the ready gate instead
    // (`YouTogether_Ad_Synchronisation_Strategy.docx`, Section 4). The
    // original F-V02 version of this test asserted a direct write on
    // the first play and would now be asserting behaviour that no
    // longer exists, so it was rewritten rather than left passing
    // against a stale expectation. Both halves of the new behaviour are
    // covered: the gate itself in
    // `video_sync_bloc_ready_gate_test.dart`, and the direct-write path
    // for subsequent plays here.
    blocTest<VideoSyncBloc, VideoSyncState>(
      'the first playRequested opens the ready gate rather than writing '
      'playback state directly',
      build: () {
        when(
          () => getVideoSessionUseCase(roomId),
        ).thenAnswer((_) async => Right(metadata));
        when(() => getCurrentPlaybackStateUseCase(roomId)).thenAnswer(
          (_) async => Right(
            buildSession(
              isPlaying: false,
              position: const Duration(seconds: 42),
            ),
          ),
        );
        when(
          () => subscribeToPlaybackStateUseCase(roomId),
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => subscribeToPresenceUseCase(any()),
        ).thenAnswer((_) => Stream.value(const Right(<PresenceEntity>[])));
        when(
          () => createSyncBarrierUseCase(any()),
        ).thenAnswer((_) async => const Right(null));
        when(
          () => subscribeToSyncBarrierUseCase(any()),
        ).thenAnswer((_) => const Stream.empty());
        return buildBloc(currentUserId: leaderId);
      },
      act: (bloc) async {
        bloc.add(const VideoSyncEvent.sessionJoined());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const VideoSyncEvent.playRequested());
      },
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verify(
          () => createSyncBarrierUseCase(
            const CreateSyncBarrierParams(
              roomId: roomId,
              targetTimestamp: Duration(seconds: 42),
              totalCount: 0,
            ),
          ),
        ).called(1);
        verifyNever(() => updatePlaybackStateUseCase(any()));
      },
    );
  });

  group('VideoSyncEvent.seekRequested (leader) — VS-SYN-04', () {
    blocTest<VideoSyncBloc, VideoSyncState>(
      'rejects a target beyond the video duration with no state change '
      'and no Firebase write attempted',
      build: () {
        when(
          () => getVideoSessionUseCase(roomId),
        ).thenAnswer((_) async => Right(metadata));
        when(
          () => getCurrentPlaybackStateUseCase(roomId),
        ).thenAnswer((_) async => Right(buildSession(isPlaying: false)));
        when(
          () => subscribeToPlaybackStateUseCase(roomId),
        ).thenAnswer((_) => const Stream.empty());
        return buildBloc(currentUserId: leaderId);
      },
      act: (bloc) async {
        bloc.add(const VideoSyncEvent.sessionJoined());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const VideoSyncEvent.seekRequested(Duration(seconds: 999)));
      },
      expect: () => [
        const VideoSyncState.loading(),
        const VideoSyncState.ready(
          position: Duration(seconds: 42),
          isPlaying: false,
        ),
      ],
      verify: (_) {
        verifyNever(() => updatePlaybackStateUseCase(any()));
      },
    );
  });

  group('Leader-only gating — VS-SYN-05', () {
    blocTest<VideoSyncBloc, VideoSyncState>(
      'playRequested is a no-op for a non-leader',
      build: () => buildBloc(currentUserId: viewerId),
      act: (bloc) => bloc.add(const VideoSyncEvent.playRequested()),
      expect: () => <VideoSyncState>[],
      verify: (_) => verifyNever(() => updatePlaybackStateUseCase(any())),
    );
  });

  group('VideoSyncEvent.adDetected / adEnded — F-V04', () {
    blocTest<VideoSyncBloc, VideoSyncState>(
      'emits adInProgress on adDetected',
      build: () => buildBloc(currentUserId: leaderId),
      act: (bloc) => bloc.add(const VideoSyncEvent.adDetected()),
      expect: () => [const VideoSyncState.adInProgress()],
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'on adEnded, re-emits playing/paused from the last known session '
      'received via sessionUpdated',
      build: () {
        when(
          () => getVideoSessionUseCase(roomId),
        ).thenAnswer((_) async => Right(metadata));
        when(
          () => getCurrentPlaybackStateUseCase(roomId),
        ).thenAnswer((_) async => Right(buildSession(isPlaying: false)));
        when(
          () => subscribeToPlaybackStateUseCase(roomId),
        ).thenAnswer((_) => const Stream.empty());
        return buildBloc(currentUserId: leaderId);
      },
      act: (bloc) async {
        bloc.add(const VideoSyncEvent.sessionJoined());
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          VideoSyncEvent.sessionUpdated(
            Right(
              buildSession(
                isPlaying: true,
                position: const Duration(seconds: 77),
              ),
            ),
          ),
        );
        bloc.add(const VideoSyncEvent.adDetected());
        bloc.add(const VideoSyncEvent.adEnded());
      },
      expect: () => [
        const VideoSyncState.loading(),
        const VideoSyncState.ready(
          position: Duration(seconds: 42),
          isPlaying: false,
        ),
        const VideoSyncState.playing(position: Duration(seconds: 77)),
        const VideoSyncState.adInProgress(),
        const VideoSyncState.playing(position: Duration(seconds: 77)),
      ],
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'adEnded is a no-op (no emission) if no session has been received yet',
      build: () => buildBloc(currentUserId: leaderId),
      act: (bloc) => bloc.add(const VideoSyncEvent.adEnded()),
      expect: () => <VideoSyncState>[],
    );
  });

  /// Regression tests for F-V07-T1.
  ///
  /// Two defects observed during Sprint 3 acceptance testing are
  /// covered here.
  ///
  /// First, `lastKnownSession` was assigned only from `sessionUpdated`,
  /// i.e. from the live Firebase subscription.
  /// `PlayerReconciliation._reconcile` returns immediately while that
  /// field is `null`, so the 500 ms
  /// sampling loop was inert between the end of `sessionJoined` and the
  /// arrival of the first stream event — even though
  /// `GetCurrentPlaybackStateUseCase` had already read exactly that
  /// data and discarded it.
  ///
  /// Second, `ready` carried `session.currentPosition` verbatim.
  /// Firebase stores the position as of the leader's last command,
  /// together with `updatedAt`; a participant joining three minutes
  /// into an active session was therefore handed a three-minute-stale
  /// position. `SyncEngine.computeExpectedPosition` already performs
  /// the required extrapolation and was simply not called on this path.
  ///
  /// @competency Unit test harness, TDD cycle.
  /// @competency Test scenarios VS-SYN-07, VS-SYN-08.
  group('VideoSyncEvent.sessionJoined — session seeding and extrapolation '
      '(F-V07-T1)', () {
    VideoSessionEntity sessionAt({
      required bool isPlaying,
      required Duration position,
      required Duration staleness,
    }) {
      return buildSession(
        isPlaying: isPlaying,
        position: position,
        updatedAt: testNow.subtract(staleness),
      );
    }

    void stubJoin(VideoSessionEntity session) {
      when(
        () => getVideoSessionUseCase(roomId),
      ).thenAnswer((_) async => Right(metadata));
      when(
        () => getCurrentPlaybackStateUseCase(roomId),
      ).thenAnswer((_) async => Right(session));
      when(
        () => subscribeToPlaybackStateUseCase(roomId),
      ).thenAnswer((_) => const Stream.empty());
    }

    test('seeds lastKnownSession from the initial single read, before any '
        'sessionUpdated event has arrived', () async {
      final session = sessionAt(
        isPlaying: true,
        position: const Duration(seconds: 100),
        staleness: const Duration(seconds: 20),
      );
      stubJoin(session);
      final bloc = buildBloc(currentUserId: leaderId, now: () => testNow);

      expect(bloc.lastKnownSession, isNull);

      bloc.add(const VideoSyncEvent.sessionJoined());
      await bloc.stream.firstWhere((s) => s is VideoSyncReady);

      expect(bloc.lastKnownSession, session);

      await bloc.close();
    });

    test('extrapolates the ready position by the elapsed time since the '
        'leader last wrote, while playing (VS-SYN-07)', () async {
      stubJoin(
        sessionAt(
          isPlaying: true,
          position: const Duration(seconds: 60),
          staleness: const Duration(seconds: 30),
        ),
      );
      final bloc = buildBloc(currentUserId: leaderId);

      bloc.add(const VideoSyncEvent.sessionJoined());
      await bloc.stream.firstWhere((s) => s is VideoSyncReady);

      expect(
        bloc.state,
        const VideoSyncState.ready(
          position: Duration(seconds: 90),
          isPlaying: true,
        ),
      );

      await bloc.close();
    });

    test('does not extrapolate a paused session: a paused leader has not '
        'advanced (VS-SYN-08)', () async {
      stubJoin(
        sessionAt(
          isPlaying: false,
          position: const Duration(seconds: 90),
          staleness: const Duration(minutes: 30),
        ),
      );
      final bloc = buildBloc(currentUserId: leaderId);

      bloc.add(const VideoSyncEvent.sessionJoined());
      await bloc.stream.firstWhere((s) => s is VideoSyncReady);

      expect(
        bloc.state,
        const VideoSyncState.ready(
          position: Duration(seconds: 90),
          isPlaying: false,
        ),
      );

      await bloc.close();
    });

    test('clamps the extrapolated position to the video duration: a session '
        'abandoned by its leader must not seek past the end', () async {
      stubJoin(
        sessionAt(
          isPlaying: true,
          position: const Duration(seconds: 100),
          staleness: const Duration(hours: 1),
        ),
      );
      final bloc = buildBloc(currentUserId: leaderId);

      bloc.add(const VideoSyncEvent.sessionJoined());
      await bloc.stream.firstWhere((s) => s is VideoSyncReady);

      expect(
        bloc.state,
        VideoSyncState.ready(
          position: Duration(seconds: metadata.durationSeconds),
          isPlaying: true,
        ),
      );

      await bloc.close();
    });

    test('treats a negative elapsed interval as zero: clock skew between the '
        'writing client and this one must not rewind the position', () async {
      stubJoin(
        sessionAt(
          isPlaying: true,
          position: const Duration(seconds: 100),
          staleness: const Duration(seconds: -30),
        ),
      );
      final bloc = buildBloc(currentUserId: leaderId);

      bloc.add(const VideoSyncEvent.sessionJoined());
      await bloc.stream.firstWhere((s) => s is VideoSyncReady);

      expect(
        bloc.state,
        const VideoSyncState.ready(
          position: Duration(seconds: 100),
          isPlaying: true,
        ),
      );

      await bloc.close();
    });
  });

  /// Regression tests for F-V06-T4.
  ///
  /// Before this ticket, `isLeader` was derived from Firebase's
  /// `leader_id`, read by `GetCurrentPlaybackStateUseCase`. That node
  /// does not exist until a video session has been created, so the room
  /// owner was denied leader privileges in exactly the situation where
  /// they are needed — creating the first session (F-V06-T3).
  ///
  /// @competency Unit test harness, TDD cycle.
  /// @competency Test scenarios VS-LED-01, VS-LED-02, VS-LED-03.
  group('leader derivation from room ownership (F-V06-T4)', () {
    blocTest<VideoSyncBloc, VideoSyncState>(
      'grants leader privileges to the room owner even when the room has no '
      'video session yet (VS-LED-01)',
      build: () {
        when(
          () => getVideoSessionUseCase(roomId),
        ).thenAnswer((_) async => const Left(Failure.notFound()));
        return buildBloc(currentUserId: leaderId);
      },
      act: (bloc) => bloc.add(const VideoSyncEvent.sessionJoined()),
      expect: () => [
        const VideoSyncState.loading(),
        const VideoSyncState.failure(Failure.notFound()),
      ],
      verify: (bloc) {
        expect(bloc.isLeader, isTrue);
        verifyNever(() => getCurrentPlaybackStateUseCase(any()));
      },
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'prefers room ownership over a disagreeing Firebase leader_id '
      '(VS-LED-02)',
      build: () {
        when(
          () => getVideoSessionUseCase(roomId),
        ).thenAnswer((_) async => Right(metadata));
        when(() => getCurrentPlaybackStateUseCase(roomId)).thenAnswer(
          (_) async =>
              Right(buildSession(isPlaying: false, leaderId: viewerId)),
        );
        when(
          () => subscribeToPlaybackStateUseCase(roomId),
        ).thenAnswer((_) => const Stream.empty());
        return buildBloc(currentUserId: leaderId);
      },
      act: (bloc) => bloc.add(const VideoSyncEvent.sessionJoined()),
      verify: (bloc) => expect(bloc.isLeader, isTrue),
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'denies leader privileges to a non-owner whose id matches a stale '
      'Firebase leader_id — no write is attempted (VS-LED-02, VS-SYN-05)',
      build: () {
        when(
          () => getVideoSessionUseCase(roomId),
        ).thenAnswer((_) async => Right(metadata));
        when(() => getCurrentPlaybackStateUseCase(roomId)).thenAnswer(
          (_) async => Right(buildSession(isPlaying: true, leaderId: viewerId)),
        );
        when(
          () => subscribeToPlaybackStateUseCase(roomId),
        ).thenAnswer((_) => const Stream.empty());
        return buildBloc(currentUserId: viewerId);
      },
      act: (bloc) async {
        bloc.add(const VideoSyncEvent.sessionJoined());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const VideoSyncEvent.pauseRequested());
      },
      verify: (bloc) {
        expect(bloc.isLeader, isFalse);
        verifyNever(() => updatePlaybackStateUseCase(any()));
      },
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'emits failure and grants nothing when the room fetch itself fails '
      '(VS-LED-03)',
      build: () {
        when(
          () => getRoomByIdUseCase(roomId),
        ).thenAnswer((_) async => const Left(Failure.notFound()));
        return buildBloc(currentUserId: leaderId);
      },
      act: (bloc) => bloc.add(const VideoSyncEvent.sessionJoined()),
      expect: () => [
        const VideoSyncState.loading(),
        const VideoSyncState.failure(Failure.notFound()),
      ],
      verify: (bloc) {
        expect(bloc.isLeader, isFalse);
        verifyNever(() => getVideoSessionUseCase(any()));
        verifyNever(() => getCurrentPlaybackStateUseCase(any()));
      },
    );
  });

  /// Tests for F-V08-T1.
  ///
  /// Firebase writes previously occurred only on play, pause and seek.
  /// All ongoing synchronisation therefore rested on wall-clock
  /// extrapolation from a single `updatedAt` that could be minutes old,
  /// which holds only while the leader's own playback is uninterrupted.
  /// Any advertisement, buffering episode or backgrounding on the
  /// leader's side introduced an error that nothing ever corrected and
  /// that grew for the remainder of the session — and that every late
  /// joiner inherited.
  ///
  /// The handler's guard is `state is VideoSyncPlaying`, and that alone.
  /// An earlier draft of this suite also exercised an `_initialStartDone`
  /// flag, which was redundant: while the ready gate is open the state is
  /// [VideoSyncBarrierWaiting], and during a local advertisement it is
  /// [VideoSyncAdInProgress], so the state test already excludes both.
  /// Expressing one rule once also keeps this suite clear of the barrier
  /// machinery, which `video_sync_bloc_ready_gate_test.dart` covers.
  ///
  /// @competency Unit test harness, TDD cycle.
  /// @competency Test scenario VS-SYN-10.
  group('VideoSyncEvent.heartbeatTicked (F-V08-T1)', () {
    const observed = Duration(seconds: 305);

    /// Number of states [joinAndPlay] emits — `loading`, `ready`, then
    /// `playing`/`paused` — skipped by the tests that assert the
    /// heartbeat itself emits nothing.
    const joinStateCount = 3;

    /// Mutable wall clock backing every bloc built in this group.
    ///
    /// The heartbeat is throttled against the bloc's own clock, so a
    /// test unable to move that clock would have to wait the real
    /// interval to observe the throttle at all. Reset by [setUp] so that
    /// no test inherits another's elapsed time.
    late DateTime now;

    setUp(() {
      now = testNow;
      when(
        () => getVideoSessionUseCase(roomId),
      ).thenAnswer((_) async => Right(metadata));
      when(
        () => getCurrentPlaybackStateUseCase(roomId),
      ).thenAnswer((_) async => Right(buildSession(isPlaying: false)));
      when(
        () => subscribeToPlaybackStateUseCase(roomId),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => updatePlaybackStateUseCase(any()),
      ).thenAnswer((_) async => const Right(null));
    });

    void advance(Duration amount) => now = now.add(amount);

    VideoSyncBloc buildHeartbeatBloc({String currentUserId = leaderId}) {
      return buildBloc(currentUserId: currentUserId, now: () => now);
    }

    /// Drives the bloc to [VideoSyncPlaying] (or [VideoSyncPaused]) the
    /// way production reaches it outside the initial collective start:
    /// a session join followed by a leader update arriving on the live
    /// subscription.
    ///
    /// The ready gate is deliberately not used. It resolves to the same
    /// [VideoSyncPlaying] state, and driving it here would pull the
    /// presence stream, the barrier stream and their stubs into a suite
    /// that is about none of them.
    Future<void> joinAndPlay(
      VideoSyncBloc bloc, {
      bool isPlaying = true,
    }) async {
      bloc.add(const VideoSyncEvent.sessionJoined());
      await pumpEventQueue();
      bloc.add(
        VideoSyncEvent.sessionUpdated(
          Right(
            buildSession(
              isPlaying: isPlaying,
              position: const Duration(seconds: 300),
            ),
          ),
        ),
      );
      await pumpEventQueue();
    }

    blocTest<VideoSyncBloc, VideoSyncState>(
      'writes the observed player position while leading an active session, '
      'without waiting for a first interval to elapse (VS-SYN-10)',
      build: buildHeartbeatBloc,
      act: (bloc) async {
        await joinAndPlay(bloc);
        bloc.add(const VideoSyncEvent.heartbeatTicked(position: observed));
        await pumpEventQueue();
      },
      verify: (_) {
        verify(
          () => updatePlaybackStateUseCase(
            const UpdatePlaybackStateParams(
              roomId: roomId,
              isPlaying: true,
              position: observed,
            ),
          ),
        ).called(1);
      },
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'emits no state of its own: a heartbeat must not disturb the leader\'s '
      'own slider while it is being dragged',
      build: buildHeartbeatBloc,
      act: (bloc) async {
        await joinAndPlay(bloc);
        bloc.add(const VideoSyncEvent.heartbeatTicked(position: observed));
        await pumpEventQueue();
      },
      skip: joinStateCount,
      expect: () => <VideoSyncState>[],
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'throttles to the configured interval: the 500 ms sampling cadence must '
      'not become the Firebase write cadence',
      build: buildHeartbeatBloc,
      act: (bloc) async {
        await joinAndPlay(bloc);
        // Twenty sampling intervals is ten seconds of playback, which
        // spans two heartbeat intervals: one write on the first beat,
        // one five seconds later.
        for (var i = 0; i < 20; i++) {
          advance(VideoSyncConfig.adDetectionInterval);
          bloc.add(
            VideoSyncEvent.heartbeatTicked(
              position: observed + Duration(milliseconds: 500 * i),
            ),
          );
          await pumpEventQueue();
        }
      },
      verify: (_) {
        verify(() => updatePlaybackStateUseCase(any())).called(2);
      },
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'ignores the heartbeat when the local participant is not the leader',
      build: () => buildHeartbeatBloc(currentUserId: viewerId),
      act: (bloc) async {
        await joinAndPlay(bloc);
        advance(VideoSyncConfig.leaderHeartbeatInterval);
        bloc.add(const VideoSyncEvent.heartbeatTicked(position: observed));
        await pumpEventQueue();
      },
      verify: (_) => verifyNever(() => updatePlaybackStateUseCase(any())),
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'ignores the heartbeat while the session is paused: a paused leader has '
      'nothing to republish',
      build: buildHeartbeatBloc,
      act: (bloc) async {
        await joinAndPlay(bloc, isPlaying: false);
        advance(VideoSyncConfig.leaderHeartbeatInterval);
        bloc.add(const VideoSyncEvent.heartbeatTicked(position: observed));
        await pumpEventQueue();
      },
      verify: (_) => verifyNever(() => updatePlaybackStateUseCase(any())),
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'ignores the heartbeat while the ready gate is open',
      build: buildHeartbeatBloc,
      act: (bloc) async {
        bloc.add(const VideoSyncEvent.sessionJoined());
        await pumpEventQueue();
        bloc.add(
          const VideoSyncEvent.barrierUpdated(
            Right(
              SyncBarrierEntity(
                targetTimestamp: Duration(seconds: 300),
                readyCount: 1,
                totalCount: 3,
                allReady: false,
              ),
            ),
          ),
        );
        await pumpEventQueue();
        advance(VideoSyncConfig.leaderHeartbeatInterval);
        bloc.add(const VideoSyncEvent.heartbeatTicked(position: observed));
        await pumpEventQueue();
      },
      verify: (_) => verifyNever(() => updatePlaybackStateUseCase(any())),
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'ignores the heartbeat while an advertisement is in progress: content '
      'time is frozen and republishing it would rewind every viewer',
      build: buildHeartbeatBloc,
      act: (bloc) async {
        await joinAndPlay(bloc);
        bloc.add(const VideoSyncEvent.adDetected());
        await pumpEventQueue();
        advance(VideoSyncConfig.leaderHeartbeatInterval);
        bloc.add(const VideoSyncEvent.heartbeatTicked(position: observed));
        await pumpEventQueue();
      },
      verify: (_) => verifyNever(() => updatePlaybackStateUseCase(any())),
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'does not surface a failed heartbeat write: the next beat retries and a '
      'transient write refusal is not a session failure',
      build: () {
        final bloc = buildHeartbeatBloc();
        when(() => updatePlaybackStateUseCase(any())).thenAnswer(
          (_) async => const Left(Failure.firebase(message: 'write refused')),
        );
        return bloc;
      },
      act: (bloc) async {
        await joinAndPlay(bloc);
        bloc.add(const VideoSyncEvent.heartbeatTicked(position: observed));
        await pumpEventQueue();
      },
      skip: joinStateCount,
      expect: () => <VideoSyncState>[],
      verify: (_) {
        verify(() => updatePlaybackStateUseCase(any())).called(1);
      },
    );
  });
}
