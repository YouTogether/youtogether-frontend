import 'package:bloc_test/bloc_test.dart';
import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/features/video_sync/domain/entities/presence_entity.dart';
import 'package:youtogether/features/video_sync/domain/entities/sync_barrier_entity.dart';
import 'package:youtogether/features/video_sync/domain/entities/video_session_entity.dart';
import 'package:youtogether/features/video_sync/domain/entities/video_session_metadata_entity.dart';
import 'package:youtogether/features/video_sync/domain/repositories/i_presence_repository.dart';
import 'package:youtogether/features/video_sync/domain/repositories/i_sync_barrier_repository.dart';
import 'package:youtogether/features/video_sync/domain/usecases/get_current_playback_state_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/get_video_session_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/subscribe_to_playback_state_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/update_playback_state_params.dart';
import 'package:youtogether/features/video_sync/domain/usecases/update_playback_state_usecase.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_bloc.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_event.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_state.dart';

class MockGetVideoSessionUseCase extends Mock
    implements GetVideoSessionUseCase {}

class MockGetCurrentPlaybackStateUseCase extends Mock
    implements GetCurrentPlaybackStateUseCase {}

class MockSubscribeToPlaybackStateUseCase extends Mock
    implements SubscribeToPlaybackStateUseCase {}

class MockUpdatePlaybackStateUseCase extends Mock
    implements UpdatePlaybackStateUseCase {}

class MockSyncBarrierRepository extends Mock
    implements ISyncBarrierRepository {}

class MockPresenceRepository extends Mock implements IPresenceRepository {}

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
  late MockGetVideoSessionUseCase getVideoSessionUseCase;
  late MockGetCurrentPlaybackStateUseCase getCurrentPlaybackStateUseCase;
  late MockSubscribeToPlaybackStateUseCase subscribeToPlaybackStateUseCase;
  late MockUpdatePlaybackStateUseCase updatePlaybackStateUseCase;
  late MockSyncBarrierRepository syncBarrierRepository;
  late MockPresenceRepository presenceRepository;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';
  const leaderId = '550e8400-e29b-41d4-a716-446655440000';
  const viewerId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

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
    ),
  );

  setUpAll(() {
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
    getVideoSessionUseCase = MockGetVideoSessionUseCase();
    getCurrentPlaybackStateUseCase = MockGetCurrentPlaybackStateUseCase();
    subscribeToPlaybackStateUseCase = MockSubscribeToPlaybackStateUseCase();
    updatePlaybackStateUseCase = MockUpdatePlaybackStateUseCase();
    syncBarrierRepository = MockSyncBarrierRepository();
    presenceRepository = MockPresenceRepository();

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
      () =>
          presenceRepository.subscribeToPresence(roomId: any(named: 'roomId')),
    ).thenAnswer((_) => Stream.value(Right(presence(3))));
    when(
      () => syncBarrierRepository.createBarrier(
        roomId: any(named: 'roomId'),
        targetTimestamp: any(named: 'targetTimestamp'),
        totalCount: any(named: 'totalCount'),
      ),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => syncBarrierRepository.subscribeToBarrier(
        roomId: any(named: 'roomId'),
      ),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => syncBarrierRepository.setAllReady(roomId: any(named: 'roomId')),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => syncBarrierRepository.deleteBarrier(roomId: any(named: 'roomId')),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => syncBarrierRepository.incrementReadyCount(
        roomId: any(named: 'roomId'),
      ),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => syncBarrierRepository.updateTotalCount(
        roomId: any(named: 'roomId'),
        totalCount: any(named: 'totalCount'),
      ),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => updatePlaybackStateUseCase(any()),
    ).thenAnswer((_) async => const Right(null));
  });

  VideoSyncBloc buildBloc({required String currentUserId}) => VideoSyncBloc(
    roomId: roomId,
    currentUserId: currentUserId,
    getVideoSessionUseCase: getVideoSessionUseCase,
    getCurrentPlaybackStateUseCase: getCurrentPlaybackStateUseCase,
    subscribeToPlaybackStateUseCase: subscribeToPlaybackStateUseCase,
    updatePlaybackStateUseCase: updatePlaybackStateUseCase,
    syncBarrierRepository: syncBarrierRepository,
    presenceRepository: presenceRepository,
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
          () => syncBarrierRepository.createBarrier(
            roomId: roomId,
            targetTimestamp: Duration.zero,
            totalCount: 3,
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
        verifyNever(
          () => syncBarrierRepository.createBarrier(
            roomId: any(named: 'roomId'),
            targetTimestamp: any(named: 'targetTimestamp'),
            totalCount: any(named: 'totalCount'),
          ),
        );
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
        verify(
          () => syncBarrierRepository.setAllReady(roomId: roomId),
        ).called(1);
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
        verify(
          () => syncBarrierRepository.deleteBarrier(roomId: roomId),
        ).called(1);
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
        verifyNever(
          () =>
              syncBarrierRepository.deleteBarrier(roomId: any(named: 'roomId')),
        );
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
        verifyNever(
          () => syncBarrierRepository.setAllReady(roomId: any(named: 'roomId')),
        );
      },
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'forceStartRequested sets all_ready for the leader',
      build: () => buildBloc(currentUserId: leaderId),
      act: (bloc) => joinThen(bloc, const VideoSyncEvent.forceStartRequested()),
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verify(
          () => syncBarrierRepository.setAllReady(roomId: roomId),
        ).called(1);
      },
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'forceStartRequested is a no-op for a non-leader',
      build: () => buildBloc(currentUserId: viewerId),
      act: (bloc) => joinThen(bloc, const VideoSyncEvent.forceStartRequested()),
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verifyNever(
          () => syncBarrierRepository.setAllReady(roomId: any(named: 'roomId')),
        );
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
        verify(
          () => syncBarrierRepository.incrementReadyCount(roomId: roomId),
        ).called(1);
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
          () => syncBarrierRepository.updateTotalCount(
            roomId: roomId,
            totalCount: 2,
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
        verifyNever(
          () => syncBarrierRepository.updateTotalCount(
            roomId: any(named: 'roomId'),
            totalCount: any(named: 'totalCount'),
          ),
        );
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
        clearInteractions(syncBarrierRepository);
        bloc.add(const VideoSyncEvent.playRequested());
      },
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verifyNever(
          () => syncBarrierRepository.createBarrier(
            roomId: any(named: 'roomId'),
            targetTimestamp: any(named: 'targetTimestamp'),
            totalCount: any(named: 'totalCount'),
          ),
        );
        verify(() => updatePlaybackStateUseCase(any())).called(greaterThan(0));
      },
    );
  });
}
