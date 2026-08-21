import 'dart:async';

import 'package:either_dart/either.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/video_session_entity.dart';
import '../../domain/usecases/get_current_playback_state_usecase.dart';
import '../../domain/usecases/get_video_session_usecase.dart';
import '../../domain/usecases/subscribe_to_playback_state_usecase.dart';
import '../../domain/usecases/update_playback_state_params.dart';
import '../../domain/usecases/update_playback_state_usecase.dart';
import '../../domain/value_objects/playback_timestamp.dart';
import 'video_sync_event.dart';
import 'video_sync_state.dart';

/// Bloc driving playback synchronisation for a single room's video
/// session.
///
/// Mirrors `RoomBloc` structurally, constructed fresh and scoped to one
/// room, mirroring how `RoomDetailCubit` is constructed fresh per
/// `RoomDetailPage` visit rather than registered as an app-wide
/// singleton.
///
/// ## Construction-time context (revised, F-V03-T2)
/// [roomId] and [currentUserId] are fixed for this bloc's whole
/// lifetime. Unlike the revision of this file, `isLeader` and
/// `durationSeconds` are **no longer constructor parameters** — they
/// are populated by [_onSessionJoined], derived from
/// [GetVideoSessionUseCase] (`durationSeconds`, from PostgreSQL via
/// `B-V02`) and [GetCurrentPlaybackStateUseCase] (`leaderId`, from
/// Firebase, compared against [currentUserId]). This closes the gap
/// flagged when first shipped `LeaderControls`/`VideoSyncBloc`
/// with no use case to supply that data — see
/// `sprint-3-videosync-frontend-commit-flow.md`, Task 7's gap note and
/// Task 8's reassignment.
///
/// ## sessionJoined sequencing
/// [_onSessionJoined] runs three steps in strict order:
/// 1. [GetVideoSessionUseCase] — the room's cached metadata
///    (`durationSeconds`, needed by every seek validated against
///    [PlaybackTimestamp]).
/// 2. [GetCurrentPlaybackStateUseCase] — a single Firebase read,
///    settling the bloc into [VideoSyncState.ready] with the position/
///    isPlaying the player should seek to on first paint, and deriving
///    `isLeader`.
/// 3. [SubscribeToPlaybackStateUseCase] — opens the live subscription
///    for ongoing updates, forwarded internally as
///    `VideoSyncEvent.sessionUpdated`.
///
/// A metadata or initial-fetch failure short-circuits the sequence
/// (steps 2/3, or 3, never run) and emits [VideoSyncState.failure]
/// directly.
///
/// ## Disconnect handling
/// A `Left(FirebaseFailure)` value forwarded via `sessionUpdated` (the
/// live subscription's own convention for surfacing a stream error as
/// a data event rather than an actual stream error — see
/// `VideoSyncRepositoryImpl.subscribeToPlaybackState`'s own doc
/// comment) emits [VideoSyncState.failure]. `SyncFailureBanner`
/// dispatches [VideoSyncEvent.retryRequested] to re-run the whole
/// `sessionJoined` sequence from scratch.
///
/// ## Leader-only gating
/// Unchanged from: every command handler checks `_isLeader`
/// first and returns without emitting or writing at all when it is
/// `false` — the first of the two enforcement points named in
/// `YouTubePlayerWidget`'s own doc comment; `LeaderControls` is the
/// second.
class VideoSyncBloc extends Bloc<VideoSyncEvent, VideoSyncState> {
  VideoSyncBloc({
    required String roomId,
    required String currentUserId,
    required GetVideoSessionUseCase getVideoSessionUseCase,
    required GetCurrentPlaybackStateUseCase getCurrentPlaybackStateUseCase,
    required SubscribeToPlaybackStateUseCase subscribeToPlaybackStateUseCase,
    required UpdatePlaybackStateUseCase updatePlaybackStateUseCase,
  }) : _roomId = roomId,
       _currentUserId = currentUserId,
       _getVideoSessionUseCase = getVideoSessionUseCase,
       _getCurrentPlaybackStateUseCase = getCurrentPlaybackStateUseCase,
       _subscribeToPlaybackStateUseCase = subscribeToPlaybackStateUseCase,
       _updatePlaybackStateUseCase = updatePlaybackStateUseCase,
       super(const VideoSyncState.initial()) {
    on<VideoSyncSessionJoined>(_onSessionJoined);
    on<VideoSyncSessionUpdated>(_onSessionUpdated);
    on<VideoSyncRetryRequested>(_onRetryRequested);
    on<VideoSyncPlayRequested>(_onPlayRequested);
    on<VideoSyncPauseRequested>(_onPauseRequested);
    on<VideoSyncSeekRequested>(_onSeekRequested);
    on<VideoSyncAdDetected>(_onAdDetected);
    on<VideoSyncAdEnded>(_onAdEnded);
  }

  final String _roomId;
  final String _currentUserId;
  final GetVideoSessionUseCase _getVideoSessionUseCase;
  final GetCurrentPlaybackStateUseCase _getCurrentPlaybackStateUseCase;
  final SubscribeToPlaybackStateUseCase _subscribeToPlaybackStateUseCase;
  final UpdatePlaybackStateUseCase _updatePlaybackStateUseCase;

  bool _isLeader = false;
  int _durationSeconds = 0;
  String _youtubeVideoId = '';
  StreamSubscription<Either<Failure, VideoSessionEntity>>? _liveSubscription;

  /// The most recent session received via `sessionUpdated`, kept so
  /// `_onAdEnded` (F-V04) can re-emit the correct playing/paused state
  /// once an advertisement is believed to have ended, and so
  /// `PlayerReconciliation` can read it (via [lastKnownSession]) to
  /// compute the expected catch-up position through
  /// `SyncEngine.computeExpectedPosition`.
  VideoSessionEntity? _lastKnownSession;

  /// Exposes the last session received via the live Firebase
  /// subscription, for `PlayerReconciliation` to compute drift/ad
  /// catch-up against. `null` before the first `sessionUpdated` event
  /// arrives.
  VideoSessionEntity? get lastKnownSession => _lastKnownSession;

  /// Whether the current user is this room's leader, derived by
  /// [_onSessionJoined]. `false` before the first successful
  /// `sessionJoined`/`retryRequested` completes.
  ///
  /// Exposed as a plain getter rather than part of [VideoSyncState]:
  /// `RoomDetailView` needs this,
  /// `_durationSeconds`, and `_youtubeVideoId` to construct
  /// `LeaderControls`/`YouTubePlayerWidget`, but none of the three ever
  /// changes independently of a full `VideoSyncState` transition
  /// (`ready`, at minimum, always precedes any state that depends on
  /// them) — so a `BlocBuilder` already rebuilds at the right time
  /// without these needing to be state fields of their own.
  bool get isLeader => _isLeader;

  /// This session's total video duration in seconds, fetched via
  /// [GetVideoSessionUseCase]. `0` before the first successful
  /// `sessionJoined`/`retryRequested` completes.
  int get durationSeconds => _durationSeconds;

  /// The YouTube video id currently loaded, from Firebase's live copy
  /// (see this class's own top-level doc comment for why Firebase's
  /// copy is preferred over the REST-cached one once both are known).
  /// Empty before the first successful `sessionJoined`/`retryRequested`
  /// completes.
  String get youtubeVideoId => _youtubeVideoId;

  Duration get _currentPosition => switch (state) {
    VideoSyncPlaying(:final position) => position,
    VideoSyncPaused(:final position) => position,
    VideoSyncReady(:final position) => position,
    VideoSyncInitial() ||
    VideoSyncLoading() ||
    VideoSyncFailure() ||
    VideoSyncAdInProgress() ||
    VideoSyncBarrierWaiting() =>
      _lastKnownSession?.currentPosition ?? Duration.zero,
  };

  Future<void> _onSessionJoined(
    VideoSyncSessionJoined event,
    Emitter<VideoSyncState> emit,
  ) {
    return _performSessionJoin(emit);
  }

  Future<void> _performSessionJoin(Emitter<VideoSyncState> emit) async {
    emit(const VideoSyncState.loading());

    final metadataResult = await _getVideoSessionUseCase(_roomId);
    if (metadataResult.isLeft) {
      emit(VideoSyncState.failure(metadataResult.left));
      return;
    }
    _durationSeconds = metadataResult.right.durationSeconds;

    final initialStateResult = await _getCurrentPlaybackStateUseCase(_roomId);
    if (initialStateResult.isLeft) {
      emit(VideoSyncState.failure(initialStateResult.left));
      return;
    }
    final initialSession = initialStateResult.right;
    _isLeader = initialSession.leaderId == _currentUserId;
    _youtubeVideoId = initialSession.youtubeVideoId;

    emit(
      VideoSyncState.ready(
        position: initialSession.currentPosition,
        isPlaying: initialSession.isPlaying,
      ),
    );

    await _liveSubscription?.cancel();
    _liveSubscription = _subscribeToPlaybackStateUseCase(_roomId).listen((
      result,
    ) {
      add(VideoSyncEvent.sessionUpdated(result));
    });
  }

  Future<void> _onSessionUpdated(
    VideoSyncSessionUpdated event,
    Emitter<VideoSyncState> emit,
  ) async {
    event.result.fold((failure) => emit(VideoSyncState.failure(failure)), (
      session,
    ) {
      _lastKnownSession = session;
      emit(
        session.isPlaying
            ? VideoSyncState.playing(position: session.currentPosition)
            : VideoSyncState.paused(position: session.currentPosition),
      );
    });
  }

  Future<void> _onAdDetected(
    VideoSyncAdDetected event,
    Emitter<VideoSyncState> emit,
  ) async {
    emit(const VideoSyncState.adInProgress());
  }

  Future<void> _onAdEnded(
    VideoSyncAdEnded event,
    Emitter<VideoSyncState> emit,
  ) async {
    final session = _lastKnownSession;
    if (session == null) return;

    emit(
      session.isPlaying
          ? VideoSyncState.playing(position: session.currentPosition)
          : VideoSyncState.paused(position: session.currentPosition),
    );
  }

  Future<void> _onRetryRequested(
    VideoSyncRetryRequested event,
    Emitter<VideoSyncState> emit,
  ) {
    return _performSessionJoin(emit);
  }

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

  @override
  Future<void> close() async {
    await _liveSubscription?.cancel();
    return super.close();
  }
}
