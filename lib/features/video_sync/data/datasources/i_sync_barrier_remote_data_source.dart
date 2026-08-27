import '../models/sync_barrier_model.dart';

/// Contract for the `sync_barrier` Firebase node access, mirroring
/// `IVideoSyncRemoteDataSource`/`IPresenceRemoteDataSource`: methods
/// throw `firebase_database`'s `FirebaseException` on failure, leaving
/// the mapping to [FirebaseFailure] to `SyncBarrierRepositoryImpl`.
///
/// @see SyncBarrierRemoteDataSourceImpl — the concrete implementation
abstract class ISyncBarrierRemoteDataSource {
  Future<void> createBarrier({
    required String roomId,
    required Duration targetTimestamp,
    required int totalCount,
  });

  /// Atomically increments `ready_count` via a Firebase transaction —
  /// see `SyncBarrierRemoteDataSourceImpl.incrementReadyCount`'s own doc
  /// comment for the exact mechanism.
  Future<void> incrementReadyCount({required String roomId});

  Future<void> updateTotalCount({
    required String roomId,
    required int totalCount,
  });

  Future<void> setAllReady({required String roomId});

  Future<void> deleteBarrier({required String roomId});

  Stream<SyncBarrierModel> subscribeToBarrier({required String roomId});
}
