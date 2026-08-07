import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/video_sync/domain/entities/video_session_entity.dart';
import 'package:youtogether/features/video_sync/domain/repositories/i_video_sync_repository.dart';
import 'package:youtogether/features/video_sync/domain/usecases/subscribe_to_playback_state_usecase.dart';

class MockIVideoSyncRepository extends Mock implements IVideoSyncRepository {}

/// Unit tests for [SubscribeToPlaybackStateUseCase].
///
/// The use case is a thin orchestrator over a `Stream`, mirroring
/// [UpdatePlaybackStateUseCase] in spirit but returning
/// `Stream<Either<Failure, VideoSessionEntity>>` per [StreamUseCase].
///
/// @competency Unit test harness, TDD cycle.
void main() {
  late MockIVideoSyncRepository videoSyncRepository;
  late SubscribeToPlaybackStateUseCase subscribeToPlaybackStateUseCase;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';

  final session = VideoSessionEntity(
    roomId: roomId,
    youtubeVideoId: 'dQw4w9WgXcQ',
    isPlaying: true,
    currentPosition: const Duration(seconds: 30),
    leaderId: '550e8400-e29b-41d4-a716-446655440000',
    updatedAt: DateTime.utc(2026, 1, 5),
  );

  setUp(() {
    videoSyncRepository = MockIVideoSyncRepository();
    subscribeToPlaybackStateUseCase = SubscribeToPlaybackStateUseCase(
      videoSyncRepository,
    );
  });

  group('SubscribeToPlaybackStateUseCase', () {
    test(
      'should delegate to IVideoSyncRepository.subscribeToPlaybackState with '
      'the room id',
      () {
        when(
          () => videoSyncRepository.subscribeToPlaybackState(
            roomId: any(named: 'roomId'),
          ),
        ).thenAnswer((_) => Stream.value(Right(session)));

        subscribeToPlaybackStateUseCase(roomId);

        verify(
          () => videoSyncRepository.subscribeToPlaybackState(roomId: roomId),
        ).called(1);
      },
    );

    test(
      'should forward every emitted Right(VideoSessionEntity) unchanged',
      () async {
        when(
          () => videoSyncRepository.subscribeToPlaybackState(
            roomId: any(named: 'roomId'),
          ),
        ).thenAnswer((_) => Stream.value(Right(session)));

        final results = await subscribeToPlaybackStateUseCase(roomId).toList();

        expect(results, [Right<Failure, VideoSessionEntity>(session)]);
      },
    );

    test('should forward a Left(FirebaseFailure) event emitted mid-stream '
        '(VS-SYN-06)', () async {
      when(
        () => videoSyncRepository.subscribeToPlaybackState(
          roomId: any(named: 'roomId'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          Right(session),
          const Left(Failure.firebase(message: 'connection lost')),
        ]),
      );

      final results = await subscribeToPlaybackStateUseCase(roomId).toList();

      expect(results.last.isLeft, isTrue);
      expect(results.last.left, isA<FirebaseFailure>());
    });
  });
}
