import '../../l10n/generated/app_localizations.dart';
import 'failures.dart';

/// Resolves a [Failure] to a localised, user-facing message.
///
/// ## Why a failure's own `message` is never displayed
/// This is not a new rule — it is the internationalisation convention
/// already documented on [Failure] itself: every `message` field is
/// diagnostic text, often sourced verbatim from the backend or a
/// platform exception, and presentation code must never render it. It
/// exists only at runtime (so no localisation infrastructure can
/// translate it), it is always English regardless of the user's locale,
/// and it can leak implementation detail.
///
/// What this function changes is *where* that convention is
/// implemented. Before it existed, every view carried its own private
/// `_failureMessage` switch — `RegisterView`, `LoginView`,
/// `CreateRoomView`, and `EditRoomView` each had one, structurally
/// identical, which is why the ARB carried five byte-identical network
/// messages and six byte-identical generic ones. Each copy was also a
/// place a variant could be forgotten.
///
/// ## Exhaustive switch, deliberately
/// Written as an exhaustive `switch` over the sealed hierarchy, matching
/// the convention on [Failure] ("switches exhaustively on the `Failure`
/// subtype"). Adding a variant to [Failure] breaks the build **here, in
/// one place**, until it is handled — which is precisely the benefit of
/// centralising: before, the same addition broke four call sites at
/// once, or worse, silently fell into somebody's `_ =>` default.
///
/// ## Overrides, and why they are not a compromise
/// Some per-feature wording says more than any generic default can:
/// `editRoomAuthErrorMessage` ("Only the room owner can make this
/// change.") is the clearest example, and collapsing it onto
/// [AppLocalizations.failureAuthMessage] would lose real information. So
/// each variant accepts an optional already-resolved string; a call site
/// passes only the ones where context genuinely adds meaning and
/// inherits the rest.
///
/// Overrides are resolved `String`s rather than key names so they stay
/// compile-time checked: a renamed or deleted ARB key breaks the build
/// at the call site instead of failing at runtime.
///
/// ## [ValidationFailure] is the one genuine exception
/// [ValidationFailure.errors] is *not* diagnostic text: those strings
/// are user-facing copy authored by the cubit or the backend's
/// `ValidationPipe` specifically to be read by the user, and
/// `LoginView` deliberately renders them joined. That is why
/// [validation] is a callback over the error map rather than a plain
/// string — a caller that wants that behaviour opts into it explicitly,
/// and every caller that omits it gets the safe generic message instead
/// of accidentally surfacing field-level text in a context that has
/// nowhere sensible to put it.
String localizeFailure(
  AppLocalizations l10n,
  Failure failure, {
  String? network,
  String? server,
  String? auth,
  String? notFound,
  String? cache,
  String? realtime,
  String? generic,
  String Function(Map<String, String> errors)? validation,
}) {
  return switch (failure) {
    NetworkFailure() => network ?? l10n.failureNetworkMessage,
    ServerFailure() => server ?? l10n.failureServerMessage,
    AuthFailure() => auth ?? l10n.failureAuthMessage,
    NotFoundFailure() => notFound ?? l10n.failureNotFoundMessage,
    CacheFailure() => cache ?? l10n.failureCacheMessage,
    FirebaseFailure() => realtime ?? l10n.failureRealtimeMessage,
    ValidationFailure(:final errors) =>
      validation?.call(errors) ?? generic ?? l10n.failureGenericMessage,
  };
}
