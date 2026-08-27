import 'package:either_dart/either.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;

import '../../../../core/error/failures.dart';
import '../../domain/entities/sync_barrier_entity.dart';
import '../../domain/repositories/i_sync_barrier_repository.dart';
import '../datasources/i_sync_barrier_remote_data_source.dart';

/// Data layer implementation of [ISyncBarrierRepository].
///
/// Mirrors `VideoSyncRepositoryImpl`/`PresenceRepositoryImpl` exactly:
/// a single `FirebaseException` catch clause per method, and a stream
/// error on [subscribeToBarrier] converted to a `Left(FirebaseFailure)`
/// event rather than a stream error.
class SyncBarrierRepositoryImpl implements ISyncBarrierRepository {
  SyncBarrierRepositoryImpl({
    required ISyncBarrierRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final ISyncBarrierRemoteDataSource _remoteDataSource;

  Failure _toFailure(Object error) {
    if (error is FirebaseException) {
      return Failure.firebase(
        message: error.message ?? 'Unknown Firebase error',
      );
    }
    return Failure.firebase(message: error.toString());
  }

  @override
  Future<Either<Failure, void>> createBarrier({
    required String roomId,
    required Duration targetTimestamp,
    required int totalCount,
  }) async {
    try {
      await _remoteDataSource.createBarrier(
        roomId: roomId,
        targetTimestamp: targetTimestamp,
        totalCount: totalCount,
      );
      return const Right(null);
    } on FirebaseException catch (exception) {
      return Left(_toFailure(exception));
    }
  }

  @override
  Future<Either<Failure, void>> incrementReadyCount({
    required String roomId,
  }) async {
    try {
      await _remoteDataSource.incrementReadyCount(roomId: roomId);
      return const Right(null);
    } on FirebaseException catch (exception) {
      return Left(_toFailure(exception));
    }
  }

  @override
  Future<Either<Failure, void>> updateTotalCount({
    required String roomId,
    required int totalCount,
  }) async {
    try {
      await _remoteDataSource.updateTotalCount(
        roomId: roomId,
        totalCount: totalCount,
      );
      return const Right(null);
    } on FirebaseException catch (exception) {
      return Left(_toFailure(exception));
    }
  }

  @override
  Future<Either<Failure, void>> setAllReady({required String roomId}) async {
    try {
      await _remoteDataSource.setAllReady(roomId: roomId);
      return const Right(null);
    } on FirebaseException catch (exception) {
      return Left(_toFailure(exception));
    }
  }

  @override
  Future<Either<Failure, void>> deleteBarrier({required String roomId}) async {
    try {
      await _remoteDataSource.deleteBarrier(roomId: roomId);
      return const Right(null);
    } on FirebaseException catch (exception) {
      return Left(_toFailure(exception));
    }
  }

  @override
  Stream<Either<Failure, SyncBarrierEntity>> subscribeToBarrier({
    required String roomId,
  }) async* {
    try {
      await for (final model in _remoteDataSource.subscribeToBarrier(
        roomId: roomId,
      )) {
        yield Right(model.toDomain());
      }
    } on FirebaseException catch (exception) {
      yield Left(_toFailure(exception));
    } catch (error) {
      yield Left(_toFailure(error));
    }
  }
}
