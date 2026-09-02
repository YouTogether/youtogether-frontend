import 'package:firebase_auth/firebase_auth.dart';

import '../models/firebase_session_model.dart';
import 'i_firebase_session_data_source.dart';

/// SDK-backed implementation of [IFirebaseSessionDataSource].
///
/// Takes [FirebaseAuth] by constructor injection rather than reaching
/// for `FirebaseAuth.instance` internally, so the class stays
/// unit-testable and the service locator remains the single place where
/// the singleton is resolved.
///
/// Contains no logic beyond mapping `UserCredential` to
/// [FirebaseSessionModel]. Every decision about *whether* to sign in,
/// reuse or replace a session lives in
/// `EstablishFirebaseSessionUseCase`, where it can be tested without an
/// SDK at all.
class FirebaseSessionDataSourceImpl implements IFirebaseSessionDataSource {
  const FirebaseSessionDataSourceImpl(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  @override
  FirebaseSessionModel? get currentSession {
    final user = _firebaseAuth.currentUser;
    return user == null ? null : FirebaseSessionModel.fromUser(user);
  }

  @override
  Future<FirebaseSessionModel> signInWithCustomToken(String token) async {
    final credential = await _firebaseAuth.signInWithCustomToken(token);
    return _requireUser(credential);
  }

  @override
  Future<FirebaseSessionModel> signInAnonymously() async {
    final credential = await _firebaseAuth.signInAnonymously();
    return _requireUser(credential);
  }

  @override
  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }

  /// Converts a successful [UserCredential] into a model.
  ///
  /// `UserCredential.user` is nullable in the SDK's type signature but
  /// is never null after a successful sign-in. The null branch throws a
  /// `FirebaseAuthException` rather than a bare `StateError` so that the
  /// repository's single `FirebaseException` catch clause still covers
  /// it, and the caller sees a `FirebaseFailure` like any other SDK
  /// problem instead of an unhandled crash.
  FirebaseSessionModel _requireUser(UserCredential credential) {
    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'null-user',
        message: 'Sign-in succeeded but returned no user.',
      );
    }
    return FirebaseSessionModel.fromUser(user);
  }
}
