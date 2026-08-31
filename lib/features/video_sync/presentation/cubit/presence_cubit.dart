import 'dart:async';

import 'package:either_dart/either.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/presence_entity.dart';
import '../../domain/usecases/remove_presence_params.dart';
import '../../domain/usecases/remove_presence_usecase.dart';
import '../../domain/usecases/set_presence_params.dart';
import '../../domain/usecases/set_presence_usecase.dart';
import '../../domain/usecases/subscribe_to_presence_usecase.dart';
import 'presence_state.dart';

/// Tracks who is currently watching in a room's broadcast session, and
/// registers this participant as one of them.
///
/// ## Presence is not membership
/// This cubit reports *participation*, not *membership*. A user counts
/// as present only while the video player is on screen — that is, while
/// they are actually following the broadcast. Membership
/// (`room_memberships` in PostgreSQL, driven by the explicit join/leave
/// buttons) is a separate, durable relationship that outlives any
/// session.
///
/// The two are never reconciled or summed. A room with fifty registered
/// members shows a participant count of `0` when nobody has the player
/// open, and that zero is correct. An earlier reading of
/// `decision-anonymous-room-join.md` had this cubit combining the
/// Firebase presence count with the Postgres member count into a single
/// figure; that was corrected in F-V05-T3 — see
/// `SubscribeToPresenceUseCase`'s own doc comment, corrected in the
/// same pass.
///
/// ## Leaving is not a button
/// Participation ends when the player leaves the screen, whatever the
/// reason — the explicit leave button, the back arrow, a `context.go`
/// elsewhere, app termination, or a crash. Three mechanisms cover those
/// paths, deliberately overlapping:
///
/// 1. [leaveSession] — an explicit call, for a caller that knows it is
///    leaving and wants the write to complete.
/// 2. [close] — called automatically by `BlocProvider` when the page's
///    provider is disposed, which covers every ordinary navigation away
///    without any caller having to remember to do anything. This is the
///    path that matters most: it makes ending participation a property
///    of leaving the page, not of pressing a particular button.
/// 3. The Firebase `onDisconnect` handler registered by
///    `PresenceRemoteDataSourceImpl` (F-V05-T2) — the backstop for
///    crashes and network loss, where no Dart code gets to run at all.
///
/// [_sessionActive] makes 1 and 2 idempotent: whichever fires first
/// clears the node, and the other becomes a no-op rather than issuing a
/// redundant second delete.
class PresenceCubit extends Cubit<PresenceState> {
  PresenceCubit({
    required String roomId,
    required String userId,
    required String username,
    required bool isAnonymous,
    required SetPresenceUseCase setPresenceUseCase,
    required RemovePresenceUseCase removePresenceUseCase,
    required SubscribeToPresenceUseCase subscribeToPresenceUseCase,
  }) : _roomId = roomId,
       _userId = userId,
       _username = username,
       _isAnonymous = isAnonymous,
       _setPresenceUseCase = setPresenceUseCase,
       _removePresenceUseCase = removePresenceUseCase,
       _subscribeToPresenceUseCase = subscribeToPresenceUseCase,
       super(const PresenceState.initial());

  final String _roomId;
  final String _userId;
  final String _username;
  final bool _isAnonymous;
  final SetPresenceUseCase _setPresenceUseCase;
  final RemovePresenceUseCase _removePresenceUseCase;
  final SubscribeToPresenceUseCase _subscribeToPresenceUseCase;

  StreamSubscription<Either<Failure, List<PresenceEntity>>>? _subscription;
  bool _sessionActive = false;

  /// Registers this participant as present and opens the live list.
  ///
  /// Called once, when the player page mounts.
  Future<void> enterSession() async {
    emit(const PresenceState.loading());

    final result = await _setPresenceUseCase(
      SetPresenceParams(
        roomId: _roomId,
        userId: _userId,
        username: _username,
        isAnonymous: _isAnonymous,
      ),
    );

    if (result.isLeft) {
      emit(PresenceState.failure(result.left));
      return;
    }

    _sessionActive = true;

    await _subscription?.cancel();
    _subscription = _subscribeToPresenceUseCase(_roomId).listen((result) {
      if (isClosed) return;
      result.fold(
        (failure) => emit(PresenceState.failure(failure)),
        (participants) => emit(PresenceState.loaded(participants)),
      );
    });
  }

  /// Ends this participant's presence.
  ///
  /// A no-op if the session was never entered, or was already ended —
  /// see this class's own doc comment on why [leaveSession] and [close]
  /// deliberately overlap.
  Future<void> leaveSession() async {
    if (!_sessionActive) return;
    _sessionActive = false;

    await _subscription?.cancel();
    _subscription = null;

    await _removePresenceUseCase(
      RemovePresenceParams(roomId: _roomId, userId: _userId),
    );
  }

  @override
  Future<void> close() async {
    await leaveSession();
    return super.close();
  }
}
