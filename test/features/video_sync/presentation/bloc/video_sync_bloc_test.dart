import 'package:bloc_test/bloc_test.dart';
import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/video_sync/domain/usecases/update_playback_state_params.dart';
import 'package:youtogether/features/video_sync/domain/usecases/update_playback_state_usecase.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_bloc.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_event.dart';
import 'package:youtogether/features/video_sync/presentation/bloc/video_sync_state.dart';

class MockUpdatePlaybackStateUseCase extends Mock
    implements UpdatePlaybackStateUseCase {}

/// Unit tests for [VideoSyncBloc]'s command handlers
/// (`playRequested`, `pauseRequested`, `seekRequested`).
///
/// Uses `bloc_test`'s `blocTest`, mirroring `room_bloc_test.dart`.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios VS-SYN-02 through.
void main() {
  late MockUpdatePlaybackStateUseCase updatePlaybackStateUseCase;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';
  const durationSeconds = 213;

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
    updatePlaybackStateUseCase = MockUpdatePlaybackStateUseCase();
  });

  VideoSyncBloc buildBloc({
    required bool isLeader,
    Duration initialPosition = Duration.zero,
    bool initialIsPlaying = false,
  }) {
    return VideoSyncBloc(
      roomId: roomId,
      isLeader: isLeader,
      durationSeconds: durationSeconds,
      updatePlaybackStateUseCase: updatePlaybackStateUseCase,
      initialPosition: initialPosition,
      initialIsPlaying: initialIsPlaying,
    );
  }

  group('VideoSyncEvent.playRequested (leader) — VS-SYN-02', () {
    blocTest<VideoSyncBloc, VideoSyncState>(
      'writes isPlaying: true at the current position via '
      'UpdatePlaybackStateUseCase and emits VideoSyncState.playing on success',
      build: () {
        when(
          () => updatePlaybackStateUseCase(any()),
        ).thenAnswer((_) async => const Right(null));
        return buildBloc(
          isLeader: true,
          initialPosition: const Duration(seconds: 42),
        );
      },
      act: (bloc) => bloc.add(const VideoSyncEvent.playRequested()),
      expect: () => [
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

    blocTest<VideoSyncBloc, VideoSyncState>(
      'emits VideoSyncState.failure when the use case fails',
      build: () {
        when(() => updatePlaybackStateUseCase(any())).thenAnswer(
          (_) async => const Left(Failure.firebase(message: 'denied')),
        );
        return buildBloc(isLeader: true);
      },
      act: (bloc) => bloc.add(const VideoSyncEvent.playRequested()),
      expect: () => [
        const VideoSyncState.failure(Failure.firebase(message: 'denied')),
      ],
    );
  });

  group('VideoSyncEvent.pauseRequested (leader) — VS-SYN-03', () {
    blocTest<VideoSyncBloc, VideoSyncState>(
      'writes isPlaying: false at the current position and emits '
      'VideoSyncState.paused on success',
      build: () {
        when(
          () => updatePlaybackStateUseCase(any()),
        ).thenAnswer((_) async => const Right(null));
        return buildBloc(
          isLeader: true,
          initialPosition: const Duration(seconds: 90),
          initialIsPlaying: true,
        );
      },
      act: (bloc) => bloc.add(const VideoSyncEvent.pauseRequested()),
      expect: () => [
        const VideoSyncState.paused(position: Duration(seconds: 90)),
      ],
      verify: (_) {
        verify(
          () => updatePlaybackStateUseCase(
            const UpdatePlaybackStateParams(
              roomId: roomId,
              isPlaying: false,
              position: Duration(seconds: 90),
            ),
          ),
        ).called(1);
      },
    );
  });

  group('VideoSyncEvent.seekRequested (leader) — VS-SYN-04', () {
    blocTest<VideoSyncBloc, VideoSyncState>(
      'writes the new position, preserving the current isPlaying flag, '
      'for a target within [0, duration]',
      build: () {
        when(
          () => updatePlaybackStateUseCase(any()),
        ).thenAnswer((_) async => const Right(null));
        return buildBloc(isLeader: true, initialIsPlaying: true);
      },
      act: (bloc) =>
          bloc.add(const VideoSyncEvent.seekRequested(Duration(seconds: 100))),
      expect: () => [
        const VideoSyncState.playing(position: Duration(seconds: 100)),
      ],
      verify: (_) {
        verify(
          () => updatePlaybackStateUseCase(
            const UpdatePlaybackStateParams(
              roomId: roomId,
              isPlaying: true,
              position: Duration(seconds: 100),
            ),
          ),
        ).called(1);
      },
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'rejects a target beyond the video duration with no state change '
      'and no Firebase write attempted',
      build: () {
        when(
          () => updatePlaybackStateUseCase(any()),
        ).thenAnswer((_) async => const Right(null));
        return buildBloc(isLeader: true);
      },
      act: (bloc) => bloc.add(
        const VideoSyncEvent.seekRequested(
          Duration(seconds: durationSeconds + 1),
        ),
      ),
      expect: () => <VideoSyncState>[],
      verify: (_) {
        verifyNever(() => updatePlaybackStateUseCase(any()));
      },
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'rejects a negative target with no state change and no Firebase '
      'write attempted',
      build: () {
        when(
          () => updatePlaybackStateUseCase(any()),
        ).thenAnswer((_) async => const Right(null));
        return buildBloc(isLeader: true);
      },
      act: (bloc) =>
          bloc.add(const VideoSyncEvent.seekRequested(Duration(seconds: -1))),
      expect: () => <VideoSyncState>[],
      verify: (_) {
        verifyNever(() => updatePlaybackStateUseCase(any()));
      },
    );
  });

  group('Leader-only gating — VS-SYN-05', () {
    blocTest<VideoSyncBloc, VideoSyncState>(
      'playRequested is a no-op for a non-leader',
      build: () => buildBloc(isLeader: false),
      act: (bloc) => bloc.add(const VideoSyncEvent.playRequested()),
      expect: () => <VideoSyncState>[],
      verify: (_) => verifyNever(() => updatePlaybackStateUseCase(any())),
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'pauseRequested is a no-op for a non-leader',
      build: () => buildBloc(isLeader: false, initialIsPlaying: true),
      act: (bloc) => bloc.add(const VideoSyncEvent.pauseRequested()),
      expect: () => <VideoSyncState>[],
      verify: (_) => verifyNever(() => updatePlaybackStateUseCase(any())),
    );

    blocTest<VideoSyncBloc, VideoSyncState>(
      'seekRequested is a no-op for a non-leader, even for an otherwise '
      'valid target',
      build: () => buildBloc(isLeader: false),
      act: (bloc) =>
          bloc.add(const VideoSyncEvent.seekRequested(Duration(seconds: 50))),
      expect: () => <VideoSyncState>[],
      verify: (_) => verifyNever(() => updatePlaybackStateUseCase(any())),
    );
  });
}
