import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/video_sync/domain/entities/video_session_entity.dart';
import 'package:youtogether/features/video_sync/domain/repositories/i_video_sync_repository.dart';
import 'package:youtogether/features/video_sync/domain/usecases/get_current_playback_state_usecase.dart';

class MockIVideoSyncRepository extends Mock implements IVideoSyncRepository {}

/// Unit tests for [GetCurrentPlaybackStateUseCase].
///
/// The use case is a thin orchestrator; these tests verify delegation
/// to [IVideoSyncRepository.getCurrentPlaybackState], mirroring
/// `get_room_by_id_usecase_test.dart` — the room id is passed directly,
/// no dedicated Params wrapper.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenario: new viewer synchronises on entry.
void main() {
  late MockIVideoSyncRepository videoSyncRepository;
  late GetCurrentPlaybackStateUseCase getCurrentPlaybackStateUseCase;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';

  final session = VideoSessionEntity(
    roomId: roomId,
    youtubeVideoId: 'dQw4w9WgXcQ',
    isPlaying: true,
    currentPosition: const Duration(seconds: 45),
    leaderId: '550e8400-e29b-41d4-a716-446655440000',
    updatedAt: DateTime.utc(2026, 1, 5),
  );

  setUp(() {
    videoSyncRepository = MockIVideoSyncRepository();
    getCurrentPlaybackStateUseCase = GetCurrentPlaybackStateUseCase(
      videoSyncRepository,
    );
  });

  group('GetCurrentPlaybackStateUseCase', () {
    test('should delegate to IVideoSyncRepository.getCurrentPlaybackState with '
        'the room id', () async {
      when(
        () => videoSyncRepository.getCurrentPlaybackState(
          roomId: any(named: 'roomId'),
        ),
      ).thenAnswer((_) async => Right(session));

      await getCurrentPlaybackStateUseCase(roomId);

      verify(
        () => videoSyncRepository.getCurrentPlaybackState(roomId: roomId),
      ).called(1);
    });

    test(
      'should return Right(VideoSessionEntity) on success (VS-SYN-01)',
      () async {
        when(
          () => videoSyncRepository.getCurrentPlaybackState(
            roomId: any(named: 'roomId'),
          ),
        ).thenAnswer((_) async => Right(session));

        final result = await getCurrentPlaybackStateUseCase(roomId);

        expect(result.isRight, isTrue);
        expect(result.right, session);
      },
    );

    test(
      'should propagate Left(FirebaseFailure) unchanged on repository failure',
      () async {
        when(
          () => videoSyncRepository.getCurrentPlaybackState(
            roomId: any(named: 'roomId'),
          ),
        ).thenAnswer(
          (_) async => const Left(Failure.firebase(message: 'read failed')),
        );

        final result = await getCurrentPlaybackStateUseCase(roomId);

        expect(result.isLeft, isTrue);
        expect(result.left, isA<FirebaseFailure>());
      },
    );
  });
}
