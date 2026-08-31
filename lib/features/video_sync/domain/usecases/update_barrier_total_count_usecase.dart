import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/i_sync_barrier_repository.dart';
import 'update_barrier_total_count_params.dart';

/// Use case for keeping an open ready gate's `total_count` in step with
/// the room's online population (Section 4.1, step 4).
///
/// Without it, a participant disconnecting mid-barrier would leave
/// `ready_count >= total_count` permanently unsatisfiable.
///
/// @see ISyncBarrierRepository.updateTotalCount — the delegated port method
class UpdateBarrierTotalCountUseCase
    extends UseCase<void, UpdateBarrierTotalCountParams> {
  UpdateBarrierTotalCountUseCase(this._syncBarrierRepository);

  final ISyncBarrierRepository _syncBarrierRepository;

  @override
  Future<Either<Failure, void>> call(UpdateBarrierTotalCountParams params) {
    return _syncBarrierRepository.updateTotalCount(
      roomId: params.roomId,
      totalCount: params.totalCount,
    );
  }
}
