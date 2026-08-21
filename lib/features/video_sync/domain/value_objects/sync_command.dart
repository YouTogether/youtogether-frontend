import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_command.freezed.dart';

/// Output of `SyncEngine`'s reconciliation computation — a command the
/// presentation layer (`PlayerReconciliation`) executes against the
/// local player.
///
/// `pause`/`play` from the source document map onto this application's
/// existing leader-only `VideoSyncBloc.playRequested`/`pauseRequested`
/// handlers rather than a distinct command here — those are
/// leader actions, never something a viewer's own `SyncEngine`
/// evaluation would decide to do locally. Only the viewer-side
/// reconciliation commands are modelled on this type: `seekTo` (drift
/// correction or ad catch-up) and `wait` (withhold reconciliation while
/// an ad is believed to be playing). `resume` is the ready-gate's own
/// command, kept distinct from `seekTo` since it also signals "leave
/// the barrier-waiting state," which a plain drift-correction `seekTo`
/// does not.
@freezed
sealed class SyncCommand with _$SyncCommand {
  /// No corrective action needed — drift, if any, is within
  /// [VideoSyncConfig.syncDriftThreshold].
  const factory SyncCommand.none() = SyncCommandNone;

  /// Seek the local player to [target] to correct drift or catch up
  /// after an advertisement ends.
  const factory SyncCommand.seekTo(Duration target) = SyncCommandSeekTo;

  /// Withhold any reconciliation action: an advertisement is believed
  /// to be in progress (per `SyncEngine.detectAd`), so the leader's
  /// timestamp updates are stored but not applied until progression
  /// resumes.
  const factory SyncCommand.wait() = SyncCommandWait;

  /// The ready gate has resolved (`all_ready`, whether by every
  /// participant signalling readiness or by a leader-forced timeout):
  /// seek to [target] and resume playback.
  const factory SyncCommand.resume(Duration target) = SyncCommandResume;
}
