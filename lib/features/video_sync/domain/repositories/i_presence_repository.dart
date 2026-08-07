import 'package:either_dart/either.dart';

import '../../../../core/error/failures.dart';
import '../entities/presence_entity.dart';

/// Domain port for the Video Synchronisation bounded context's presence
/// tracking, backed exclusively by Firebase (`rooms/{room_id}/presence`).
///
/// Mirrors `IVideoSyncRepository` in spirit and shares its
/// Firebase-only failure surface ([FirebaseFailure]); kept as a
/// separate interface rather than folded into `IVideoSyncRepository`
/// since presence and playback state are independent Firebase nodes
/// with independent lifecycles (a user's presence outlives any single
/// video session in the room).
///
/// @see PresenceRemoteDataSourceImpl — the data-layer implementation
abstract class IPresenceRepository {
  /// Writes this participant's presence node on room entry, setting
  /// `is_online: true`. The data layer additionally registers Firebase's
  /// `onDisconnect` handler at this point so that presence is
  /// cleared automatically even if [removePresence] is never called
  /// (app crash, network loss).
  Future<Either<Failure, void>> setPresence({
    required String roomId,
    required String userId,
    required String username,
  });

  /// Clears this participant's presence node on an explicit, graceful
  /// room exit.
  Future<Either<Failure, void>> removePresence({
    required String roomId,
    required String userId,
  });

  /// Returns a live stream of every participant currently present in
  /// [roomId].
  Stream<Either<Failure, List<PresenceEntity>>> subscribeToPresence({
    required String roomId,
  });
}
