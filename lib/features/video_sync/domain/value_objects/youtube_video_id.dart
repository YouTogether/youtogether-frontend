import 'package:equatable/equatable.dart';

/// Value object holding a validated YouTube video id, parsed from
/// either a bare id or one of the URL forms a user is likely to paste.
///
/// Declared as a plain [Equatable] class rather than `@freezed`, for
/// the same reason as [PlaybackTimestamp]: the invariant is enforced by
/// an explicit throw in a factory constructor, and freezed's generated
/// constructors provide no body to run such a check in. `assert()` is
/// not an option either — it is stripped from release builds, which is
/// precisely where malformed input arrives.
///
/// ## Why a value object and not a `String`
/// The 11-character format is validated in four places: this class, the
/// backend's `CreateVideoSessionDto` (`@Matches`), the backend's
/// `CreateVideoSessionUseCase`, and the `video_sessions` table's CHECK
/// constraint — with the Realtime Database security rules adding a
/// fifth once B-A06 lands. That is defence in depth, not redundancy to
/// collapse: each layer protects a different set of callers.
///
/// This layer's specific contribution is that no network request is
/// ever issued for input that cannot be a video id, and that
/// [CreateVideoSessionParams] can only be constructed around an
/// already-validated id — an unparsed `String` cannot reach the use
/// case at all.
///
/// ## Accepted input
/// - A bare id: `dQw4w9WgXcQ`
/// - `https://www.youtube.com/watch?v=<id>` (any additional query
///   parameters, such as `&t=42s`, are ignored)
/// - `https://youtu.be/<id>`
/// - `https://www.youtube.com/embed/<id>`, `/shorts/<id>`, `/live/<id>`
/// - Any of the above on `youtube.com`, `www.`, `m.` or `music.`
///
/// Surrounding whitespace is trimmed. A scheme is required for URL
/// forms: `youtu.be/<id>` without `https://` parses as a relative path
/// with no host and is rejected, which the form field's helper text
/// should make clear.
///
/// The host allowlist is deliberate. Extracting a `v=` parameter from
/// an arbitrary host would turn this parser into a general-purpose
/// query-string reader, accepting input that merely resembles a YouTube
/// link.
///
/// @competency Evolvable, secure domain modelling (OWASP A03:2021)
class YoutubeVideoId extends Equatable {
  const YoutubeVideoId._(this.value);

  /// Parses [input] as a YouTube video id or URL.
  ///
  /// @throws [ArgumentError] if [input] is neither a bare 11-character
  ///   id nor a recognised YouTube URL carrying one.
  factory YoutubeVideoId.parse(String input) {
    final candidate = input.trim();

    if (_idPattern.hasMatch(candidate)) {
      return YoutubeVideoId._(candidate);
    }

    final extracted = _extractFromUrl(candidate);
    if (extracted != null && _idPattern.hasMatch(extracted)) {
      return YoutubeVideoId._(extracted);
    }

    throw ArgumentError.value(
      input,
      'input',
      'is neither an 11-character YouTube video id nor a YouTube video URL',
    );
  }

  /// The same expression as the backend's `CreateVideoSessionDto`
  /// `@Matches` pattern and the `video_sessions` CHECK constraint.
  /// Kept literal rather than shared, since the two codebases have no
  /// common module — divergence is guarded by tests on both sides.
  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

  static const Set<String> _allowedHosts = {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtu.be',
    'www.youtu.be',
  };

  /// Path prefixes that place the video id in the *second* segment.
  static const Set<String> _pathPrefixes = {'embed', 'shorts', 'live', 'v'};

  /// The validated 11-character id, ready to be sent to the backend.
  final String value;

  static String? _extractFromUrl(String candidate) {
    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return null;
    }
    if (!_allowedHosts.contains(uri.host.toLowerCase())) {
      return null;
    }

    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();

    // Short link form: the id is the whole path.
    if (uri.host.toLowerCase().endsWith('youtu.be')) {
      return segments.isEmpty ? null : segments.first;
    }

    // Watch form: the id is the `v` query parameter.
    final queryId = uri.queryParameters['v'];
    if (queryId != null && queryId.isNotEmpty) {
      return queryId;
    }

    // Embed, shorts and live forms: the id is the second segment.
    if (segments.length >= 2 && _pathPrefixes.contains(segments.first)) {
      return segments[1];
    }

    return null;
  }

  @override
  List<Object?> get props => [value];

  @override
  String toString() => value;
}
