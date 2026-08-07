import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/video_sync/data/datasources/i_presence_remote_data_source.dart';
import 'package:youtogether/features/video_sync/data/models/presence_model.dart';
import 'package:youtogether/features/video_sync/data/repositories/presence_repository_impl.dart';

class MockPresenceRemoteDataSource extends Mock
    implements IPresenceRemoteDataSource {}

/// Unit tests for [PresenceRepositoryImpl].
///
/// Mirrors `video_sync_repository_impl_test.dart`'s exception-to-Failure
/// mapping pattern and its stream-error-becomes-Left-event convention
/// for [PresenceRepositoryImpl.subscribeToPresence].
///
/// @competency Unit test harness (C2.2.2).
void main() {
  late MockPresenceRemoteDataSource remoteDataSource;
  late PresenceRepositoryImpl repository;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';
  const userId = '550e8400-e29b-41d4-a716-446655440000';

  final model = PresenceModel(
    userId: userId,
    username: 'Alice',
    isOnline: true,
    lastSeen: DateTime.utc(2026, 1, 5),
  );

  setUp(() {
    remoteDataSource = MockPresenceRemoteDataSource();
    repository = PresenceRepositoryImpl(remoteDataSource: remoteDataSource);
  });

  group('PresenceRepositoryImpl.setPresence', () {
    test('should return Right(null) on success', () async {
      when(
        () => remoteDataSource.setPresence(
          roomId: any(named: 'roomId'),
          userId: any(named: 'userId'),
          username: any(named: 'username'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.setPresence(
        roomId: roomId,
        userId: userId,
        username: 'Alice',
      );

      expect(result.isRight, isTrue);
    });

    test('should map a FirebaseException to Left(FirebaseFailure)', () async {
      when(
        () => remoteDataSource.setPresence(
          roomId: any(named: 'roomId'),
          userId: any(named: 'userId'),
          username: any(named: 'username'),
        ),
      ).thenThrow(
        FirebaseException(plugin: 'firebase_database', message: 'denied'),
      );

      final result = await repository.setPresence(
        roomId: roomId,
        userId: userId,
        username: 'Alice',
      );

      expect(result.isLeft, isTrue);
      expect(result.left, isA<FirebaseFailure>());
    });
  });

  group('PresenceRepositoryImpl.removePresence', () {
    test('should return Right(null) on success', () async {
      when(
        () => remoteDataSource.removePresence(
          roomId: any(named: 'roomId'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.removePresence(
        roomId: roomId,
        userId: userId,
      );

      expect(result.isRight, isTrue);
    });

    test('should map a FirebaseException to Left(FirebaseFailure)', () async {
      when(
        () => remoteDataSource.removePresence(
          roomId: any(named: 'roomId'),
          userId: any(named: 'userId'),
        ),
      ).thenThrow(
        FirebaseException(plugin: 'firebase_database', message: 'denied'),
      );

      final result = await repository.removePresence(
        roomId: roomId,
        userId: userId,
      );

      expect(result.isLeft, isTrue);
      expect(result.left, isA<FirebaseFailure>());
    });
  });

  group('PresenceRepositoryImpl.subscribeToPresence', () {
    test(
      'should map each stream value to Right(List<PresenceEntity>)',
      () async {
        when(
          () => remoteDataSource.subscribeToPresence(
            roomId: any(named: 'roomId'),
          ),
        ).thenAnswer((_) => Stream.value([model]));

        final result = await repository
            .subscribeToPresence(roomId: roomId)
            .first;

        expect(result.isRight, isTrue);
        expect(result.right, hasLength(1));
        expect(result.right.first.userId, userId);
      },
    );

    test(
      'should map a stream error to a Left(FirebaseFailure) event, not a stream error',
      () async {
        when(
          () => remoteDataSource.subscribeToPresence(
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
            .subscribeToPresence(roomId: roomId)
            .first;

        expect(result.isLeft, isTrue);
        expect(result.left, isA<FirebaseFailure>());
      },
    );
  });
}
