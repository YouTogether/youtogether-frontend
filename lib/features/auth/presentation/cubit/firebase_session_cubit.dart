import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/end_firebase_session_usecase.dart';
import '../../domain/usecases/establish_firebase_session_params.dart';
import '../../domain/usecases/establish_firebase_session_usecase.dart';
import 'firebase_session_state.dart';

/// Cubit owning the client's Firebase session for the whole application
/// lifetime.
///
/// Provided once, above the router, alongside `AuthBloc` — the only
/// other app-scoped bloc. Every other cubit in this codebase is scoped
/// to a page, but a Firebase session is a process-wide credential: two
/// instances would fight over the same SDK singleton, and a
/// page-scoped one would be torn down on navigation while the session
/// it established kept running.
///
/// ## Two triggers, deliberately
/// [synchronise] is called from two places, and both are necessary:
///
/// - **`App`**, on every `AuthState` transition to authenticated. A
///   user who signs in gets a named Firebase session immediately, so
///   the credential is in place before they reach a room.
/// - **`FirebaseSessionGate`**, when a screen that needs the Realtime
///   Database mounts and no session is ready. This is what establishes
///   the *anonymous* session for a visitor.
///
/// Anonymous sessions are deliberately not established at startup.
/// Doing so would mint a Firebase anonymous account for every visitor
/// on first launch, including the many who never open a room. Deferring
/// it to the point of need costs nothing — the gate already renders a
/// loading state — and keeps the project's anonymous user list
/// proportional to actual use.
///
/// ## Re-entrancy
/// Both triggers can fire close together: a user signing in on the
/// login screen and then navigating straight into a room. [synchronise]
/// therefore ignores a call made while one is already in flight, rather
/// than starting a second sign-in against the same SDK singleton.
///
/// @see EstablishFirebaseSessionUseCase — where the reuse decision lives
/// @see FirebaseSessionGate — the widget that consumes this state
class FirebaseSessionCubit extends Cubit<FirebaseSessionState> {
  FirebaseSessionCubit({
    required EstablishFirebaseSessionUseCase establishFirebaseSessionUseCase,
    required EndFirebaseSessionUseCase endFirebaseSessionUseCase,
  }) : _establishFirebaseSessionUseCase = establishFirebaseSessionUseCase,
       _endFirebaseSessionUseCase = endFirebaseSessionUseCase,
       super(const FirebaseSessionState.initial());

  final EstablishFirebaseSessionUseCase _establishFirebaseSessionUseCase;
  final EndFirebaseSessionUseCase _endFirebaseSessionUseCase;

  /// Establishes a Firebase session appropriate to [appUserId], reusing
  /// the one the SDK already holds when it belongs to the right
  /// identity.
  ///
  /// [appUserId] is the application's user UUID, or `null` for a
  /// visitor. It is never sent anywhere — see
  /// [EstablishFirebaseSessionParams].
  ///
  /// Safe to call repeatedly: the use case reuses a matching session
  /// without any network traffic, so a redundant call is close to free.
  Future<void> synchronise({required String? appUserId}) async {
    if (state is FirebaseSessionEstablishing) {
      return;
    }

    emit(const FirebaseSessionState.establishing());

    final result = await _establishFirebaseSessionUseCase(
      EstablishFirebaseSessionParams(appUserId: appUserId),
    );

    result.fold(
      (failure) => emit(FirebaseSessionState.failure(failure)),
      (session) => emit(FirebaseSessionState.ready(session)),
    );
  }

  /// Releases the Firebase session, returning to
  /// [FirebaseSessionState.initial].
  ///
  /// Called by `App` when the application session ends. Not merged into
  /// [synchronise] with a null [appUserId]: that would replace a named
  /// session with an anonymous one, leaving a live Firebase credential
  /// on a device whose user has just logged out. A visitor who then
  /// opens a room gets an anonymous session from the gate, at the point
  /// where one is actually needed.
  ///
  /// The result of the sign-out is deliberately not inspected. Whether
  /// the SDK managed to release the session cleanly or not, this client
  /// no longer considers it usable, and reporting a failure the user
  /// cannot act on would be noise. The next [synchronise] re-evaluates
  /// the SDK's actual state anyway.
  Future<void> release() async {
    await _endFirebaseSessionUseCase(const NoParams());

    emit(const FirebaseSessionState.initial());
  }
}
