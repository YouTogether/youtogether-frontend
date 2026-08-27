/// Outcome of `SyncEngine.evaluateReadyGate`, mirroring the
/// `sync_barrier` node's own state machine.
enum ReadyGateResult {
  /// Not every online participant has signalled readiness yet, and the
  /// configured timeout has not elapsed.
  waiting,

  /// `readyCount >= totalCount`: every online participant is past their
  /// pre-roll (or had none). The leader should set `all_ready = true`.
  allReady,

  /// The configured timeout elapsed before every participant signalled
  /// readiness. The leader may force-start playback regardless of the
  /// current `readyCount` — participants still mid-ad catch up via the
  /// ordinary mid-roll recovery logic.
  timedOut,
}
