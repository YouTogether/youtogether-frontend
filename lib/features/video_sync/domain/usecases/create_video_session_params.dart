import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/youtube_video_id.dart';

part 'create_video_session_params.freezed.dart';

/// Value object encapsulating the input required to create a room's
/// video session via `POST /rooms/:id/video-session`.
///
/// Declared `@freezed`, mirroring `UpdatePlaybackStateParams` and
/// `SetPresenceParams`.
///
/// [youtubeVideoId] is a [YoutubeVideoId], not a `String`. Typing it
/// this way means the use case cannot be handed unvalidated input:
/// parsing happens once, at the form boundary, and any failure is
/// reported to the user there rather than surfacing as an HTTP 400 four
/// layers away.
///
/// `addedBy` is deliberately absent, mirroring `CreateRoomParams` and
/// unlike the backend's own `CreateVideoSessionParams`: the backend
/// resolves the creator from the authenticated request, and sending a
/// client-supplied user id would be exactly the access-control mistake
/// `RoomController.create` documents avoiding. The room's leader is
/// likewise resolved server-side, from the room's persisted `ownerId`
/// (B-V03).
///
/// @see CreateVideoSessionUseCase
/// @see IVideoSessionRepository.create
@freezed
sealed class CreateVideoSessionParams with _$CreateVideoSessionParams {
  const factory CreateVideoSessionParams({
    required String roomId,
    required YoutubeVideoId youtubeVideoId,
  }) = _CreateVideoSessionParams;
}
