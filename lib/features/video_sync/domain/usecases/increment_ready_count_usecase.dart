import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/i_sync_barrier_repository.dart';

/// Use case for signalling that this participant is past its pre-roll
/// (Section 4.1, step 3).
///
/// Takes the room id directly rather than a params object — a single
/// scalar input, mirroring `GetCurrentPlaybackStateUseCase`.
///
/// The atomicity of the underlying increment is a data-layer concern
/// (`SyncBarrierRemoteDataSourceImpl` runs a Firebase transaction);
/// this layer only expresses the intent.
///
/// @see ISyncBarrierRepository.incrementReadyCount — the delegated port method
class IncrementReadyCountUseCase extends UseCase<void, String> {
  IncrementReadyCountUseCase(this._syncBarrierRepository);

  final ISyncBarrierRepository _syncBarrierRepository;

  @override
  Future<Either<Failure, void>> call(String roomId) {
    return _syncBarrierRepository.incrementReadyCount(roomId: roomId);
  }
}
