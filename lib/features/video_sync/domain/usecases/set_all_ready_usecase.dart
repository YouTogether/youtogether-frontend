import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/i_sync_barrier_repository.dart';

/// Use case for resolving the ready gate (Section 4.1, step 5), whether
/// because every participant signalled readiness or because the leader
/// force-started after the timeout (Section 4.2).
///
/// @see ISyncBarrierRepository.setAllReady — the delegated port method
class SetAllReadyUseCase extends UseCase<void, String> {
  SetAllReadyUseCase(this._syncBarrierRepository);

  final ISyncBarrierRepository _syncBarrierRepository;

  @override
  Future<Either<Failure, void>> call(String roomId) {
    return _syncBarrierRepository.setAllReady(roomId: roomId);
  }
}
