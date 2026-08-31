import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/stream_usecase.dart';
import '../entities/sync_barrier_entity.dart';
import '../repositories/i_sync_barrier_repository.dart';

/// Use case for observing the ready gate's live state.
///
/// Extends `StreamUseCase<SyncBarrierEntity, String>`, mirroring
/// `SubscribeToPlaybackStateUseCase` — every participant watches the
/// barrier, not just the leader, since `all_ready` is what releases
/// each client's own playback.
///
/// @see ISyncBarrierRepository.subscribeToBarrier — the delegated port method
class SubscribeToSyncBarrierUseCase
    extends StreamUseCase<SyncBarrierEntity, String> {
  SubscribeToSyncBarrierUseCase(this._syncBarrierRepository);

  final ISyncBarrierRepository _syncBarrierRepository;

  @override
  Stream<Either<Failure, SyncBarrierEntity>> call(String roomId) {
    return _syncBarrierRepository.subscribeToBarrier(roomId: roomId);
  }
}
