import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_barrier_entity.freezed.dart';

/// Domain entity for the `rooms/{room_id}/sync_barrier` Firebase node
/// — the ready-gate mechanism used exclusively during the initial playback
/// start sequence.
///
/// No participant identifiers are stored here, by design: readiness tracking is purely quantitative
/// (`readyCount`/`totalCount`), never a list of who is or isn't ready.
@freezed
sealed class SyncBarrierEntity with _$SyncBarrierEntity {
  const factory SyncBarrierEntity({
    /// Content position (not wall-clock time) all participants should
    /// seek to once the barrier resolves.
    required Duration targetTimestamp,

    /// Number of participants who have signalled they are past their
    /// pre-roll (or had none), incremented atomically.
    required int readyCount,

    /// Number of currently online participants, derived from the
    /// `presence` node — decreases automatically if a participant
    /// disconnects mid-barrier, which is exactly
    /// why this is read from `presence` rather than fixed at barrier
    /// creation time.
    required int totalCount,

    /// Set by the leader once `readyCount >= totalCount` (or forced
    /// after `readyGateTimeout`). Every client seeks to
    /// [targetTimestamp] and resumes playback once this becomes `true`.
    required bool allReady,
  }) = _SyncBarrierEntity;
}
