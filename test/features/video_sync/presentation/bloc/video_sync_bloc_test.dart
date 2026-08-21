import 'package:bloc_test/bloc_test.dart';
import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/video_sync/domain/entities/video_session_entity.dart';
import 'package:youtogether/features/video_sync/domain/entities/video_session_metadata_entity.dart';
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
/// @competency Test scenarios VS-SYN-02 through.
void main() {
  late MockGetVideoSessionUseCase getVideoSessionUseCase;
  late MockGetCurrentPlaybackStateUseCase getCurrentPlaybackStateUseCase;
  late MockSubscribeToPlaybackStateUseCase subscribeToPlaybackStateUseCase;
  late MockUpdatePlaybackStateUseCase updatePlaybackStateUseCase;

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

  VideoSessionEntity buildSession({
    required bool isPlaying,
    Duration position = const Duration(seconds: 42),
  }) {
    return VideoSessionEntity(
      roomId: roomId,
      youtubeVideoId: 'dQw4w9WgXcQ',
      isPlaying: isPlaying,
      currentPosition: position,
      leaderId: leaderId,
      updatedAt: DateTime.utc(2026, 1, 5),
    );
  }

  setUpAll(() {
    registerFallbackValue(
      const UpdatePlaybackStateParams(
        roomId: roomId,
        isPlaying: false,
        position: Duration.zero,
      ),
    );
  });

  setUp(() {
    getVideoSessionUseCase = MockGetVideoSessionUseCase();
    getCurrentPlaybackStateUseCase = MockGetCurrentPlaybackStateUseCase();
    subscribeToPlaybackStateUseCase = MockSubscribeToPlaybackStateUseCase();
    updatePlaybackStateUseCase = MockUpdatePlaybackStateUseCase();
  });

  VideoSyncBloc buildBloc({required String currentUserId}) {
    return VideoSyncBloc(
      roomId: roomId,
      currentUserId: currentUserId,
      getVideoSessionUseCase: getVideoSessionUseCase,
      getCurrentPlaybackStateUseCase: getCurrentPlaybackStateUseCase,
      subscribeToPlaybackStateUseCase: subscribeToPlaybackStateUseCase,
      updatePlaybackStateUseCase: updatePlaybackStateUseCase,
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
    blocTest<VideoSyncBloc, VideoSyncState>(
      'writes isPlaying: true at the current position via '
      'UpdatePlaybackStateUseCase and emits VideoSyncState.playing on success',
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
          () => updatePlaybackStateUseCase(any()),
        ).thenAnswer((_) async => const Right(null));
        return buildBloc(currentUserId: leaderId);
      },
      act: (bloc) async {
        bloc.add(const VideoSyncEvent.sessionJoined());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const VideoSyncEvent.playRequested());
      },
      expect: () => [
        const VideoSyncState.loading(),
        const VideoSyncState.ready(
          position: Duration(seconds: 42),
          isPlaying: false,
        ),
        const VideoSyncState.playing(position: Duration(seconds: 42)),
      ],
      verify: (_) {
        verify(
          () => updatePlaybackStateUseCase(
            const UpdatePlaybackStateParams(
              roomId: roomId,
              isPlaying: true,
              position: Duration(seconds: 42),
            ),
          ),
        ).called(1);
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
}
