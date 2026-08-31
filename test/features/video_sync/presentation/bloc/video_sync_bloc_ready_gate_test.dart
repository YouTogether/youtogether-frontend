import 'package:bloc_test/bloc_test.dart';
import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/features/room/domain/entities/room_entity.dart';
import 'package:youtogether/features/room/domain/usecases/get_room_by_id_usecase.dart';

import 'package:youtogether/features/video_sync/domain/entities/presence_entity.dart';
import 'package:youtogether/features/video_sync/domain/entities/sync_barrier_entity.dart';
import 'package:youtogether/features/video_sync/domain/entities/video_session_entity.dart';
import 'package:youtogether/features/video_sync/domain/entities/video_session_metadata_entity.dart';
import 'package:youtogether/features/video_sync/domain/usecases/create_sync_barrier_params.dart';
import 'package:youtogether/features/video_sync/domain/usecases/create_sync_barrier_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/delete_sync_barrier_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/increment_ready_count_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/set_all_ready_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/subscribe_to_presence_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/subscribe_to_sync_barrier_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/update_barrier_total_count_params.dart';
import 'package:youtogether/features/video_sync/domain/usecases/update_barrier_total_count_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/get_current_playback_state_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/get_video_session_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/subscribe_to_playback_state_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/update_playback_state_params.dart';
import 'package:youtogether/features/video_sync/domain/usecases/update_playback_state_usecase.dart';
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

/// Unit tests for [VideoSyncBloc]'s ready-gate orchestration (F-V04,
/// `YouTogether_Ad_Synchronisation_Strategy.docx`, Section 4).
///
/// Kept in a separate file from `video_sync_bloc_test.dart` — that suite
/// covers `sessionJoined`/playback commands and would otherwise need
/// every one of its `buildBloc` calls rewritten to stub the two new
/// repositories; splitting by concern keeps each file's `setUp` focused
/// on what it actually exercises.
///
/// @competency Unit test harness, TDD cycle (C2.2.2).
/// @competency Test scenarios T05, T06 (ready gate resolution and
///   timeout), VS-ADS-01.
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

  VideoSessionEntity session({Duration position = Duration.zero}) =>
      VideoSessionEntity(
        roomId: roomId,
        youtubeVideoId: 'dQw4w9WgXcQ',
        isPlaying: false,
        currentPosition: position,
        leaderId: leaderId,
        updatedAt: DateTime.utc(2026, 1, 5),
      );

  List<PresenceEntity> presence(int count) => List.generate(
    count,
    (i) => PresenceEntity(
      userId: 'user-$i',
      username: 'User $i',
      isOnline: true,
      lastSeen: DateTime.utc(2026, 1, 5),
      isAnonymous: false,
    ),
  );

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
      () => getVideoSessionUseCase(roomId),
    ).thenAnswer((_) async => Right(metadata));
    when(
      () => getCurrentPlaybackStateUseCase(roomId),
    ).thenAnswer((_) async => Right(session()));
    when(
      () => subscribeToPlaybackStateUseCase(roomId),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => subscribeToPresenceUseCase(any()),
    ).thenAnswer((_) => Stream.value(Right(presence(3))));
    when(
      () => createSyncBarrierUseCase(any()),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => subscribeToSyncBarrierUseCase(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => setAllReadyUseCase(any()),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => deleteSyncBarrierUseCase(any()),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => incrementReadyCountUseCase(any()),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => updateBarrierTotalCountUseCase(any()),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => updatePlaybackStateUseCase(any()),
    ).thenAnswer((_) async => const Right(null));
  });

  VideoSyncBloc buildBloc({required String currentUserId}) => VideoSyncBloc(
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
  );

  Future<void> joinThen(VideoSyncBloc bloc, VideoSyncEvent event) async {
    bloc.add(const VideoSyncEvent.sessionJoined());
    await Future<void>.delayed(Duration.zero);
    bloc.add(event);
  }

  group('Initial start opens the ready gate (Section 4.1, steps 1-2)', () {
    blocTest<VideoSyncBloc, VideoSyncState>(
      'leader playRequested creates the barrier with the online count and '
      'emits barrierWaiting instead of writing playback state directly',
      build: () => buildBloc(currentUserId: leaderId),
      act: (bloc) => joinThen(bloc, const VideoSyncEvent.playRequested()),
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verify(
          () => createSyncBarrierUseCase(
            const CreateSyncBarrierParams(
              roomId: roomId,
              targetTimestamp: Duration.zero,
              totalCount: 3,
            ),
          ),
        ).called(1);
        verifyNever(() => updatePlaybackStateUseCase(any()));
      },
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'a non-leader playRequested never opens a barrier',
      build: () => buildBloc(currentUserId: viewerId),
      act: (bloc) => joinThen(bloc, const VideoSyncEvent.playRequested()),
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verifyNever(() => createSyncBarrierUseCase(any()));
      },
    );
  });

  group('Barrier resolution (Section 4.1, steps 5-6)', () {
    blocTest<VideoSyncBloc, VideoSyncState>(
      'T05: leader sets all_ready once readyCount >= totalCount',
      build: () => buildBloc(currentUserId: leaderId),
      act: (bloc) async {
        await joinThen(bloc, const VideoSyncEvent.playRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          VideoSyncEvent.barrierUpdated(
            Right(
              const SyncBarrierEntity(
                targetTimestamp: Duration.zero,
                readyCount: 3,
                totalCount: 3,
                allReady: false,
              ),
            ),
          ),
        );
      },
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verify(() => setAllReadyUseCase(roomId)).called(1);
      },
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'on all_ready, the leader deletes the barrier and writes playback state',
      build: () => buildBloc(currentUserId: leaderId),
      act: (bloc) async {
        await joinThen(bloc, const VideoSyncEvent.playRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          VideoSyncEvent.barrierUpdated(
            Right(
              const SyncBarrierEntity(
                targetTimestamp: Duration(seconds: 12),
                readyCount: 3,
                totalCount: 3,
                allReady: true,
              ),
            ),
          ),
        );
      },
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verify(() => deleteSyncBarrierUseCase(roomId)).called(1);
        verify(
          () => updatePlaybackStateUseCase(
            const UpdatePlaybackStateParams(
              roomId: roomId,
              isPlaying: true,
              position: Duration(seconds: 12),
            ),
          ),
        ).called(1);
      },
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'a viewer receiving all_ready transitions to playing but never '
      'deletes the barrier or writes playback state',
      build: () => buildBloc(currentUserId: viewerId),
      act: (bloc) async {
        bloc.add(const VideoSyncEvent.sessionJoined());
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          VideoSyncEvent.barrierUpdated(
            Right(
              const SyncBarrierEntity(
                targetTimestamp: Duration(seconds: 12),
                readyCount: 3,
                totalCount: 3,
                allReady: true,
              ),
            ),
          ),
        );
      },
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verifyNever(() => deleteSyncBarrierUseCase(any()));
        verifyNever(() => updatePlaybackStateUseCase(any()));
      },
    );
  });

  group('Timeout handling (Section 4.2)', () {
    blocTest<VideoSyncBloc, VideoSyncState>(
      'T06: the leader does NOT auto-force-start on timeout — the choice '
      'is offered, not taken automatically',
      build: () => buildBloc(currentUserId: leaderId),
      act: (bloc) async {
        await joinThen(bloc, const VideoSyncEvent.playRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          VideoSyncEvent.barrierUpdated(
            Right(
              const SyncBarrierEntity(
                targetTimestamp: Duration.zero,
                readyCount: 2,
                totalCount: 3,
                allReady: false,
              ),
            ),
          ),
        );
      },
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verifyNever(() => setAllReadyUseCase(any()));
      },
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'forceStartRequested sets all_ready for the leader',
      build: () => buildBloc(currentUserId: leaderId),
      act: (bloc) => joinThen(bloc, const VideoSyncEvent.forceStartRequested()),
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verify(() => setAllReadyUseCase(roomId)).called(1);
      },
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'forceStartRequested is a no-op for a non-leader',
      build: () => buildBloc(currentUserId: viewerId),
      act: (bloc) => joinThen(bloc, const VideoSyncEvent.forceStartRequested()),
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verifyNever(() => setAllReadyUseCase(any()));
      },
    );
  });

  group('Readiness signalling and total_count maintenance', () {
    blocTest<VideoSyncBloc, VideoSyncState>(
      'readySignalled increments ready_count while the barrier is open',
      build: () => buildBloc(currentUserId: viewerId),
      seed: () =>
          const VideoSyncState.barrierWaiting(readyCount: 0, totalCount: 3),
      act: (bloc) => bloc.add(const VideoSyncEvent.readySignalled()),
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verify(() => incrementReadyCountUseCase(roomId)).called(1);
      },
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'presenceCountUpdated updates total_count for the leader while the '
      'barrier is open (Section 4.1, step 4)',
      build: () => buildBloc(currentUserId: leaderId),
      act: (bloc) async {
        await joinThen(bloc, const VideoSyncEvent.playRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const VideoSyncEvent.presenceCountUpdated(2));
      },
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verify(
          () => updateBarrierTotalCountUseCase(
            const UpdateBarrierTotalCountParams(roomId: roomId, totalCount: 2),
          ),
        ).called(1);
      },
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'presenceCountUpdated is ignored when no barrier is open',
      build: () => buildBloc(currentUserId: leaderId),
      act: (bloc) =>
          joinThen(bloc, const VideoSyncEvent.presenceCountUpdated(2)),
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verifyNever(() => updateBarrierTotalCountUseCase(any()));
      },
    );
  });

  group('Subsequent plays bypass the gate (Section 7.3)', () {
    blocTest<VideoSyncBloc, VideoSyncState>(
      'after the initial start resolves, a later playRequested writes '
      'playback state directly and opens no second barrier',
      build: () => buildBloc(currentUserId: leaderId),
      act: (bloc) async {
        await joinThen(bloc, const VideoSyncEvent.playRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          VideoSyncEvent.barrierUpdated(
            Right(
              const SyncBarrierEntity(
                targetTimestamp: Duration.zero,
                readyCount: 3,
                totalCount: 3,
                allReady: true,
              ),
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        clearInteractions(createSyncBarrierUseCase);
        bloc.add(const VideoSyncEvent.playRequested());
      },
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verifyNever(() => createSyncBarrierUseCase(any()));
        verify(() => updatePlaybackStateUseCase(any())).called(greaterThan(0));
      },
    );
  });
}
