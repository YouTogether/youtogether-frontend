import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/i_firebase_session_repository.dart';

/// Use case releasing the client's Firebase session.
///
/// A thin delegation to [IFirebaseSessionRepository.signOut], mirroring
/// `LogoutUseCase`.
///
/// Called alongside the application logout, never instead of it. The two
/// are independent credentials with independent lifetimes: ending the
/// application session leaves a Firebase session that would keep
/// refreshing itself indefinitely, still able to write to any node its
/// uid is authorised for. `EstablishFirebaseSessionUseCase` would
/// eventually detect and replace such a session on the next sign-in,
/// but leaving a live credential behind on a shared device for that
/// long is not acceptable — hence an explicit release.
///
/// Releasing a session that does not exist is not an error; see the
/// port's own doc comment.
///
/// @see IFirebaseSessionRepository.signOut — the delegated port method
class EndFirebaseSessionUseCase extends UseCase<void, NoParams> {
  EndFirebaseSessionUseCase(this._firebaseSessionRepository);

  final IFirebaseSessionRepository _firebaseSessionRepository;

  @override
  Future<Either<Failure, void>> call(NoParams params) {
    return _firebaseSessionRepository.signOut();
  }
}
