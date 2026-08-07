import 'package:freezed_annotation/freezed_annotation.dart';

part 'set_presence_params.freezed.dart';

/// Value object encapsulating the input required to write a presence
/// node on room entry.
///
/// Declared `@freezed`, mirroring `UpdatePlaybackStateParams`.
///
/// @see SetPresenceUseCase
/// @see IPresenceRepository.setPresence
@freezed
sealed class SetPresenceParams with _$SetPresenceParams {
  const factory SetPresenceParams({
    required String roomId,
    required String userId,
    required String username,
  }) = _SetPresenceParams;
}
