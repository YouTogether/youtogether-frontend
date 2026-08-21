import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../entities/sync_barrier_entity.dart';

/// Domain port for the `sync_barrier` Firebase node (ready-gate
/// mechanism), per `YouTogether_Ad_Synchronisation_Strategy.docx`,
/// Sections 3.1 and 4.
///
/// Kept as its own interface rather than folded into
/// [IVideoSyncRepository]: `sync_barrier` is a distinct Firebase node
/// with its own lifecycle (created by the leader on first play, deleted
/// once resolved), independent of `playback_state`'s own lifecycle —
/// mirroring why `IPresenceRepository` is likewise kept separate from
/// `IVideoSyncRepository` (see that interface's own doc comment for the
/// same rationale, applied here to a second, equally independent node).
///
/// @see SyncBarrierRepositoryImpl — the data-layer implementation
abstract class ISyncBarrierRepository {
  /// Creates the barrier node (leader only), Section 4.1 step 1.
  /// [totalCount] is the number of currently online participants,
  /// read by the caller from `IPresenceRepository` at call time.
  Future<Either<Failure, void>> createBarrier({
    required String roomId,
    required Duration targetTimestamp,
    required int totalCount,
  });

  /// Atomically increments `ready_count` via a Firebase transaction
  /// (Section 4.1 step 3) — a plain read-then-write would race if two
  /// participants become ready at nearly the same instant.
  Future<Either<Failure, void>> incrementReadyCount({required String roomId});

  /// Sets `all_ready = true` (Section 4.1 step 5, or a leader-forced
  /// timeout per Section 4.2).
  Future<Either<Failure, void>> setAllReady({required String roomId});

  /// Deletes the barrier node (leader, after `all_ready`), Section 4.1
  /// step 6.
  Future<Either<Failure, void>> deleteBarrier({required String roomId});

  /// Live stream of the barrier's current state, so every participant
  /// (not just the leader) observes `readyCount`/`totalCount`/
  /// `allReady` as they change.
  Stream<Either<Failure, SyncBarrierEntity>> subscribeToBarrier({
    required String roomId,
  });
}
