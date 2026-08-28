import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/i_sync_barrier_repository.dart';
import 'create_sync_barrier_params.dart';

/// Use case for opening the ready gate (Section 4.1, step 1 of
/// `YouTogether_Ad_Synchronisation_Strategy.docx`).
///
/// A thin delegation to [ISyncBarrierRepository.createBarrier],
/// matching every other use case in this bounded context. It exists so
/// `VideoSyncBloc` depends on the domain's *use cases* rather than
/// reaching into a repository port directly — the layering every other
/// bloc and cubit in this codebase already follows.
///
/// @see ISyncBarrierRepository.createBarrier — the delegated port method
class CreateSyncBarrierUseCase extends UseCase<void, CreateSyncBarrierParams> {
  CreateSyncBarrierUseCase(this._syncBarrierRepository);

  final ISyncBarrierRepository _syncBarrierRepository;

  @override
  Future<Either<Failure, void>> call(CreateSyncBarrierParams params) {
    return _syncBarrierRepository.createBarrier(
      roomId: params.roomId,
      targetTimestamp: params.targetTimestamp,
      totalCount: params.totalCount,
    );
  }
}
