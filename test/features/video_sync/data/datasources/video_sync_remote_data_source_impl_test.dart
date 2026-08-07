import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/features/video_sync/data/datasources/video_sync_remote_data_source_impl.dart';

class MockFirebaseDatabase extends Mock implements FirebaseDatabase {}

class MockDatabaseReference extends Mock implements DatabaseReference {}

class MockDatabaseEvent extends Mock implements DatabaseEvent {}

class MockDataSnapshot extends Mock implements DataSnapshot {}

/// Unit tests for [VideoSyncRemoteDataSourceImpl].
///
/// `FirebaseDatabase`/`DatabaseReference`/`DatabaseEvent`/`DataSnapshot`
/// are mocked with `mocktail` rather than exercised against a real
/// Firebase project or the Firebase emulator — consistent with the
/// project's existing unit-test boundary (Dio itself is never hit for
/// `RoomRemoteDataSourceImpl` unit tests either; only its
/// `*.integration.spec.ts`-equivalent widget/integration tests would
/// exercise a real backend, and no such suite exists yet for Firebase
/// in this sprint).
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios: data-layer slice.
void main() {
  late MockFirebaseDatabase database;
  late MockDatabaseReference reference;
  late VideoSyncRemoteDataSourceImpl dataSource;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';

  Map<Object?, Object?> buildSnapshotValue() => {
    'youtube_video_id': 'dQw4w9WgXcQ',
    'is_playing': true,
    'timestamp_seconds': 42.5,
    'leader_id': '550e8400-e29b-41d4-a716-446655440000',
    'last_updated_at': 1767571200000,
  };

  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    database = MockFirebaseDatabase();
    reference = MockDatabaseReference();
    when(
      () => database.ref('rooms/$roomId/playback_state'),
    ).thenReturn(reference);
    dataSource = VideoSyncRemoteDataSourceImpl(database: database);
  });

  group('updatePlaybackState', () {
    test('should call DatabaseReference.update with only is_playing, '
        'timestamp_seconds, and last_updated_at', () async {
      when(() => reference.update(any())).thenAnswer((_) async {});

      await dataSource.updatePlaybackState(
        roomId: roomId,
        isPlaying: true,
        position: const Duration(seconds: 42, milliseconds: 500),
      );

      final captured =
          verify(() => reference.update(captureAny())).captured.single
              as Map<String, Object?>;
      expect(captured['is_playing'], true);
      expect(captured['timestamp_seconds'], 42.5);
      expect(captured.containsKey('youtube_video_id'), isFalse);
      expect(captured.containsKey('leader_id'), isFalse);
    });

    test('should propagate a FirebaseException thrown by update()', () async {
      when(() => reference.update(any())).thenThrow(
        FirebaseException(plugin: 'firebase_database', message: 'denied'),
      );

      expect(
        () => dataSource.updatePlaybackState(
          roomId: roomId,
          isPlaying: true,
          position: Duration.zero,
        ),
        throwsA(isA<FirebaseException>()),
      );
    });
  });

  group('getCurrentPlaybackState', () {
    test(
      'should perform a single read and return a parsed VideoSessionModel',
      () async {
        final event = MockDatabaseEvent();
        final snapshot = MockDataSnapshot();
        when(() => snapshot.value).thenReturn(buildSnapshotValue());
        when(() => snapshot.exists).thenReturn(true);
        when(() => event.snapshot).thenReturn(snapshot);
        when(() => reference.once()).thenAnswer((_) async => event);

        final model = await dataSource.getCurrentPlaybackState(roomId: roomId);

        expect(model.roomId, roomId);
        expect(model.youtubeVideoId, 'dQw4w9WgXcQ');
        expect(model.isPlaying, isTrue);
      },
    );

    test(
      'should throw a FirebaseException when no playback state exists',
      () async {
        final event = MockDatabaseEvent();
        final snapshot = MockDataSnapshot();
        when(() => snapshot.value).thenReturn(null);
        when(() => snapshot.exists).thenReturn(false);
        when(() => event.snapshot).thenReturn(snapshot);
        when(() => reference.once()).thenAnswer((_) async => event);

        expect(
          () => dataSource.getCurrentPlaybackState(roomId: roomId),
          throwsA(isA<FirebaseException>()),
        );
      },
    );
  });

  group('subscribeToPlaybackState', () {
    test(
      'should map DatabaseReference.onValue events to VideoSessionModel',
      () async {
        final event = MockDatabaseEvent();
        final snapshot = MockDataSnapshot();
        when(() => snapshot.value).thenReturn(buildSnapshotValue());
        when(() => snapshot.exists).thenReturn(true);
        when(() => event.snapshot).thenReturn(snapshot);
        when(() => reference.onValue).thenAnswer((_) => Stream.value(event));

        final model = await dataSource
            .subscribeToPlaybackState(roomId: roomId)
            .first;

        expect(model.roomId, roomId);
        expect(model.isPlaying, isTrue);
      },
    );

    test('should emit a stream error when a snapshot has no value', () async {
      final event = MockDatabaseEvent();
      final snapshot = MockDataSnapshot();
      when(() => snapshot.value).thenReturn(null);
      when(() => snapshot.exists).thenReturn(false);
      when(() => event.snapshot).thenReturn(snapshot);
      when(() => reference.onValue).thenAnswer((_) => Stream.value(event));

      expect(
        dataSource.subscribeToPlaybackState(roomId: roomId),
        emitsError(isA<FirebaseException>()),
      );
    });
  });
}
