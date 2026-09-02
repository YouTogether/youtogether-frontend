import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/firebase_session_entity.dart';

part 'firebase_session_state.freezed.dart';

/// State hierarchy for [FirebaseSessionCubit].
///
/// Declared `@freezed` as a sealed union, mirroring `JoinRoomState`.
///
/// [initial] means "no session, and none being established" — the state
/// at cold start and after a logout. It is distinct from [failure]:
/// nothing has gone wrong, nothing has been attempted. `FirebaseSessionGate`
/// treats the two differently, offering a retry only for the second.
///
/// [ready] carries the session rather than just its uid, because the
/// distinction between an anonymous and a named session determines
/// what the Realtime Database rules will let the holder do, and callers
/// occasionally need to reason about that without asking `AuthBloc`
/// again.
@freezed
sealed class FirebaseSessionState with _$FirebaseSessionState {
  const factory FirebaseSessionState.initial() = FirebaseSessionInitial;
  const factory FirebaseSessionState.establishing() =
      FirebaseSessionEstablishing;
  const factory FirebaseSessionState.ready(FirebaseSessionEntity session) =
      FirebaseSessionReady;
  const factory FirebaseSessionState.failure(Failure failure) =
      FirebaseSessionFailure;
}
