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
/// Combining this list's count with the Postgres-sourced registered
/// member count is `PresenceCubit`'s concern, not this use case's: this
/// layer only ever reports who is present in Firebase, never anything
/// about `room_memberships`.
///
/// @see IPresenceRepository.subscribeToPresence — the delegated port method
class SubscribeToPresenceUseCase
    extends StreamUseCase<List<PresenceEntity>, String> {
  SubscribeToPresenceUseCase(this._presenceRepository);

  final IPresenceRepository _presenceRepository;

  @override
  Stream<Either<Failure, List<PresenceEntity>>> call(String roomId) {
    return _presenceRepository.subscribeToPresence(roomId: roomId);
  }
}
