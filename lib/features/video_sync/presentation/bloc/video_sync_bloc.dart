import 'dart:async';

import 'package:either_dart/either.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/presence_entity.dart';
import '../../domain/entities/sync_barrier_entity.dart';
import '../../domain/entities/video_session_entity.dart';
import '../../domain/repositories/i_presence_repository.dart';
import '../../domain/repositories/i_sync_barrier_repository.dart';
import '../../domain/services/sync_engine.dart';
import '../../domain/value_objects/ready_gate_result.dart';
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
    required ISyncBarrierRepository syncBarrierRepository,
    required IPresenceRepository presenceRepository,
    SyncEngine? syncEngine,
  }) : _roomId = roomId,
       _currentUserId = currentUserId,
       _getVideoSessionUseCase = getVideoSessionUseCase,
       _getCurrentPlaybackStateUseCase = getCurrentPlaybackStateUseCase,
       _subscribeToPlaybackStateUseCase = subscribeToPlaybackStateUseCase,
       _updatePlaybackStateUseCase = updatePlaybackStateUseCase,
       _syncBarrierRepository = syncBarrierRepository,
       _presenceRepository = presenceRepository,
       _syncEngine = syncEngine ?? SyncEngine(),
       super(const VideoSyncState.initial()) {
    on<VideoSyncSessionJoined>(_onSessionJoined);
    on<VideoSyncSessionUpdated>(_onSessionUpdated);
    on<VideoSyncRetryRequested>(_onRetryRequested);
    on<VideoSyncPlayRequested>(_onPlayRequested);
    on<VideoSyncPauseRequested>(_onPauseRequested);
    on<VideoSyncSeekRequested>(_onSeekRequested);
    on<VideoSyncAdDetected>(_onAdDetected);
    on<VideoSyncAdEnded>(_onAdEnded);
    on<VideoSyncBarrierUpdated>(_onBarrierUpdated);
    on<VideoSyncPresenceCountUpdated>(_onPresenceCountUpdated);
    on<VideoSyncReadySignalled>(_onReadySignalled);
    on<VideoSyncForceStartRequested>(_onForceStartRequested);
  }

  final String _roomId;
  final String _currentUserId;
  final GetVideoSessionUseCase _getVideoSessionUseCase;
  final GetCurrentPlaybackStateUseCase _getCurrentPlaybackStateUseCase;
  final SubscribeToPlaybackStateUseCase _subscribeToPlaybackStateUseCase;
  final UpdatePlaybackStateUseCase _updatePlaybackStateUseCase;
  final ISyncBarrierRepository _syncBarrierRepository;
  final IPresenceRepository _presenceRepository;
  final SyncEngine _syncEngine;

  bool _isLeader = false;
  int _durationSeconds = 0;
  String _youtubeVideoId = '';
  StreamSubscription<Either<Failure, VideoSessionEntity>>? _liveSubscription;
  StreamSubscription<Either<Failure, SyncBarrierEntity>>? _barrierSubscription;
  StreamSubscription<Either<Failure, List<PresenceEntity>>>?
  _presenceSubscription;

  /// When the currently open barrier was created, for
  /// [SyncEngine.evaluateReadyGate]'s timeout comparison. `null`
  /// whenever no barrier is open.
  DateTime? _barrierCreatedAt;

  /// Whether the room's initial collective start has already happened.
  ///
  /// The ready gate is used **only** for that first start — per
  /// `YouTogether_Ad_Synchronisation_Strategy.docx`, Section 7.3
  /// ("No ready gate is triggered for late joins; the gate is only used
  /// for the initial collective start"). Every subsequent
  /// play/pause/seek is an ordinary direct Firebase write, so this flag
  /// is what keeps a mid-session pause-then-play from re-opening a
  /// barrier and making every participant wait again.
  bool _initialStartDone = false;

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

  /// Actual `sessionJoined` sequencing logic (see this class's own doc
  /// comment), extracted from [_onSessionJoined] so [_onRetryRequested]
  /// can re-run it without constructing a `VideoSyncSessionJoined`
  /// instance to pass around.
  ///
  /// A freezed sealed union's generative factory constructor
  /// (`VideoSyncEvent.sessionJoined()`) has the *supertype*
  /// `VideoSyncEvent` as its static return type, even though the
  /// runtime object is a `VideoSyncSessionJoined` — passing it to a
  /// function whose parameter type is the narrower
  /// `VideoSyncSessionJoined` therefore fails static type checking
  /// (`flutter analyze`: `argument_type_not_assignable`), regardless of
  /// what the object actually is at runtime. Neither `on<E>()`'s own
  /// handler signature (which must accept exactly
  /// `VideoSyncSessionJoined` to type-check against
  /// `on<VideoSyncSessionJoined>(...)`) nor a runtime cast are the
  /// right fix — extracting the shared body to a method with no event
  /// parameter at all removes the mismatch entirely, since neither
  /// caller actually reads any field off the event.
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

    if (!_initialStartDone) {
      await _startReadyGate(emit);
      return;
    }

    await _write(isPlaying: true, position: _currentPosition, emit: emit);
  }

  /// Opens the ready gate for the room's initial collective start.
  ///
  /// The online-participant count is taken from the *first* value the
  /// presence stream yields, rather than from a separate one-shot read:
  /// `IPresenceRepository` exposes no one-shot count method, and the
  /// same subscription is needed anyway to keep `total_count` current
  /// while the barrier is open — so opening it once and using
  /// its first value serves both purposes without a redundant read.
  Future<void> _startReadyGate(Emitter<VideoSyncState> emit) async {
    final target = _currentPosition;

    final firstPresence = await _presenceRepository
        .subscribeToPresence(roomId: _roomId)
        .first;
    if (firstPresence.isLeft) {
      emit(VideoSyncState.failure(firstPresence.left));
      return;
    }
    final totalCount = firstPresence.right.where((p) => p.isOnline).length;

    final created = await _syncBarrierRepository.createBarrier(
      roomId: _roomId,
      targetTimestamp: target,
      totalCount: totalCount,
    );
    if (created.isLeft) {
      emit(VideoSyncState.failure(created.left));
      return;
    }

    _barrierCreatedAt = DateTime.now().toUtc();
    emit(VideoSyncState.barrierWaiting(readyCount: 0, totalCount: totalCount));

    await _barrierSubscription?.cancel();
    _barrierSubscription = _syncBarrierRepository
        .subscribeToBarrier(roomId: _roomId)
        .listen((result) => add(VideoSyncEvent.barrierUpdated(result)));

    await _presenceSubscription?.cancel();
    _presenceSubscription = _presenceRepository
        .subscribeToPresence(roomId: _roomId)
        .listen((result) {
          if (result.isRight) {
            add(
              VideoSyncEvent.presenceCountUpdated(
                result.right.where((p) => p.isOnline).length,
              ),
            );
          }
        });
  }

  Future<void> _onBarrierUpdated(
    VideoSyncBarrierUpdated event,
    Emitter<VideoSyncState> emit,
  ) async {
    if (event.result.isLeft) {
      emit(VideoSyncState.failure(event.result.left));
      return;
    }
    final barrier = event.result.right;

    if (barrier.allReady) {
      // Section 4.1, step 5: every participant (leader included) seeks
      // to the target and resumes. The seek itself is
      // PlayerReconciliation's job, driven by this state transition —
      // this handler only settles the bloc's own state and, on the
      // leader, tidies up.
      _initialStartDone = true;
      _barrierCreatedAt = null;
      await _barrierSubscription?.cancel();
      _barrierSubscription = null;
      await _presenceSubscription?.cancel();
      _presenceSubscription = null;

      emit(VideoSyncState.playing(position: barrier.targetTimestamp));

      if (_isLeader) {
        // Step 6, then the actual playback_state write that every
        // viewer's own live subscription reacts to. Ordering matters:
        // the barrier is deleted first so a late-arriving barrier event
        // cannot re-trigger this branch after the write.
        await _syncBarrierRepository.deleteBarrier(roomId: _roomId);
        await _updatePlaybackStateUseCase(
          UpdatePlaybackStateParams(
            roomId: _roomId,
            isPlaying: true,
            position: barrier.targetTimestamp,
          ),
        );
      }
      return;
    }

    emit(
      VideoSyncState.barrierWaiting(
        readyCount: barrier.readyCount,
        totalCount: barrier.totalCount,
      ),
    );

    if (!_isLeader) return;

    final gate = _syncEngine.evaluateReadyGate(
      readyCount: barrier.readyCount,
      totalCount: barrier.totalCount,
      elapsedSinceCreated: _barrierCreatedAt == null
          ? Duration.zero
          : DateTime.now().toUtc().difference(_barrierCreatedAt!),
    );

    // Only `allReady` acts automatically. `timedOut` deliberately does
    // not force-start on its own: Section 4.2 specifies the leader is
    // *offered* the choice ("the leader may force-start"), with the UI
    // showing current readiness — auto-forcing would take that decision
    // away. `VideoSyncEvent.forceStartRequested` is the leader's own
    // opt-in.
    if (gate == ReadyGateResult.allReady) {
      await _syncBarrierRepository.setAllReady(roomId: _roomId);
    }
  }

  Future<void> _onPresenceCountUpdated(
    VideoSyncPresenceCountUpdated event,
    Emitter<VideoSyncState> emit,
  ) async {
    // Section 4.1, step 4 — leader-only, and only while a barrier is
    // actually open.
    if (!_isLeader || _barrierCreatedAt == null) return;

    await _syncBarrierRepository.updateTotalCount(
      roomId: _roomId,
      totalCount: event.onlineCount,
    );
  }

  Future<void> _onReadySignalled(
    VideoSyncReadySignalled event,
    Emitter<VideoSyncState> emit,
  ) async {
    // Section 4.1, step 3 — every participant signals its own
    // readiness, leader included; this is deliberately not
    // leader-gated.
    if (_barrierCreatedAt == null && state is! VideoSyncBarrierWaiting) return;

    await _syncBarrierRepository.incrementReadyCount(roomId: _roomId);
  }

  Future<void> _onForceStartRequested(
    VideoSyncForceStartRequested event,
    Emitter<VideoSyncState> emit,
  ) async {
    if (!_isLeader) return;

    await _syncBarrierRepository.setAllReady(roomId: _roomId);
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
    await _barrierSubscription?.cancel();
    await _presenceSubscription?.cancel();
    return super.close();
  }
}
