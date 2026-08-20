import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/update_playback_state_params.dart';
import '../../domain/usecases/update_playback_state_usecase.dart';
import '../../domain/value_objects/playback_timestamp.dart';
import 'video_sync_event.dart';
import 'video_sync_state.dart';

/// Bloc driving playback commands for a single room's video session.
///
/// Mirrors `RoomBloc` structurally (a `Bloc<Event, State>` wrapping use
/// cases per handled event), constructed fresh and scoped to one room,
/// mirroring how `RoomDetailCubit` is constructed fresh per
/// `RoomDetailPage` visit rather than registered as an app-wide
/// singleton.
///
/// ## Construction-time context, and the gap
/// [roomId], [isLeader], and [durationSeconds] are fixed for this
/// bloc's whole lifetime, passed at construction rather than resolved
/// from a `sessionJoined` event: `sessionJoined` (which will fetch the
/// current playback state via `GetCurrentPlaybackStateUseCase` and open
/// the live Firebase subscription) is not
/// yet implemented. Until that lands, [initialPosition] and
/// [initialIsPlaying] must be supplied by the caller from whatever
/// video-session data it already has — and as of this ticket, no
/// existing use case actually loads a room's video session on the
/// frontend at all (`GetRoomByIdUseCase`/`RoomEntity` carry no
/// `videoId`/`durationSeconds`/`leaderId` fields;
/// `POST /rooms/:id/video-session` response is never fetched back by
/// any frontend use case). That is a genuine backlog gap, not papered
/// over here: this bloc is complete and tested for the play/pause/seek
/// commands is scoped to, but wiring a real instance into
/// `RoomDetailView` needs a preceding ticket that fetches a room's
/// video session and exposes `durationSeconds`/`leaderId` to the
/// widget tree. Flagged rather than worked around with invented fields,
/// per this project's "no fabricated evidence" standard.
///
/// ## Leader-only gating
/// Every handler below checks [isLeader] first and returns without
/// emitting or calling [_updatePlaybackStateUseCase] at all when it is
/// `false` — this is the first of the two enforcement points named in
/// `YouTubePlayerWidget`'s own doc comment (native controls hidden);
/// `LeaderControls` (this same ticket) is the second, disabling its
/// buttons outright so a non-leader's tap never reaches this bloc in
/// the first place. Firebase security rules remain the actual
/// server-side authority — this and the disabled buttons are
/// defence in depth against a modified client, not the source of
/// truth.
class VideoSyncBloc extends Bloc<VideoSyncEvent, VideoSyncState> {
  VideoSyncBloc({
    required String roomId,
    required bool isLeader,
    required int durationSeconds,
    required UpdatePlaybackStateUseCase updatePlaybackStateUseCase,
    Duration initialPosition = Duration.zero,
    bool initialIsPlaying = false,
  }) : _roomId = roomId,
       _isLeader = isLeader,
       _durationSeconds = durationSeconds,
       _updatePlaybackStateUseCase = updatePlaybackStateUseCase,
       super(
         initialIsPlaying
             ? VideoSyncState.playing(position: initialPosition)
             : VideoSyncState.paused(position: initialPosition),
       ) {
    on<VideoSyncPlayRequested>(_onPlayRequested);
    on<VideoSyncPauseRequested>(_onPauseRequested);
    on<VideoSyncSeekRequested>(_onSeekRequested);
  }

  final String _roomId;
  final bool _isLeader;
  final int _durationSeconds;
  final UpdatePlaybackStateUseCase _updatePlaybackStateUseCase;

  Duration get _currentPosition => switch (state) {
    VideoSyncPlaying(:final position) => position,
    VideoSyncPaused(:final position) => position,
    VideoSyncReady(:final position) => position,
    VideoSyncInitial() ||
    VideoSyncLoading() ||
    VideoSyncFailure() => Duration.zero,
  };

  Future<void> _write({
    required bool isPlaying,
    required Duration position,
    required Emitter<VideoSyncState> emit,
  }) async {
    final result = await _updatePlaybackStateUseCase(
      UpdatePlaybackStateParams(
        roomId: _roomId,
        isPlaying: isPlaying,
        position: position,
      ),
    );

    result.fold((failure) => emit(VideoSyncState.failure(failure)), (_) {
      emit(
        isPlaying
            ? VideoSyncState.playing(position: position)
            : VideoSyncState.paused(position: position),
      );
    });
  }

  Future<void> _onPlayRequested(
    VideoSyncPlayRequested event,
    Emitter<VideoSyncState> emit,
  ) async {
    if (!_isLeader) return;
    await _write(isPlaying: true, position: _currentPosition, emit: emit);
  }

  Future<void> _onPauseRequested(
    VideoSyncPauseRequested event,
    Emitter<VideoSyncState> emit,
  ) async {
    if (!_isLeader) return;
    await _write(isPlaying: false, position: _currentPosition, emit: emit);
  }

  Future<void> _onSeekRequested(
    VideoSyncSeekRequested event,
    Emitter<VideoSyncState> emit,
  ) async {
    if (!_isLeader) return;

    final PlaybackTimestamp validated;
    try {
      validated = PlaybackTimestamp(
        position: event.target,
        duration: Duration(seconds: _durationSeconds),
      );
    } on ArgumentError {
      // VS-SYN-04: rejected client-side, no state change, no write.
      return;
    }

    final isPlaying = state is VideoSyncPlaying;
    await _write(
      isPlaying: isPlaying,
      position: validated.position,
      emit: emit,
    );
  }
}
