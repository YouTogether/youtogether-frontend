import 'package:freezed_annotation/freezed_annotation.dart';

part 'establish_firebase_session_params.freezed.dart';

/// Value object encapsulating the input required to establish a Firebase
/// session.
///
/// [appUserId] is the *application's* user id — the UUID from
/// `UserEntity` — or `null` when no one is signed in. It is not sent
/// anywhere: `POST /auth/firebase-token` derives the identity from the
/// bearer token, and sending an id from the client would defeat that.
///
/// It is carried solely so [EstablishFirebaseSessionUseCase] can decide
/// whether a session the SDK already holds belongs to this user or to a
/// previous one. That comparison is the whole reason this params object
/// exists rather than the use case taking `NoParams`.
///
/// @see EstablishFirebaseSessionUseCase
@freezed
sealed class EstablishFirebaseSessionParams
    with _$EstablishFirebaseSessionParams {
  const factory EstablishFirebaseSessionParams({
    /// The signed-in user's application UUID, or `null` for a visitor.
    required String? appUserId,
  }) = _EstablishFirebaseSessionParams;
}
