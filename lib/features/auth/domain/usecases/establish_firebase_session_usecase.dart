import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/firebase_session_entity.dart';
import '../repositories/i_firebase_session_repository.dart';
import 'establish_firebase_session_params.dart';

/// Use case establishing the client's Firebase session, reusing the one
/// the SDK already holds when — and only when — it belongs to the right
/// identity.
///
/// Unlike most use cases in this codebase, this one is not a thin
/// delegation. The decision it encodes is the whole point of the
/// ticket, and it belongs in the domain rather than in a cubit: it is
/// security-relevant, it has four distinct branches, and it must be
/// testable without a widget tree or a Firebase SDK.
///
/// ## The four cases
/// The Firebase SDK persists its session across launches, so on any
/// given call it may already hold one:
///
/// 1. **No session** — sign in, anonymously or with a custom token
///    depending on whether anyone is signed in to the application.
/// 2. **Anonymous session, no application user** — reuse it. A visitor
///    keeps the same uid across launches, which is harmless and avoids
///    accumulating a new anonymous Firebase account per app start.
/// 3. **Named session matching the application user** — reuse it. This
///    is the common warm-start path, and it avoids a needless round trip
///    to `POST /auth/firebase-token` on every launch.
/// 4. **Session belonging to someone else** — release it, then sign in
///    afresh.
///
/// Case 4 is the one that matters. It covers a user logging out and
/// back in as a different account, and an anonymous visitor
/// subsequently signing in. Reusing the stale session there would let
/// the new user write presence nodes and playback commands under the
/// previous identity's uid, which the Realtime Database rules would
/// dutifully authorise — they check that `auth.uid` matches, not that
/// `auth.uid` is who the application thinks it is.
///
/// ## Failure of the sign-out step
/// If releasing a stale session fails, the use case reports that
/// failure rather than pressing on. Signing in over a session that
/// refused to end would leave the SDK in a state neither this code nor
/// the caller can reason about, and the correct client behaviour —
/// refuse to enter a room until identity is settled — is the same one a
/// failure already produces.
///
/// @competency Access control anchored in verified identity (OWASP A01:2021)
/// @see IFirebaseSessionRepository — the delegated port
class EstablishFirebaseSessionUseCase
    extends UseCase<FirebaseSessionEntity, EstablishFirebaseSessionParams> {
  EstablishFirebaseSessionUseCase(this._firebaseSessionRepository);

  final IFirebaseSessionRepository _firebaseSessionRepository;

  @override
  Future<Either<Failure, FirebaseSessionEntity>> call(
    EstablishFirebaseSessionParams params,
  ) async {
    final existing = _firebaseSessionRepository.currentSession;
    final appUserId = params.appUserId;

    if (existing != null) {
      final canReuse = appUserId == null
          ? existing.isAnonymous
          : !existing.isAnonymous && existing.uid == appUserId;

      if (canReuse) {
        return Right(existing);
      }

      final signOutResult = await _firebaseSessionRepository.signOut();
      if (signOutResult.isLeft) {
        return Left(signOutResult.left);
      }
    }

    return appUserId == null
        ? _firebaseSessionRepository.signInAnonymously()
        : _firebaseSessionRepository.signInWithCustomToken();
  }
}
