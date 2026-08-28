import 'package:freezed_annotation/freezed_annotation.dart';

part 'update_barrier_total_count_params.freezed.dart';

/// Value object encapsulating the input required to resize an open
/// ready gate.
///
/// @see UpdateBarrierTotalCountUseCase
@freezed
sealed class UpdateBarrierTotalCountParams
    with _$UpdateBarrierTotalCountParams {
  const factory UpdateBarrierTotalCountParams({
    required String roomId,
    required int totalCount,
  }) = _UpdateBarrierTotalCountParams;
}
