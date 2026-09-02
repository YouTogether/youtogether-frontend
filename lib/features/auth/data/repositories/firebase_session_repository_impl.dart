import 'package:either_dart/either.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/firebase_session_entity.dart';
import '../../domain/repositories/i_firebase_session_repository.dart';
import '../datasources/i_firebase_session_data_source.dart';
import '../datasources/i_firebase_token_remote_data_source.dart';

/// Data layer implementation of [IFirebaseSessionRepository].
///
/// The only repository in the codebase drawing on two data sources with
/// unrelated failure surfaces: an HTTP call to the backend
/// (`ServerException`, `NetworkException`) followed by an SDK call
/// (`FirebaseException`). [signInWithCustomToken] therefore carries
/// three catch clauses where `VideoSyncRepositoryImpl` needs one and
/// `RoomRepositoryImpl` needs two.
///
/// That is a property of the operation, not an accident of design: the
/// custom token flow genuinely spans two systems, and collapsing the
/// two error sets would erase the distinction between "the backend
/// would not issue a token" and "Firebase would not accept it" —
/// diagnoses with entirely different remedies.
///
/// @see IFirebaseSessionRepository — the domain port being implemented
class FirebaseSessionRepositoryImpl implements IFirebaseSessionRepository {
  FirebaseSessionRepositoryImpl({
    required IFirebaseTokenRemoteDataSource tokenRemoteDataSource,
    required IFirebaseSessionDataSource sessionDataSource,
  }) : _tokenRemoteDataSource = tokenRemoteDataSource,
       _sessionDataSource = sessionDataSource;

  final IFirebaseTokenRemoteDataSource _tokenRemoteDataSource;
  final IFirebaseSessionDataSource _sessionDataSource;

  @override
  FirebaseSessionEntity? get currentSession {
    return _sessionDataSource.currentSession?.toDomain();
  }

  @override
  Future<Either<Failure, FirebaseSessionEntity>> signInWithCustomToken() async {
    try {
      final token = await _tokenRemoteDataSource.fetchCustomToken();
      final model = await _sessionDataSource.signInWithCustomToken(token);

      return Right(model.toDomain());
    } on ServerException catch (exception) {
      // 401 means the application session is gone or the account no
      // longer resolves. Surfaced as AuthFailure rather than
      // ServerFailure so the caller falls back to an anonymous session
      // instead of retrying a call that will keep failing.
      if (exception.statusCode == 401) {
        return Left(Failure.auth(message: exception.message));
      }
      return Left(
        Failure.server(
          statusCode: exception.statusCode,
          message: exception.message,
        ),
      );
    } on NetworkException {
      return const Left(Failure.network());
    } on FirebaseException catch (exception) {
      return Left(_toFirebaseFailure(exception));
    }
  }

  @override
  Future<Either<Failure, FirebaseSessionEntity>> signInAnonymously() async {
    try {
      final model = await _sessionDataSource.signInAnonymously();

      return Right(model.toDomain());
    } on FirebaseException catch (exception) {
      return Left(_toFirebaseFailure(exception));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await _sessionDataSource.signOut();

      return const Right(null);
    } on FirebaseException catch (exception) {
      return Left(_toFirebaseFailure(exception));
    }
  }

  /// Mirrors `VideoSyncRepositoryImpl._toFailure`.
  Failure _toFirebaseFailure(FirebaseException exception) {
    return Failure.firebase(
      message: exception.message ?? 'Unknown Firebase error',
    );
  }
}
