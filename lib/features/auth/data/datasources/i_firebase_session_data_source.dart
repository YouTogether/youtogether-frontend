import '../models/firebase_session_model.dart';

/// Contract for the Firebase Authentication SDK, isolating
/// `firebase_auth` behind an interface the rest of the codebase can
/// mock.
///
/// The isolation is not stylistic. `FirebaseAuth.instance` requires the
/// platform channels a `flutter test` process does not have, so any
/// class touching it directly becomes untestable — the same constraint
/// that produced `YoutubePlayerControllerAdapter` in the Video
/// Synchronisation context.
///
/// Every method throws `FirebaseAuthException` (a `FirebaseException`
/// subtype) and nothing else, which is what lets
/// `FirebaseSessionRepositoryImpl` map SDK failures with a single catch
/// clause, exactly as `VideoSyncRepositoryImpl` already does.
///
/// @see FirebaseSessionDataSourceImpl — the SDK-backed implementation
abstract class IFirebaseSessionDataSource {
  /// The session the SDK currently holds, or `null` if none.
  ///
  /// Reads the SDK's cached `currentUser`; performs no I/O and does not
  /// throw. The SDK restores a persisted session before the first
  /// frame, so this is meaningful from application start.
  FirebaseSessionModel? get currentSession;

  /// Exchanges a backend-issued custom token for a Firebase session.
  ///
  /// Throws `FirebaseAuthException` with `invalid-custom-token` if the
  /// token was signed for a different project, or `custom-token-mismatch`
  /// if the audience does not match — both indicate a backend
  /// misconfiguration rather than anything the user can act on.
  Future<FirebaseSessionModel> signInWithCustomToken(String token);

  /// Establishes an anonymous session.
  ///
  /// Throws `FirebaseAuthException` with `operation-not-allowed` if the
  /// Anonymous provider has not been enabled in the Firebase console.
  /// That is a deployment prerequisite, not a runtime condition.
  Future<FirebaseSessionModel> signInAnonymously();

  /// Releases the current session. A no-op when there is none.
  Future<void> signOut();
}
