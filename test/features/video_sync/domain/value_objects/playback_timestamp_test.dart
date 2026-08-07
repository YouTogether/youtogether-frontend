import 'package:flutter_test/flutter_test.dart';
import 'package:youtogether/features/video_sync/domain/value_objects/playback_timestamp.dart';

/// Unit tests for [PlaybackTimestamp].
///
/// Mirrors the style of `room_entity_test.dart` for construction/equality,
/// with the added invariant coverage this value object exists for.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenario: seek rejected outside [0, duration].
void main() {
  group('PlaybackTimestamp', () {
    test('should construct when position is within [0, duration]', () {
      final timestamp = PlaybackTimestamp(
        position: const Duration(seconds: 30),
        duration: const Duration(seconds: 213),
      );

      expect(timestamp.position, const Duration(seconds: 30));
      expect(timestamp.duration, const Duration(seconds: 213));
    });

    test('should accept position exactly at zero', () {
      final timestamp = PlaybackTimestamp(
        position: Duration.zero,
        duration: const Duration(seconds: 213),
      );

      expect(timestamp.position, Duration.zero);
    });

    test('should accept position exactly at duration', () {
      final timestamp = PlaybackTimestamp(
        position: const Duration(seconds: 213),
        duration: const Duration(seconds: 213),
      );

      expect(timestamp.position, const Duration(seconds: 213));
    });

    test(
      'should throw ArgumentError when position is negative (VS-SYN-04)',
      () {
        expect(
          () => PlaybackTimestamp(
            position: const Duration(seconds: -1),
            duration: const Duration(seconds: 213),
          ),
          throwsArgumentError,
        );
      },
    );

    test(
      'should throw ArgumentError when position exceeds duration (VS-SYN-04)',
      () {
        expect(
          () => PlaybackTimestamp(
            position: const Duration(seconds: 214),
            duration: const Duration(seconds: 213),
          ),
          throwsArgumentError,
        );
      },
    );

    test('should support value equality', () {
      final a = PlaybackTimestamp(
        position: const Duration(seconds: 30),
        duration: const Duration(seconds: 213),
      );
      final b = PlaybackTimestamp(
        position: const Duration(seconds: 30),
        duration: const Duration(seconds: 213),
      );

      expect(a, b);
    });

    test('should not enforce the invariant via assert alone (release-mode '
        'safe)', () {
      // Regression guard: an earlier draft relied on `assert()`, which is
      // stripped in release builds. The explicit throw below must fire
      // regardless of build mode.
      expect(
        () => PlaybackTimestamp(
          position: const Duration(seconds: 9999),
          duration: const Duration(seconds: 213),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
