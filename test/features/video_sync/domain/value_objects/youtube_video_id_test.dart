import 'package:flutter_test/flutter_test.dart';
import 'package:youtogether/features/video_sync/domain/value_objects/youtube_video_id.dart';

/// Unit tests for [YoutubeVideoId].
///
/// Mirrors the style of `playback_timestamp_test.dart`: construction,
/// equality, and full coverage of the invariant the value object exists
/// to enforce.
///
/// The rejection cases matter as much as the acceptance ones. This is
/// the first of five validation layers for the same 11-character format
/// (client, DTO, backend use case, database CHECK, security rules), and
/// its specific job is to stop malformed input before a network request
/// is issued.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios VS-ADD-01, VS-ADD-02.
void main() {
  const validId = 'dQw4w9WgXcQ';

  group('YoutubeVideoId.parse — bare id', () {
    test('should accept an 11-character id', () {
      expect(YoutubeVideoId.parse(validId).value, validId);
    });

    test('should accept ids containing hyphens and underscores', () {
      expect(YoutubeVideoId.parse('a-b_c-d_e-f').value, 'a-b_c-d_e-f');
    });

    test('should trim surrounding whitespace', () {
      expect(YoutubeVideoId.parse('  $validId \n').value, validId);
    });
  });

  group('YoutubeVideoId.parse — URL forms', () {
    test('should extract the id from a standard watch URL', () {
      expect(
        YoutubeVideoId.parse('https://www.youtube.com/watch?v=$validId').value,
        validId,
      );
    });

    test('should ignore additional query parameters such as a timestamp', () {
      expect(
        YoutubeVideoId.parse(
          'https://www.youtube.com/watch?v=$validId&t=42s&list=PL123',
        ).value,
        validId,
      );
    });

    test('should extract the id from a youtu.be short link', () {
      expect(YoutubeVideoId.parse('https://youtu.be/$validId').value, validId);
    });

    test('should extract the id from a youtu.be link carrying a timestamp', () {
      expect(
        YoutubeVideoId.parse('https://youtu.be/$validId?t=42').value,
        validId,
      );
    });

    test('should extract the id from an embed URL', () {
      expect(
        YoutubeVideoId.parse('https://www.youtube.com/embed/$validId').value,
        validId,
      );
    });

    test('should extract the id from a shorts URL', () {
      expect(
        YoutubeVideoId.parse('https://www.youtube.com/shorts/$validId').value,
        validId,
      );
    });

    test('should accept the mobile host', () {
      expect(
        YoutubeVideoId.parse('https://m.youtube.com/watch?v=$validId').value,
        validId,
      );
    });

    test('should accept a bare youtube.com host with no subdomain', () {
      expect(
        YoutubeVideoId.parse('https://youtube.com/watch?v=$validId').value,
        validId,
      );
    });

    test('should accept http as well as https', () {
      expect(
        YoutubeVideoId.parse('http://www.youtube.com/watch?v=$validId').value,
        validId,
      );
    });
  });

  group('YoutubeVideoId.parse — rejected input (VS-ADD-02)', () {
    test('should reject an empty string', () {
      expect(() => YoutubeVideoId.parse(''), throwsArgumentError);
    });

    test('should reject whitespace only', () {
      expect(() => YoutubeVideoId.parse('   '), throwsArgumentError);
    });

    test('should reject an id shorter than 11 characters', () {
      expect(() => YoutubeVideoId.parse('dQw4w9WgX'), throwsArgumentError);
    });

    test('should reject an id longer than 11 characters', () {
      expect(() => YoutubeVideoId.parse('dQw4w9WgXcQQ'), throwsArgumentError);
    });

    test('should reject an id containing characters outside the alphabet', () {
      expect(() => YoutubeVideoId.parse('dQw4w9WgXc!'), throwsArgumentError);
    });

    test('should reject a URL on a host outside the allowlist', () {
      // A general-purpose query-string reader would accept this. The
      // host allowlist is what keeps the parser from doing so.
      expect(
        () => YoutubeVideoId.parse('https://evil.example.com/watch?v=$validId'),
        throwsArgumentError,
      );
    });

    test('should reject a lookalike host', () {
      expect(
        () => YoutubeVideoId.parse(
          'https://youtube.com.evil.net/watch?v=$validId',
        ),
        throwsArgumentError,
      );
    });

    test('should reject a YouTube URL carrying no video id', () {
      expect(
        () =>
            YoutubeVideoId.parse('https://www.youtube.com/feed/subscriptions'),
        throwsArgumentError,
      );
    });

    test('should reject a YouTube URL whose v parameter is malformed', () {
      expect(
        () => YoutubeVideoId.parse('https://www.youtube.com/watch?v=tooshort'),
        throwsArgumentError,
      );
    });

    test('should reject a schemeless URL', () {
      // Documented limitation rather than an oversight: without a
      // scheme there is no host to check against the allowlist. The
      // form's helper text tells the user to paste the full link.
      expect(
        () => YoutubeVideoId.parse('youtu.be/$validId'),
        throwsArgumentError,
      );
    });

    test('should report the original input in the thrown error', () {
      expect(
        () => YoutubeVideoId.parse('not a video'),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.invalidValue,
            'invalidValue',
            'not a video',
          ),
        ),
      );
    });
  });

  group('YoutubeVideoId — value semantics', () {
    test('should support value equality', () {
      expect(YoutubeVideoId.parse(validId), YoutubeVideoId.parse(validId));
    });

    test('should treat a bare id and its watch URL as equal', () {
      expect(
        YoutubeVideoId.parse('https://www.youtube.com/watch?v=$validId'),
        YoutubeVideoId.parse(validId),
      );
    });

    test('should not be equal to a different id', () {
      expect(
        YoutubeVideoId.parse(validId),
        isNot(YoutubeVideoId.parse('a-b_c-d_e-f')),
      );
    });

    test('should render as the bare id', () {
      expect(YoutubeVideoId.parse(validId).toString(), validId);
    });
  });
}
