import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/presence_entity.dart';

part 'presence_state.freezed.dart';

/// State hierarchy for [PresenceCubit].
///
/// Declared `@freezed` as a sealed union, mirroring `RoomDetailState`.
@freezed
sealed class PresenceState with _$PresenceState {
  /// The participant has not entered the broadcast session yet.
  const factory PresenceState.initial() = PresenceInitial;

  /// Presence has been written and the live subscription is opening,
  /// but no participant list has arrived yet.
  const factory PresenceState.loading() = PresenceLoading;

  /// Live participant list for this room.
  ///
  /// [participants] contains everyone currently watching — **not**
  /// everyone who has ever joined the room. An empty list (count `0`)
  /// is a valid, expected state, not an error or an "unknown" placeholder:
  /// a room with fifty registered members has zero participants when
  /// nobody has the player open. See [PresenceCubit]'s own doc comment
  /// for why this is deliberately never reconciled against the
  /// Postgres-sourced membership count.
  const factory PresenceState.loaded(List<PresenceEntity> participants) =
      PresenceLoaded;

  /// Writing presence or reading the live list failed.
  const factory PresenceState.failure(Failure failure) = PresenceFailure;
}
