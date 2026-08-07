import 'package:firebase_database/firebase_database.dart';

import '../models/presence_model.dart';
import 'i_presence_remote_data_source.dart';

/// Concrete [IPresenceRemoteDataSource] backed by Firebase Realtime
/// Database.
///
/// `FirebaseDatabase` is injected via the constructor, mirroring
/// `VideoSyncRemoteDataSourceImpl`, so tests can supply a mocktail
/// double instead of a real Firebase connection.
class PresenceRemoteDataSourceImpl implements IPresenceRemoteDataSource {
  PresenceRemoteDataSourceImpl({required FirebaseDatabase database})
    : _database = database;

  final FirebaseDatabase _database;

  DatabaseReference _presenceRef(String roomId, String userId) {
    return _database.ref('rooms/$roomId/presence/$userId');
  }

  DatabaseReference _roomPresenceRef(String roomId) {
    return _database.ref('rooms/$roomId/presence');
  }

  @override
  Future<void> setPresence({
    required String roomId,
    required String userId,
    required String username,
  }) async {
    final ref = _presenceRef(roomId, userId);

    // Registered BEFORE the node is written, deliberately: if the
    // client disconnects in the narrow window between these two calls,
    // there is otherwise no handler yet in place to clear presence —
    // the node would stay `is_online: true` forever. Registering first
    // means the worst case is the handler existing very briefly before
    // there is even a node for it to act on, which is harmless.
    await ref.onDisconnect().update(<String, Object?>{
      'is_online': false,
      'last_seen': ServerValue.timestamp,
    });

    await ref.set(
      PresenceModel(
        userId: userId,
        username: username,
        isOnline: true,
        lastSeen: DateTime.now().toUtc(),
      ).toJson(),
    );
  }

  @override
  Future<void> removePresence({
    required String roomId,
    required String userId,
  }) async {
    final ref = _presenceRef(roomId, userId);

    // Cancelled BEFORE the node is removed: otherwise a disconnect
    // racing this graceful exit could fire the onDisconnect handler
    // after .remove() completes, briefly resurrecting an
    // `is_online: false` node that this method already deleted.
    await ref.onDisconnect().cancel();
    await ref.remove();
  }

  @override
  Stream<List<PresenceModel>> subscribeToPresence({required String roomId}) {
    return _roomPresenceRef(roomId).onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null) {
        return const <PresenceModel>[];
      }

      final children = value as Map<Object?, Object?>;
      return children.entries.map((entry) {
        return PresenceModel.fromSnapshot(
          userId: entry.key as String,
          json: entry.value as Map<Object?, Object?>,
        );
      }).toList();
    });
  }
}
