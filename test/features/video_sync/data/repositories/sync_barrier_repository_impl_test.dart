import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/video_sync/data/datasources/i_sync_barrier_remote_data_source.dart';
import 'package:youtogether/features/video_sync/data/models/sync_barrier_model.dart';
import 'package:youtogether/features/video_sync/data/repositories/sync_barrier_repository_impl.dart';

class MockSyncBarrierRemoteDataSource extends Mock
    implements ISyncBarrierRemoteDataSource {}

/// Unit tests for [SyncBarrierRepositoryImpl].
///
/// Mirrors `video_sync_repository_impl_test.dart`/
/// `presence_repository_impl_test.dart`'s exception-to-Failure mapping
/// and stream-error-becomes-Left-event conventions.
///
/// @competency Unit test harness (C2.2.2).
void main() {
  late MockSyncBarrierRemoteDataSource remoteDataSource;
  late SyncBarrierRepositoryImpl repository;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';

  final model = SyncBarrierModel(
    targetTimestampSeconds: 42.0,
    readyCount: 1,
    totalCount: 3,
    allReady: false,
  );

  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    remoteDataSource = MockSyncBarrierRemoteDataSource();
    repository = SyncBarrierRepositoryImpl(remoteDataSource: remoteDataSource);
  });

  test('createBarrier should return Right(null) on success', () async {
    when(
      () => remoteDataSource.createBarrier(
        roomId: any(named: 'roomId'),
        targetTimestamp: any(named: 'targetTimestamp'),
        totalCount: any(named: 'totalCount'),
      ),
    ).thenAnswer((_) async {});

    final result = await repository.createBarrier(
      roomId: roomId,
      targetTimestamp: const Duration(seconds: 42),
      totalCount: 3,
    );

    expect(result.isRight, isTrue);
  });

  test(
    'incrementReadyCount should map a FirebaseException to Left(FirebaseFailure)',
    () async {
      when(
        () =>
            remoteDataSource.incrementReadyCount(roomId: any(named: 'roomId')),
      ).thenThrow(
        FirebaseException(plugin: 'firebase_database', message: 'denied'),
      );

      final result = await repository.incrementReadyCount(roomId: roomId);

      expect(result.isLeft, isTrue);
      expect(result.left, isA<FirebaseFailure>());
    },
  );

  test(
    'subscribeToBarrier should map each stream value to Right(SyncBarrierEntity)',
    () async {
      when(
        () => remoteDataSource.subscribeToBarrier(roomId: any(named: 'roomId')),
      ).thenAnswer((_) => Stream.value(model));

      final result = await repository.subscribeToBarrier(roomId: roomId).first;

      expect(result.isRight, isTrue);
      expect(result.right.readyCount, 1);
      expect(result.right.totalCount, 3);
    },
  );

  test(
    'subscribeToBarrier should map a stream error to a Left(FirebaseFailure) event',
    () async {
      when(
        () => remoteDataSource.subscribeToBarrier(roomId: any(named: 'roomId')),
      ).thenAnswer(
        (_) => Stream.error(
          FirebaseException(
            plugin: 'firebase_database',
            message: 'disconnected',
          ),
        ),
      );

      final result = await repository.subscribeToBarrier(roomId: roomId).first;

      expect(result.isLeft, isTrue);
      expect(result.left, isA<FirebaseFailure>());
    },
  );
}
