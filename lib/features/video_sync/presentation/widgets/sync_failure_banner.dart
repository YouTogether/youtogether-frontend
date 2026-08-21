import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/video_sync_bloc.dart';
import '../bloc/video_sync_event.dart';
import '../bloc/video_sync_state.dart';

/// Displays an inline error banner with a retry action whenever the
/// ancestor [VideoSyncBloc] is in [VideoSyncState.failure] — most
/// commonly a lost Firebase connection mid-session, but
/// also any failed command or initial-sync fetch.
///
/// Renders nothing (`SizedBox.shrink()`) for every other state — this
/// widget is meant to sit above `YouTubePlayerWidget`/`LeaderControls`
/// in `RoomDetailView` without reserving layout space when there is
/// nothing to report.
///
/// NOTE: shows a fixed, generic message rather than
/// `state.failure`'s own text. `Failure`'s exact per-variant fields
/// (whether every variant — `notFound`, `firebase`, `server`, etc. —
/// exposes a uniform `message` getter) could not be verified against
/// the actual `core/error/failures.dart` in this environment; a fixed
/// string avoids assuming an API shape that could not be confirmed.
/// Replace with `state.failure`'s real message once verified.
class SyncFailureBanner extends StatelessWidget {
  const SyncFailureBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VideoSyncBloc, VideoSyncState>(
      builder: (context, state) {
        if (state is! VideoSyncFailure) {
          return const SizedBox.shrink();
        }

        return Material(
          key: const Key('syncFailureBanner'),
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Connection lost. Tap retry to reconnect.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('syncFailureBannerRetryButton'),
                  onPressed: () => context.read<VideoSyncBloc>().add(
                    const VideoSyncEvent.retryRequested(),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
