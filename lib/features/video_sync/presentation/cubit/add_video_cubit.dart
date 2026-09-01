import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/create_video_session_params.dart';
import '../../domain/usecases/create_video_session_usecase.dart';
import '../../domain/value_objects/youtube_video_id.dart';
import 'add_video_state.dart';

/// Cubit orchestrating the video session creation request lifecycle.
///
/// Mirrors `JoinRoomCubit` in structure: emit `submitting`, delegate to
/// the use case, fold the result into `success` or `failure`.
///
/// Scoped to a single room's page and constructed by `RoomDetailPage`,
/// not registered in the service locator — same treatment as
/// `RoomDetailCubit`, `JoinRoomCubit` and `LeaveRoomCubit`, and for the
/// same reason: its lifetime is the visit, not the process.
///
/// ## Not this cubit's concerns
/// - **Input validation.** [submit] takes a [YoutubeVideoId], so an
///   unvalidated string cannot reach it. `AddVideoForm`'s field
///   validator is where malformed input is caught and reported.
/// - **Ownership.** `OwnershipGuard` enforces it server-side; the form
///   is only rendered for the owner as defence in depth. A request that
///   somehow reaches here for a non-owner resolves to
///   `Left(AuthFailure)` and is surfaced like any other failure.
/// - **Refreshing the player.** On success, `AddVideoForm` dispatches
///   `VideoSyncEvent.sessionJoined` so the bloc re-runs its own
///   sequence. This cubit does not talk to `VideoSyncBloc`: keeping the
///   two independent is what lets each be tested without the other.
///   The re-run is safe to trigger immediately because the backend has
///   already written the room's `playback_state` node by the time the
///   response arrives.
///
/// @see CreateVideoSessionUseCase — the delegated domain operation
class AddVideoCubit extends Cubit<AddVideoState> {
  AddVideoCubit(this._createVideoSessionUseCase)
    : super(const AddVideoState.initial());

  final CreateVideoSessionUseCase _createVideoSessionUseCase;

  /// Creates the room's video session from an already-validated
  /// [youtubeVideoId].
  Future<void> submit({
    required String roomId,
    required YoutubeVideoId youtubeVideoId,
  }) async {
    emit(const AddVideoState.submitting());

    final result = await _createVideoSessionUseCase(
      CreateVideoSessionParams(roomId: roomId, youtubeVideoId: youtubeVideoId),
    );

    result.fold(
      (failure) => emit(AddVideoState.failure(failure)),
      (session) => emit(AddVideoState.success(session)),
    );
  }
}
