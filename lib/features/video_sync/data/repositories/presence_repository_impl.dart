import 'package:either_dart/either.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/presence_entity.dart';
import '../../domain/repositories/i_presence_repository.dart';
import '../datasources/i_presence_remote_data_source.dart';

/// Data layer implementation of [IPresenceRepository].
///
/// Mirrors `VideoSyncRepositoryImpl` exactly in structure: a single
/// `FirebaseException` catch clause per method, and a stream error on
/// [subscribeToPresence] converted to a `Left(FirebaseFailure)` event
/// rather than a stream error — see that class's own doc comment for
/// the shared rationale (letting `PresenceCubit`, react
/// without a dedicated `onError` handler).
///
/// @see IPresenceRepository — the domain port being implemented
class PresenceRepositoryImpl implements IPresenceRepository {
  PresenceRepositoryImpl({required IPresenceRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final IPresenceRemoteDataSource _remoteDataSource;

  Failure _toFailure(Object error) {
    if (error is FirebaseException) {
      return Failure.firebase(
        message: error.message ?? 'Unknown Firebase error',
      );
    }
    return Failure.firebase(message: error.toString());
  }

  @override
  Future<Either<Failure, void>> setPresence({
    required String roomId,
    required String userId,
    required String username,
    required bool isAnonymous,
  }) async {
    try {
      await _remoteDataSource.setPresence(
        roomId: roomId,
        userId: userId,
        username: username,
        isAnonymous: isAnonymous,
      );
      return const Right(null);
    } on FirebaseException catch (exception) {
      return Left(_toFailure(exception));
    }
  }

  @override
  Future<Either<Failure, void>> removePresence({
    required String roomId,
    required String userId,
  }) async {
    try {
      await _remoteDataSource.removePresence(roomId: roomId, userId: userId);
      return const Right(null);
    } on FirebaseException catch (exception) {
      return Left(_toFailure(exception));
    }
  }

  @override
  Stream<Either<Failure, List<PresenceEntity>>> subscribeToPresence({
    required String roomId,
  }) async* {
    try {
      await for (final models in _remoteDataSource.subscribeToPresence(
        roomId: roomId,
      )) {
        yield Right(models.map((model) => model.toDomain()).toList());
      }
    } on FirebaseException catch (exception) {
      yield Left(_toFailure(exception));
    } catch (error) {
      yield Left(_toFailure(error));
    }
  }
}
