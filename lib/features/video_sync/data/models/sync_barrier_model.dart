import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/sync_barrier_entity.dart';

part 'sync_barrier_model.freezed.dart';

/// Data layer model for the `rooms/{room_id}/sync_barrier` Firebase
/// node, mirroring `VideoSessionModel`/`PresenceModel`'s conventions:
/// hand-written `fromSnapshot`/`toJson`, a `Map<Object?, Object?>` input
/// type forced by the Firebase SDK. Field names mirror
/// `YouTogether_Ad_Synchronisation_Strategy.docx`, Section 3.1 exactly:
/// `target_timestamp`, `ready_count`, `total_count`, `all_ready`.
@freezed
sealed class SyncBarrierModel with _$SyncBarrierModel {
  const SyncBarrierModel._();

  const factory SyncBarrierModel({
    required double targetTimestampSeconds,
    required int readyCount,
    required int totalCount,
    required bool allReady,
  }) = _SyncBarrierModel;

  factory SyncBarrierModel.fromSnapshot(Map<Object?, Object?> json) {
    return SyncBarrierModel(
      targetTimestampSeconds: (json['target_timestamp'] as num).toDouble(),
      readyCount: json['ready_count'] as int,
      totalCount: json['total_count'] as int,
      allReady: json['all_ready'] as bool,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'target_timestamp': targetTimestampSeconds,
      'ready_count': readyCount,
      'total_count': totalCount,
      'all_ready': allReady,
    };
  }

  SyncBarrierEntity toDomain() {
    return SyncBarrierEntity(
      targetTimestamp: Duration(
        milliseconds: (targetTimestampSeconds * 1000).round(),
      ),
      readyCount: readyCount,
      totalCount: totalCount,
      allReady: allReady,
    );
  }
}
