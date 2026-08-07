import '../models/presence_model.dart';

/// Data source port for the Video Synchronisation bounded context's
/// presence tracking, backed by Firebase Realtime Database.
///
/// Mirrors `IVideoSyncRemoteDataSource` in structure: methods throw
/// `firebase_database`'s `FirebaseException` on failure, leaving the
/// mapping to [FirebaseFailure] to `PresenceRepositoryImpl`.
///
/// Every method targets a single room's `rooms/{roomId}/presence` node
/// tree — `setPresence`/`removePresence` operate on one participant's
/// own `rooms/{roomId}/presence/{userId}` child; `subscribeToPresence`
/// reads/watches the whole `presence` node so the room UI can render
/// every currently online participant at once.
///
/// @see PresenceRemoteDataSourceImpl — the concrete implementation
/// @see PresenceRepositoryImpl — the repository mapping this port's
///   exceptions to [FirebaseFailure]
abstract class IPresenceRemoteDataSource {
  /// Writes this participant's presence node on room entry
  /// (`is_online: true`), and registers Firebase's `onDisconnect`
  /// handler so that an ungraceful disconnection (app crash, network
  /// loss) still clears presence automatically — see
  /// [PresenceRemoteDataSourceImpl.setPresence]'s own doc comment for
  /// why the `onDisconnect` registration happens *before* the node is
  /// written, not after.
  Future<void> setPresence({
    required String roomId,
    required String userId,
    required String username,
  });

  /// Clears this participant's presence node on a graceful room exit,
  /// and cancels the pending `onDisconnect` handler registered by
  /// [setPresence] — otherwise a delayed `onDisconnect` callback could
  /// still fire after this method already removed the node, briefly
  /// resurrecting an `is_online: false` node that should no longer
  /// exist at all.
  Future<void> removePresence({required String roomId, required String userId});

  /// Returns a live stream of every participant currently present in
  /// [roomId]'s `presence` node, re-emitting the full list on every
  /// change to any child.
  Stream<List<PresenceModel>> subscribeToPresence({required String roomId});
}
