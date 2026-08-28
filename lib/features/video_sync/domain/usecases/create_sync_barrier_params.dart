import 'package:freezed_annotation/freezed_annotation.dart';

part 'create_sync_barrier_params.freezed.dart';

/// Value object encapsulating the input required to open the ready gate.
///
/// Declared `@freezed`, mirroring `UpdatePlaybackStateParams`.
///
/// @see CreateSyncBarrierUseCase
@freezed
sealed class CreateSyncBarrierParams with _$CreateSyncBarrierParams {
  const factory CreateSyncBarrierParams({
    required String roomId,

    /// Content position every participant seeks to once the barrier
    /// resolves.
    required Duration targetTimestamp,

    /// Number of participants currently online, read from presence by
    /// the caller at the moment the barrier is opened.
    required int totalCount,
  }) = _CreateSyncBarrierParams;
}
