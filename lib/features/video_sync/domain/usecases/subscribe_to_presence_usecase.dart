import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/stream_usecase.dart';
import '../entities/presence_entity.dart';
import '../repositories/i_presence_repository.dart';

/// Use case for subscribing to live presence updates for a room.
///
/// Extends `StreamUseCase<List<PresenceEntity>, String>` — the input is
/// simply the room id, mirroring `SubscribeToPlaybackStateUseCase`.
/// Contains no business logic beyond delegating to
/// `IPresenceRepository.subscribeToPresence()`.
///
/// This list is the *complete* answer to "who is currently in this
/// room's broadcast session" — it is never combined with, or reconciled
/// against, the Postgres-sourced `room_memberships` count. A previous
/// revision of this comment said otherwise, citing
/// `decision-anonymous-room-join.md`; that reading was corrected.
/// Membership (a persisted, durable relationship: "I have
/// joined this room") and presence (an ephemeral, real-time fact: "I am
/// watching right now") are separate concepts that happen to both be
/// counted — a room with fifty members has a presence count of zero
/// when nobody is watching, and that zero is correct, not a bug.
///
/// @see IPresenceRepository.subscribeToPresence — the delegated port method
/// @see PresenceCubit — the consumer that turns this into a live count
class SubscribeToPresenceUseCase
    extends StreamUseCase<List<PresenceEntity>, String> {
  SubscribeToPresenceUseCase(this._presenceRepository);

  final IPresenceRepository _presenceRepository;

  @override
  Stream<Either<Failure, List<PresenceEntity>>> call(String roomId) {
    return _presenceRepository.subscribeToPresence(roomId: roomId);
  }
}
