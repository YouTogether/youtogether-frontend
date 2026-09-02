import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/firebase_session_entity.dart';

/// Data layer representation of a Firebase Authentication session.
///
/// Unlike every other model in this codebase, this one deserialises
/// from an SDK object rather than from JSON. It exists for the same
/// reason they do: to keep a third-party type out of the domain layer.
/// `IFirebaseSessionRepository` returns
/// [FirebaseSessionEntity], and nothing above the data layer imports
/// `firebase_auth`.
///
/// Only two of [User]'s many fields are carried. The rest — email,
/// display name, photo URL, provider data — describe a Firebase
/// *account*, which this application does not have and does not want:
/// identity is owned by the backend. Copying them across would create a
/// second, silently diverging profile.
///
/// @see FirebaseSessionEntity — the domain type this maps to
class FirebaseSessionModel {
  const FirebaseSessionModel({required this.uid, required this.isAnonymous});

  /// Builds a model from the SDK's current [User].
  ///
  /// [User.isAnonymous] is the SDK's own record of how the session was
  /// established, and survives the app restarts that make this
  /// distinction matter — see
  /// `EstablishFirebaseSessionUseCase` for the cold-start cases it
  /// disambiguates.
  factory FirebaseSessionModel.fromUser(User user) {
    return FirebaseSessionModel(uid: user.uid, isAnonymous: user.isAnonymous);
  }

  final String uid;
  final bool isAnonymous;

  FirebaseSessionEntity toDomain() {
    return FirebaseSessionEntity(uid: uid, isAnonymous: isAnonymous);
  }
}
