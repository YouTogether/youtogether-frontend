import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/i_sync_barrier_repository.dart';

/// Use case for tearing down the ready gate once it has resolved
/// (Section 4.1, step 6).
///
/// @see ISyncBarrierRepository.deleteBarrier — the delegated port method
class DeleteSyncBarrierUseCase extends UseCase<void, String> {
  DeleteSyncBarrierUseCase(this._syncBarrierRepository);

  final ISyncBarrierRepository _syncBarrierRepository;

  @override
  Future<Either<Failure, void>> call(String roomId) {
    return _syncBarrierRepository.deleteBarrier(roomId: roomId);
  }
}
