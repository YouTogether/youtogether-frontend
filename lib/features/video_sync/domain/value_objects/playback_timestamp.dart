import 'package:equatable/equatable.dart';

/// Value object pairing a playback [position] with the video's total
/// [duration], enforcing the invariant that a valid position always
/// falls within `[0, duration]`.
///
/// Declared as a plain [Equatable] class rather than `@freezed`: the
/// invariant must be enforced by an explicit constructor-body check,
/// not by an `assert()` (asserts are stripped from release builds —
/// see the regression test guarding against exactly that mistake), and
/// freezed's generated constructors do not offer a body to run such a
/// check in.
///
/// This is the frontend's client-side mirror of the backend's database
/// CHECK constraint semantics (`video_sessions.duration_seconds > 0`)
/// combined with the seek-specific rule from the data model's business
/// invariants ("a seek operation is only valid if the target timestamp
/// is within [0, duration_seconds]") — defence in depth, not
/// redundancy: `VideoSyncBloc.seek` constructs this value object before
/// ever calling [UpdatePlaybackStateUseCase], so an invalid seek never
/// reaches the repository, let alone Firebase.
///
/// @see CHECK constraint on the equivalent backend column
/// @competency Evolvable, secure domain modelling
class PlaybackTimestamp extends Equatable {
  /// Constructs a [PlaybackTimestamp], throwing [ArgumentError] if
  /// [position] falls outside `[0, duration]`.
  PlaybackTimestamp({required this.position, required this.duration}) {
    if (position < Duration.zero || position > duration) {
      throw ArgumentError.value(
        position,
        'position',
        'must be within [Duration.zero, duration] (duration: $duration)',
      );
    }
  }

  /// The playback position being validated.
  final Duration position;

  /// The video's total duration, defining the upper bound of the
  /// invariant.
  final Duration duration;

  @override
  List<Object?> get props => [position, duration];
}
