import 'package:freezed_annotation/freezed_annotation.dart';

part 'update_playback_state_params.freezed.dart';

/// Value object encapsulating the input required to write a new
/// playback state to Firebase.
///
/// Declared `@freezed`, mirroring `UpdateRoomParams`. Unlike
/// `UpdateRoomParams`, every field here is `required`: unlike a partial
/// room-metadata update, a playback state write always replaces the
/// entire `playback_state` node (see
/// `IVideoSyncRepository.updatePlaybackState`'s own doc comment on
/// "writes the full node") — there is no partial-update semantics to
/// support here.
///
/// `leaderId` is deliberately absent from this value object: unlike the
/// backend's `CreateVideoSessionParams.addedBy`, the leader-only write
/// check is enforced by `VideoSyncBloc` (via its own `isLeader` flag)
/// and by Firebase security rules directly against the authenticated
/// Firebase UID — not by anything this params object would carry.
///
/// @see UpdatePlaybackStateUseCase
/// @see IVideoSyncRepository.updatePlaybackState
@freezed
sealed class UpdatePlaybackStateParams with _$UpdatePlaybackStateParams {
  const factory UpdatePlaybackStateParams({
    required String roomId,
    required bool isPlaying,
    required Duration position,
  }) = _UpdatePlaybackStateParams;
}
