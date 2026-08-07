import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/video_sync/domain/repositories/i_video_sync_repository.dart';
import 'package:youtogether/features/video_sync/domain/usecases/update_playback_state_params.dart';
import 'package:youtogether/features/video_sync/domain/usecases/update_playback_state_usecase.dart';

class MockIVideoSyncRepository extends Mock implements IVideoSyncRepository {}

/// Unit tests for [UpdatePlaybackStateUseCase].
///
/// The use case is a thin orchestrator; these tests verify delegation
/// to [IVideoSyncRepository.updatePlaybackState], mirroring
/// `update_room_usecase_test.dart`.
///
/// @competency Unit test harness, TDD cycle.
void main() {
  late MockIVideoSyncRepository videoSyncRepository;
  late UpdatePlaybackStateUseCase updatePlaybackStateUseCase;

  final validParams = UpdatePlaybackStateParams(
    roomId: '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f',
    isPlaying: true,
    position: const Duration(seconds: 30),
  );

  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    videoSyncRepository = MockIVideoSyncRepository();
    updatePlaybackStateUseCase = UpdatePlaybackStateUseCase(
      videoSyncRepository,
    );
  });

  group('UpdatePlaybackStateUseCase', () {
    test('should delegate to IVideoSyncRepository.updatePlaybackState with the '
        'unpacked params', () async {
      when(
        () => videoSyncRepository.updatePlaybackState(
          roomId: any(named: 'roomId'),
          isPlaying: any(named: 'isPlaying'),
          position: any(named: 'position'),
        ),
      ).thenAnswer((_) async => const Right(null));

      await updatePlaybackStateUseCase(validParams);

      verify(
        () => videoSyncRepository.updatePlaybackState(
          roomId: validParams.roomId,
          isPlaying: true,
          position: const Duration(seconds: 30),
        ),
      ).called(1);
    });

    test('should return Right(null) on success', () async {
      when(
        () => videoSyncRepository.updatePlaybackState(
          roomId: any(named: 'roomId'),
          isPlaying: any(named: 'isPlaying'),
          position: any(named: 'position'),
        ),
      ).thenAnswer((_) async => const Right(null));

      final result = await updatePlaybackStateUseCase(validParams);

      expect(result.isRight, isTrue);
    });

    test(
      'should propagate Left(FirebaseFailure) unchanged on repository failure',
      () async {
        when(
          () => videoSyncRepository.updatePlaybackState(
            roomId: any(named: 'roomId'),
            isPlaying: any(named: 'isPlaying'),
            position: any(named: 'position'),
          ),
        ).thenAnswer(
          (_) async => const Left(Failure.firebase(message: 'disconnected')),
        );

        final result = await updatePlaybackStateUseCase(validParams);

        expect(result.isLeft, isTrue);
        expect(result.left, isA<FirebaseFailure>());
      },
    );
  });
}
