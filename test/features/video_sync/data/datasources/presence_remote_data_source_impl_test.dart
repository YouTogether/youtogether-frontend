import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/features/video_sync/data/datasources/presence_remote_data_source_impl.dart';

class MockFirebaseDatabase extends Mock implements FirebaseDatabase {}

class MockDatabaseReference extends Mock implements DatabaseReference {}

class MockOnDisconnect extends Mock implements OnDisconnect {}

class MockDatabaseEvent extends Mock implements DatabaseEvent {}

class MockDataSnapshot extends Mock implements DataSnapshot {}

/// Unit tests for [PresenceRemoteDataSourceImpl].
///
/// Mirrors `video_sync_remote_data_source_impl_test.dart`'s mocktail
/// strategy for `FirebaseDatabase`/`DatabaseReference`, plus a mocked
/// `OnDisconnect` for the `setPresence`/`removePresence` handler
/// lifecycle specific to presence tracking.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios: data-layer slice.
void main() {
  late MockFirebaseDatabase database;
  late MockDatabaseReference presenceRef;
  late MockDatabaseReference roomPresenceRef;
  late MockOnDisconnect onDisconnect;
  late PresenceRemoteDataSourceImpl dataSource;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';
  const userId = '550e8400-e29b-41d4-a716-446655440000';

  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    database = MockFirebaseDatabase();
    presenceRef = MockDatabaseReference();
    roomPresenceRef = MockDatabaseReference();
    onDisconnect = MockOnDisconnect();

    when(
      () => database.ref('rooms/$roomId/presence/$userId'),
    ).thenReturn(presenceRef);
    when(
      () => database.ref('rooms/$roomId/presence'),
    ).thenReturn(roomPresenceRef);
    when(() => presenceRef.onDisconnect()).thenReturn(onDisconnect);

    dataSource = PresenceRemoteDataSourceImpl(database: database);
  });

  group('setPresence', () {
    test('should register the onDisconnect handler before writing the '
        'presence node', () async {
      final callOrder = <String>[];
      when(() => onDisconnect.update(any())).thenAnswer((_) async {
        callOrder.add('onDisconnect.update');
      });
      when(() => presenceRef.set(any())).thenAnswer((_) async {
        callOrder.add('set');
      });

      await dataSource.setPresence(
        roomId: roomId,
        userId: userId,
        username: 'Alice',
      );

      expect(callOrder, ['onDisconnect.update', 'set']);
    });

    test(
      'should register an onDisconnect handler that sets is_online: false',
      () async {
        when(() => onDisconnect.update(any())).thenAnswer((_) async {});
        when(() => presenceRef.set(any())).thenAnswer((_) async {});

        await dataSource.setPresence(
          roomId: roomId,
          userId: userId,
          username: 'Alice',
        );

        final captured =
            verify(() => onDisconnect.update(captureAny())).captured.single
                as Map<String, Object?>;
        expect(captured['is_online'], false);
      },
    );

    test(
      'should write the presence node with is_online: true and the username',
      () async {
        when(() => onDisconnect.update(any())).thenAnswer((_) async {});
        when(() => presenceRef.set(any())).thenAnswer((_) async {});

        await dataSource.setPresence(
          roomId: roomId,
          userId: userId,
          username: 'Alice',
        );

        final captured =
            verify(() => presenceRef.set(captureAny())).captured.single
                as Map<String, Object?>;
        expect(captured['username'], 'Alice');
        expect(captured['is_online'], true);
      },
    );

    test('should propagate a FirebaseException thrown while writing', () async {
      when(() => onDisconnect.update(any())).thenAnswer((_) async {});
      when(() => presenceRef.set(any())).thenThrow(
        FirebaseException(plugin: 'firebase_database', message: 'denied'),
      );

      expect(
        () => dataSource.setPresence(
          roomId: roomId,
          userId: userId,
          username: 'Alice',
        ),
        throwsA(isA<FirebaseException>()),
      );
    });
  });

  group('removePresence', () {
    test(
      'should cancel the pending onDisconnect handler before removing the node',
      () async {
        final callOrder = <String>[];
        when(() => onDisconnect.cancel()).thenAnswer((_) async {
          callOrder.add('onDisconnect.cancel');
        });
        when(() => presenceRef.remove()).thenAnswer((_) async {
          callOrder.add('remove');
        });

        await dataSource.removePresence(roomId: roomId, userId: userId);

        expect(callOrder, ['onDisconnect.cancel', 'remove']);
      },
    );
  });

  group('subscribeToPresence', () {
    test(
      'should map every child of the presence node to a PresenceModel',
      () async {
        final event = MockDatabaseEvent();
        final snapshot = MockDataSnapshot();
        when(() => snapshot.value).thenReturn({
          userId: {
            'username': 'Alice',
            'is_online': true,
            'last_seen': 1767571200000,
          },
          'other-user-id': {
            'username': 'Bob',
            'is_online': true,
            'last_seen': 1767571200000,
          },
        });
        when(() => event.snapshot).thenReturn(snapshot);
        when(
          () => roomPresenceRef.onValue,
        ).thenAnswer((_) => Stream.value(event));

        final result = await dataSource
            .subscribeToPresence(roomId: roomId)
            .first;

        expect(result, hasLength(2));
        expect(
          result.map((p) => p.userId),
          containsAll([userId, 'other-user-id']),
        );
      },
    );

    test(
      'should emit an empty list when the presence node has no children',
      () async {
        final event = MockDatabaseEvent();
        final snapshot = MockDataSnapshot();
        when(() => snapshot.value).thenReturn(null);
        when(() => event.snapshot).thenReturn(snapshot);
        when(
          () => roomPresenceRef.onValue,
        ).thenAnswer((_) => Stream.value(event));

        final result = await dataSource
            .subscribeToPresence(roomId: roomId)
            .first;

        expect(result, isEmpty);
      },
    );
  });
}
