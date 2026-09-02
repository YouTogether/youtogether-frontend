import 'package:freezed_annotation/freezed_annotation.dart';

part 'firebase_session_entity.freezed.dart';

/// A live Firebase Authentication session, described in the only two
/// terms the rest of the application cares about.
///
/// ## Why this is not `UserEntity`
/// The two describe different identities and must not be conflated.
/// [UserEntity] is this application's account: an email, a display
/// name, a role, a PostgreSQL row. A [FirebaseSessionEntity] is a
/// credential held by the Firebase SDK, and its only job is to make
/// `auth.uid` non-null so the Realtime Database security rules have
/// something to authorise against.
///
/// For a registered user the two [uid]s coincide, by design: the
/// backend mints the custom token with the account's UUID as the
/// Firebase uid, so `auth.uid` can be compared directly against
/// `playback_state.leader_id`, which the backend writes from the room's
/// `ownerId`. For an anonymous viewer only this identity
/// exists — they have no account here at all.
///
/// Presence nodes are keyed by *this* [uid], never by the application
/// user id, because the security rules will restrict each participant
/// to writing under `auth.uid`.
///
/// ## Why [isAnonymous] is carried rather than derived
/// A cold start finds whatever session the SDK persisted, which may
/// belong to a different account than the one now signed in — the user
/// logged out and back in as someone else. Distinguishing "anonymous
/// session, reusable by any visitor" from "named session, reusable only
/// by its own account" is what
/// [EstablishFirebaseSessionUseCase] needs in order to decide whether
/// to reuse or replace it, and it cannot be inferred from [uid] alone.
///
/// @see IFirebaseSessionRepository
/// @see EstablishFirebaseSessionUseCase
@freezed
sealed class FirebaseSessionEntity with _$FirebaseSessionEntity {
  const factory FirebaseSessionEntity({
    /// The Firebase `uid` this session authenticates as.
    ///
    /// Equal to the application's user UUID for a registered user;
    /// an opaque Firebase-generated value for an anonymous visitor.
    required String uid,

    /// Whether this session was established via `signInAnonymously`
    /// rather than a backend-issued custom token.
    required bool isAnonymous,
  }) = _FirebaseSessionEntity;
}
