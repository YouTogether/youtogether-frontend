import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/sync_barrier_model.dart';
import 'i_sync_barrier_remote_data_source.dart';

/// Concrete [ISyncBarrierRemoteDataSource] backed by Firebase Realtime
/// Database.
///
/// NOTE: `runTransaction`'s exact signature (return type, whether the
/// transaction handler receives `Object?` or a package-specific
/// wrapper type, and the exact success-value constructor name — used
/// here as a plausible `Transaction.success(...)`/`Transaction.abort()`
/// pair) could not be verified against a live `firebase_database` fetch
/// in this offline environment. Re-check
/// [incrementReadyCount] against the pinned package version before
/// this compiles for real — the same caveat already applied to
/// `youtube_player_controller_factory.dart`'s `currentTime` getter.
class SyncBarrierRemoteDataSourceImpl implements ISyncBarrierRemoteDataSource {
  SyncBarrierRemoteDataSourceImpl({required FirebaseDatabase database})
    : _database = database;

  final FirebaseDatabase _database;

  DatabaseReference _barrierRef(String roomId) {
    return _database.ref('rooms/$roomId/sync_barrier');
  }

  @override
  Future<void> createBarrier({
    required String roomId,
    required Duration targetTimestamp,
    required int totalCount,
  }) {
    return _barrierRef(roomId).set(
      SyncBarrierModel(
        targetTimestampSeconds: targetTimestamp.inMilliseconds / 1000,
        readyCount: 0,
        totalCount: totalCount,
        allReady: false,
      ).toJson(),
    );
  }

  @override
  Future<void> incrementReadyCount({required String roomId}) async {
    await _barrierRef(roomId).child('ready_count').runTransaction((
      currentValue,
    ) {
      final current = (currentValue as int?) ?? 0;
      return Transaction.success(current + 1);
    });
  }

  @override
  Future<void> setAllReady({required String roomId}) {
    return _barrierRef(roomId).update({'all_ready': true});
  }

  @override
  Future<void> deleteBarrier({required String roomId}) {
    return _barrierRef(roomId).remove();
  }

  @override
  Stream<SyncBarrierModel> subscribeToBarrier({required String roomId}) {
    return _barrierRef(roomId).onValue.map((event) {
      final value = event.snapshot.value;
      if (!event.snapshot.exists || value == null) {
        throw FirebaseException(
          plugin: 'firebase_database',
          message: 'No sync_barrier found for this room.',
        );
      }
      return SyncBarrierModel.fromSnapshot(value as Map<Object?, Object?>);
    });
  }
}
