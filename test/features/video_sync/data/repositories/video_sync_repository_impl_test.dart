import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/video_sync/data/datasources/i_video_sync_remote_data_source.dart';
import 'package:youtogether/features/video_sync/data/models/video_session_model.dart';
import 'package:youtogether/features/video_sync/data/repositories/video_sync_repository_impl.dart';

class MockVideoSyncRemoteDataSource extends Mock
    implements IVideoSyncRemoteDataSource {}

/// Unit tests for [VideoSyncRepositoryImpl].
///
/// Mirrors `room_repository_impl_test.dart`'s exception-to-Failure
/// mapping pattern, adapted to a single exception type: every method on
/// [IVideoSyncRemoteDataSource] throws only `FirebaseException`
/// (firebase_database's own type), so this repository has exactly one
/// `catch` clause per method, always producing [FirebaseFailure].
///
/// @competency Unit test harness.
void main() {
  late MockVideoSyncRemoteDataSource remoteDataSource;
  late VideoSyncRepositoryImpl repository;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';

  final model = VideoSessionModel(
    roomId: roomId,
    youtubeVideoId: 'dQw4w9WgXcQ',
    isPlaying: true,
    currentPositionSeconds: 42.5,
    leaderId: '550e8400-e29b-41d4-a716-446655440000',
    updatedAt: DateTime.utc(2026, 1, 5),
  );

  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    remoteDataSource = MockVideoSyncRemoteDataSource();
    repository = VideoSyncRepositoryImpl(remoteDataSource: remoteDataSource);
  });

  group('VideoSyncRepositoryImpl.updatePlaybackState', () {
    test('should return Right(null) on success', () async {
      when(
        () => remoteDataSource.updatePlaybackState(
          roomId: any(named: 'roomId'),
          isPlaying: any(named: 'isPlaying'),
          position: any(named: 'position'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.updatePlaybackState(
        roomId: roomId,
        isPlaying: true,
        position: const Duration(seconds: 42),
      );

      expect(result.isRight, isTrue);
    });

    test('should map a FirebaseException to Left(FirebaseFailure)', () async {
      when(
        () => remoteDataSource.updatePlaybackState(
          roomId: any(named: 'roomId'),
          isPlaying: any(named: 'isPlaying'),
          position: any(named: 'position'),
        ),
      ).thenThrow(
        FirebaseException(
          plugin: 'firebase_database',
          message: 'Permission denied',
        ),
      );

      final result = await repository.updatePlaybackState(
        roomId: roomId,
        isPlaying: true,
        position: const Duration(seconds: 42),
      );

      expect(result.isLeft, isTrue);
      expect(result.left, isA<FirebaseFailure>());
      expect((result.left as FirebaseFailure).message, 'Permission denied');
    });
  });

  group('VideoSyncRepositoryImpl.getCurrentPlaybackState', () {
    test('should return Right(VideoSessionEntity) on success', () async {
      when(
        () => remoteDataSource.getCurrentPlaybackState(
          roomId: any(named: 'roomId'),
        ),
      ).thenAnswer((_) async => model);

      final result = await repository.getCurrentPlaybackState(roomId: roomId);

      expect(result.isRight, isTrue);
      expect(result.right.roomId, roomId);
    });

    test('should map a FirebaseException to Left(FirebaseFailure)', () async {
      when(
        () => remoteDataSource.getCurrentPlaybackState(
          roomId: any(named: 'roomId'),
        ),
      ).thenThrow(
        FirebaseException(plugin: 'firebase_database', message: 'not-found'),
      );

      final result = await repository.getCurrentPlaybackState(roomId: roomId);

      expect(result.isLeft, isTrue);
      expect(result.left, isA<FirebaseFailure>());
    });
  });

  group('VideoSyncRepositoryImpl.subscribeToPlaybackState', () {
    test('should map each stream value to Right(VideoSessionEntity)', () async {
      when(
        () => remoteDataSource.subscribeToPlaybackState(
          roomId: any(named: 'roomId'),
        ),
      ).thenAnswer((_) => Stream.value(model));

      final result = await repository
          .subscribeToPlaybackState(roomId: roomId)
          .first;

      expect(result.isRight, isTrue);
      expect(result.right.roomId, roomId);
    });

    test(
      'should map a stream error to a Left(FirebaseFailure) event, not a stream error',
      () async {
        when(
          () => remoteDataSource.subscribeToPlaybackState(
            roomId: any(named: 'roomId'),
          ),
        ).thenAnswer(
          (_) => Stream.error(
            FirebaseException(
              plugin: 'firebase_database',
              message: 'disconnected',
            ),
          ),
        );

        final result = await repository
            .subscribeToPlaybackState(roomId: roomId)
            .first;

        expect(result.isLeft, isTrue);
        expect(result.left, isA<FirebaseFailure>());
      },
    );
  });
}
