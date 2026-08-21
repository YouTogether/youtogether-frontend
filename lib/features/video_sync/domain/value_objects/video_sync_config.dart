/// Configurable synchronisation parameters.
///
/// Kept as `static const` values on a single class — no instance is
/// ever created — mirroring how `PlaybackTimestamp`'s bound is a plain
/// constructor argument rather than a magic number scattered across
/// call sites. Centralising these here means `SyncEngine`'s unit tests
/// exercise the exact same defaults production code uses, rather than
/// each site hardcoding its own copy.
abstract final class VideoSyncConfig {
  /// Maximum allowed drift before a corrective `seekTo` is issued.
  static const Duration syncDriftThreshold = Duration(milliseconds: 1500);

  /// Monitoring interval for timestamp-stagnation (ad) detection.
  static const Duration adDetectionInterval = Duration(milliseconds: 500);

  /// Minimum timestamp change to consider the player as progressing.
  static const Duration adDetectionMinDelta = Duration(milliseconds: 100);

  /// Maximum wait time for the ready gate before a force start.
  static const Duration readyGateTimeout = Duration(seconds: 20);

  /// Maximum wait for an ad to load before forcing content.
  static const Duration adLoadingTimeout = Duration(seconds: 10);

  /// Default offset compensating for network round-trip latency.
  static const Duration latencyOffset = Duration(milliseconds: 200);
}
