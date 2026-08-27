import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure_localizations.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../bloc/video_sync_bloc.dart';
import '../bloc/video_sync_event.dart';
import '../bloc/video_sync_state.dart';

/// Single inline status banner for the room's video synchronisation
/// state, consolidating what were previously two separate concerns.
///
/// Replaces `SyncFailureBanner`, which handled only
/// [VideoSyncState.failure]. That widget could not cover the ready gate
/// when it was written — [VideoSyncState.barrierWaiting] did not carry
/// `readyCount`/`totalCount` until the ready-gate orchestration pass —
/// and two independently-rendered banners stacked above the player
/// would have competed for the same slot in `RoomDetailView`, since a
/// participant can be waiting on the gate *and* hit a Firebase failure.
/// One widget, one slot, one state resolution.
///
/// Renders per state:
/// - [VideoSyncState.failure] — error styling, **Retry**
///   ([VideoSyncEvent.retryRequested]). The message comes from
///   [localizeFailure], which maps the failure *variant* to a localised
///   string rather than displaying the failure's own technical
///   `message` field — see that function's own doc comment. Two
///   overrides are passed: a dropped realtime connection and a room with
///   no video session both mean something specific here that the core
///   defaults cannot express.
/// - [VideoSyncState.barrierWaiting] — "`n/m ready`" progress, plus
///   **Start now** ([VideoSyncEvent.forceStartRequested]) for the leader
///   only. The button is always offered to the leader rather than only
///   after `readyGateTimeout` elapses: `VideoSyncBloc` deliberately does
///   not auto-force-start on timeout (see `_onBarrierUpdated`'s own
///   comment), and this widget has no timer of its own to know when the
///   timeout passed — gating the button on a duration it cannot observe
///   would be guesswork. `VideoSyncBloc._onForceStartRequested` is
///   itself leader-gated, so an early tap is safe regardless.
/// - [VideoSyncState.adInProgress] — informational only; no action, since
///   neither the viewer nor the leader can skip an advertisement.
/// - Every other state — `SizedBox.shrink()`, reserving no layout space.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocBuilder<VideoSyncBloc, VideoSyncState>(
      builder: (context, state) {
        return switch (state) {
          VideoSyncFailure(:final failure) => _Banner(
            message: localizeFailure(
              l10n,
              failure,
              realtime: l10n.videoSyncRealtimeErrorMessage,
              notFound: l10n.videoSyncNotFoundErrorMessage,
            ),
            isError: true,
            action: _BannerAction(
              key: const Key('syncStatusBannerRetryButton'),
              label: l10n.commonRetryButtonLabel,
              event: const VideoSyncEvent.retryRequested(),
            ),
          ),
          VideoSyncBarrierWaiting(:final readyCount, :final totalCount) =>
            _Banner(
              message: l10n.videoSyncReadyGateMessage(readyCount, totalCount),
              isError: false,
              action: context.read<VideoSyncBloc>().isLeader
                  ? _BannerAction(
                      key: const Key('syncStatusBannerForceStartButton'),
                      label: l10n.videoSyncForceStartButtonLabel,
                      event: const VideoSyncEvent.forceStartRequested(),
                    )
                  : null,
            ),
          VideoSyncAdInProgress() => _Banner(
            message: l10n.videoSyncAdInProgressMessage,
            isError: false,
            action: null,
          ),
          VideoSyncInitial() ||
          VideoSyncLoading() ||
          VideoSyncReady() ||
          VideoSyncPlaying() ||
          VideoSyncPaused() => const SizedBox.shrink(),
        };
      },
    );
  }
}

/// A labelled button dispatching [event] to the ancestor
/// [VideoSyncBloc].
class _BannerAction {
  const _BannerAction({
    required this.key,
    required this.label,
    required this.event,
  });

  final Key key;
  final String label;
  final VideoSyncEvent event;
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.message,
    required this.isError,
    required this.action,
  });

  final String message;
  final bool isError;
  final _BannerAction? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = isError
        ? scheme.errorContainer
        : scheme.secondaryContainer;
    final foreground = isError
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;
    final bannerAction = action;

    return Material(
      key: const Key('syncStatusBanner'),
      color: background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              // liveRegion: assistive technologies announce the banner
              // when it appears or its text changes, rather than the
              // user discovering a connection loss or a moving ready
              // count only by exploring the screen (WCAG 2.1, 4.1.3
              // Status Messages).
              child: Semantics(
                liveRegion: true,
                child: Text(message, style: TextStyle(color: foreground)),
              ),
            ),
            if (bannerAction != null)
              TextButton(
                key: bannerAction.key,
                onPressed: () =>
                    context.read<VideoSyncBloc>().add(bannerAction.event),
                child: Text(bannerAction.label),
              ),
          ],
        ),
      ),
    );
  }
}
