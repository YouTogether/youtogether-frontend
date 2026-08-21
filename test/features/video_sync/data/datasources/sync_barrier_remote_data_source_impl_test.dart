import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/features/video_sync/data/datasources/sync_barrier_remote_data_source_impl.dart';

class MockFirebaseDatabase extends Mock implements FirebaseDatabase {}

class MockDatabaseReference extends Mock implements DatabaseReference {}

class MockDatabaseEvent extends Mock implements DatabaseEvent {}

class MockDataSnapshot extends Mock implements DataSnapshot {}

class MockTransactionResult extends Mock implements TransactionResult {}

/// Unit tests for [SyncBarrierRemoteDataSourceImpl].
///
/// Mirrors the mocktail strategy already used for
/// `video_sync_remote_data_source_impl_test.dart` and
/// `presence_remote_data_source_impl_test.dart`.
///
/// NOTE: `runTransaction`'s exact signature (per this file's own doc
/// comment) could not be verified against a live `firebase_database`
/// fetch in this offline environment. This suite verifies that
/// `incrementReadyCount` calls `runTransaction` on the `ready_count`
/// child reference and awaits it — not the literal shape of the
/// transaction handler argument, which should be re-checked against the
/// pinned package version.
///
/// @competency Unit test harness, TDD cycle.
void main() {
  late MockFirebaseDatabase database;
  late MockDatabaseReference barrierRef;
  late MockDatabaseReference readyCountRef;
  late SyncBarrierRemoteDataSourceImpl dataSource;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';

  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    database = MockFirebaseDatabase();
    barrierRef = MockDatabaseReference();
    readyCountRef = MockDatabaseReference();

    when(
      () => database.ref('rooms/$roomId/sync_barrier'),
    ).thenReturn(barrierRef);
    when(() => barrierRef.child('ready_count')).thenReturn(readyCountRef);

    dataSource = SyncBarrierRemoteDataSourceImpl(database: database);
  });

  test(
    'createBarrier should set the full node with the given targetTimestamp and totalCount',
    () async {
      when(() => barrierRef.set(any())).thenAnswer((_) async {});

      await dataSource.createBarrier(
        roomId: roomId,
        targetTimestamp: const Duration(seconds: 42),
        totalCount: 3,
      );

      final captured =
          verify(() => barrierRef.set(captureAny())).captured.single
              as Map<String, Object?>;
      expect(captured['target_timestamp'], 42.0);
      expect(captured['total_count'], 3);
      expect(captured['ready_count'], 0);
      expect(captured['all_ready'], false);
    },
  );

  test(
    'incrementReadyCount should run a transaction on the ready_count child',
    () async {
      when(
        () => readyCountRef.runTransaction(any()),
      ).thenAnswer((_) async => MockTransactionResult());

      await dataSource.incrementReadyCount(roomId: roomId);

      verify(() => readyCountRef.runTransaction(any())).called(1);
    },
  );

  test(
    'setAllReady should update all_ready to true on the barrier node',
    () async {
      when(() => barrierRef.update(any())).thenAnswer((_) async {});

      await dataSource.setAllReady(roomId: roomId);

      verify(() => barrierRef.update({'all_ready': true})).called(1);
    },
  );

  test('deleteBarrier should remove the barrier node', () async {
    when(() => barrierRef.remove()).thenAnswer((_) async {});

    await dataSource.deleteBarrier(roomId: roomId);

    verify(() => barrierRef.remove()).called(1);
  });

  test(
    'subscribeToBarrier should map onValue events to SyncBarrierModel',
    () async {
      final event = MockDatabaseEvent();
      final snapshot = MockDataSnapshot();
      when(() => snapshot.value).thenReturn({
        'target_timestamp': 42.0,
        'ready_count': 2,
        'total_count': 3,
        'all_ready': false,
      });
      when(() => snapshot.exists).thenReturn(true);
      when(() => event.snapshot).thenReturn(snapshot);
      when(() => barrierRef.onValue).thenAnswer((_) => Stream.value(event));

      final model = await dataSource.subscribeToBarrier(roomId: roomId).first;

      expect(model.readyCount, 2);
      expect(model.totalCount, 3);
      expect(model.allReady, isFalse);
    },
  );
}
