import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/video_session_metadata_entity.dart';

part 'add_video_state.freezed.dart';

/// State hierarchy for [AddVideoCubit].
///
/// Declared `@freezed` as a sealed union, mirroring `JoinRoomState` and
/// `LeaveRoomState`.
///
/// There is deliberately no `invalidInput` variant. Malformed input is
/// rejected by `AddVideoForm`'s own field validator, which constructs a
/// [YoutubeVideoId] and reports the failure inline on the field —
/// no cubit involvement, no state transition, and no network call. By
/// the time [AddVideoCubit.submit] runs, the id is already a validated
/// value object, so every state below describes the *request*, never
/// the input.
///
/// [success] carries the created session's metadata even though
/// `AddVideoForm` only uses it as a signal to dispatch
/// `VideoSyncEvent.sessionJoined`. Discarding it would make the cubit
/// untestable on the one property that matters most — that the backend
/// really created the session it reports — and the entity is already in
/// hand.
@freezed
sealed class AddVideoState with _$AddVideoState {
  const factory AddVideoState.initial() = AddVideoInitial;
  const factory AddVideoState.submitting() = AddVideoSubmitting;
  const factory AddVideoState.success(VideoSessionMetadataEntity session) =
      AddVideoSuccess;
  const factory AddVideoState.failure(Failure failure) = AddVideoFailure;
}
