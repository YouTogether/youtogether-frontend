import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../entities/firebase_session_entity.dart';

/// Domain port for establishing and releasing the client's Firebase
/// Authentication session.
///
/// Separate from [IAuthRepository], which owns this application's own
/// identity — email, password, JWT pair, local token storage. This port
/// owns only the Firebase credential derived from that identity. The
/// two are kept apart because they fail differently, expire
/// differently, and are consumed by different layers: `IAuthRepository`
/// serves the login screens, this one serves the Realtime Database
/// security rules.
///
/// ## Why the client needs a Firebase identity at all
/// The application does not use Firebase Authentication as a source of
/// identity. Without a session, however, clients reach the Realtime
/// Database with `auth == null`, and no rule can restrict a write to
/// the room's leader or to a participant's own presence node. The
/// session exists solely so those rules become expressible.
///
/// @see FirebaseSessionRepositoryImpl — the data layer implementation
/// @see EstablishFirebaseSessionUseCase — primary consumer
abstract class IFirebaseSessionRepository {
  /// The session the Firebase SDK currently holds, or `null` if none.
  ///
  /// Synchronous and non-failing by design: the SDK restores a
  /// persisted session before the first frame, and this getter reads
  /// that cached value rather than performing any I/O. Modelling it as
  /// `Future<Either<...>>` would suggest a network round trip that does
  /// not happen and would force every caller into an `await` for a
  /// field read.
  ///
  /// A returned session is **not** proof that it belongs to the user
  /// currently signed in to this application — see
  /// [FirebaseSessionEntity.isAnonymous] for the cold-start case this
  /// guards against.
  FirebaseSessionEntity? get currentSession;

  /// Establishes a session for the currently authenticated user, by
  /// requesting a custom token from `POST /auth/firebase-token` and
  /// exchanging it with Firebase.
  ///
  /// Takes no user id: the backend resolves it from the bearer token
  /// and re-checks the account is still active before minting (B-A06).
  /// Sending an id from here would be the access-control mistake that
  /// endpoint exists to avoid, since the resulting `auth.uid` is what
  /// authorises Realtime Database writes.
  ///
  /// - `Left(AuthFailure)` — no valid application session; the caller
  ///   should be treating this user as anonymous.
  /// - `Left(ServerFailure)` — the backend could not sign a token
  ///   (HTTP 502). Transient; retrying is the correct response.
  /// - `Left(NetworkFailure)` — the request never reached the backend.
  /// - `Left(FirebaseFailure)` — the token was issued but Firebase
  ///   refused it, which in practice means a clock skew or a revoked
  ///   service account.
  Future<Either<Failure, FirebaseSessionEntity>> signInWithCustomToken();

  /// Establishes an anonymous session.
  ///
  /// Used for visitors with no account here. They obtain a real
  /// `auth.uid`, which is what lets the security rules key a presence
  /// node to its writer — without it, an anonymous viewer has no
  /// identity to scope a write to, and the presence path degenerates to
  /// the shared parent node.
  ///
  /// Requires the Anonymous provider to be enabled in the Firebase
  /// console; otherwise the SDK reports `operation-not-allowed`, which
  /// surfaces here as `Left(FirebaseFailure)`.
  Future<Either<Failure, FirebaseSessionEntity>> signInAnonymously();

  /// Releases the current session.
  ///
  /// Called when the application session ends, and — more importantly —
  /// when a persisted Firebase session turns out to belong to a
  /// different account than the one now signed in. Reusing such a
  /// session would let a user write presence and playback commands
  /// under the previous account's uid.
  ///
  /// Resolves to `Right(null)` when there was no session to release:
  /// releasing nothing is not a failure.
  Future<Either<Failure, void>> signOut();
}
