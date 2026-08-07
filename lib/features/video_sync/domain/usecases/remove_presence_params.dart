import 'package:freezed_annotation/freezed_annotation.dart';

part 'remove_presence_params.freezed.dart';

/// Value object encapsulating the input required to clear a presence
/// node on a graceful room exit.
///
/// Declared `@freezed`, mirroring `SetPresenceParams` (minus
/// `username`, which is not needed to clear a node keyed by `userId`
/// alone).
///
/// @see RemovePresenceUseCase
/// @see IPresenceRepository.removePresence
@freezed
sealed class RemovePresenceParams with _$RemovePresenceParams {
  const factory RemovePresenceParams({
    required String roomId,
    required String userId,
  }) = _RemovePresenceParams;
}
