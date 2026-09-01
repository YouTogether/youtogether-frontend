import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/value_objects/youtube_video_id.dart';
import '../bloc/video_sync_bloc.dart';
import '../bloc/video_sync_event.dart';
import '../cubit/add_video_cubit.dart';
import '../cubit/add_video_state.dart';

/// Form letting a room's leader add a YouTube video and start the
/// session.
///
/// Rendered by `RoomVideoSection` in the one state where it makes
/// sense: the room has no video session yet
/// (`VideoSyncBloc.youtubeVideoId` is empty) *and* the viewer is the
/// leader. Non-leaders see an explanatory line instead.
///
/// Hiding the form from non-leaders is defence in depth, not the
/// enforcement point: `OwnershipGuard` rejects the request server-side,
/// and `AddVideoCubit` surfaces that rejection like any other failure.
/// The same discipline `RoomDetailView` already applies to the edit and
/// delete actions.
///
/// ## Validation
/// The field validator constructs a [YoutubeVideoId], which throws for
/// anything that is neither a bare 11-character id nor a recognised
/// YouTube URL. That keeps malformed input entirely local: no state
/// transition, no request, and an error message on the field itself
/// rather than a snack bar after a round trip.
///
/// [_submit] parses a second time rather than caching what the
/// validator produced. Retaining a parsed value out of a validator
/// means keeping two sources of truth for the field's contents in sync,
/// and the parse is a pure function over a short string — re-running it
/// once per submission is cheaper than the bug that shortcut invites.
///
/// ## After success
/// The listener dispatches `VideoSyncEvent.sessionJoined`, which
/// re-runs the bloc's whole join sequence. That resolves the room owner,
/// the freshly created metadata, and the `playback_state` node the
/// backend wrote during the same request (B-V03) — so the player mounts
/// on the next frame without a second user action.
class AddVideoForm extends StatefulWidget {
  const AddVideoForm({super.key});

  @override
  State<AddVideoForm> createState() => _AddVideoFormState();
}

class _AddVideoFormState extends State<AddVideoForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final YoutubeVideoId youtubeVideoId;
    try {
      youtubeVideoId = YoutubeVideoId.parse(_controller.text);
    } on ArgumentError {
      // Unreachable: the validator above rejects exactly the same
      // inputs. Kept rather than forced with `!`, so that a future
      // divergence between the two degrades into a no-op instead of a
      // crash.
      return;
    }

    context.read<AddVideoCubit>().submit(
      roomId: context.read<VideoSyncBloc>().roomId,
      youtubeVideoId: youtubeVideoId,
    );
  }

  String? _validate(AppLocalizations l10n, String? value) {
    try {
      YoutubeVideoId.parse(value ?? '');
      return null;
    } on ArgumentError {
      return l10n.videoSyncAddVideoInvalidInputMessage;
    }
  }

  /// Maps a [Failure] to the message shown in the snack bar.
  ///
  /// The 400/502 split is the reason `VideoSessionRepositoryImpl.create`
  /// preserves the status code: a rejected video id is a user error,
  /// correctable in the field, while an upstream failure is transient
  /// and worth retrying unchanged. Collapsing both into one message
  /// would tell the user to fix something that is not broken.
  String _errorMessage(AppLocalizations l10n, Failure failure) {
    return switch (failure) {
      ServerFailure(:final statusCode) when statusCode == 400 =>
        l10n.videoSyncAddVideoRejectedMessage,
      ServerFailure() => l10n.videoSyncAddVideoUpstreamMessage,
      AuthFailure() => l10n.videoSyncAddVideoForbiddenMessage,
      NotFoundFailure() => l10n.videoSyncNotFoundErrorMessage,
      _ => l10n.videoSyncAddVideoNetworkMessage,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return BlocConsumer<AddVideoCubit, AddVideoState>(
      listener: (context, state) {
        switch (state) {
          case AddVideoSuccess():
            _controller.clear();
            context.read<VideoSyncBloc>().add(
              const VideoSyncEvent.sessionJoined(),
            );
          case AddVideoFailure(:final failure):
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_errorMessage(l10n, failure))),
            );
          case AddVideoInitial():
          case AddVideoSubmitting():
            break;
        }
      },
      builder: (context, state) {
        final isSubmitting = state is AddVideoSubmitting;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.videoSyncAddVideoTitle,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('addVideoFormField'),
                  controller: _controller,
                  enabled: !isSubmitting,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(
                    labelText: l10n.videoSyncAddVideoFieldLabel,
                    helperText: l10n.videoSyncAddVideoFieldHelper,
                    helperMaxLines: 2,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => _validate(l10n, value),
                  onFieldSubmitted: (_) => isSubmitting ? null : _submit(),
                ),
                const SizedBox(height: 12),
                if (isSubmitting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: CircularProgressIndicator(
                        key: Key('addVideoFormSubmittingIndicator'),
                      ),
                    ),
                  )
                else
                  FilledButton(
                    key: const Key('addVideoFormSubmitButton'),
                    onPressed: _submit,
                    child: Text(l10n.videoSyncAddVideoSubmitButtonLabel),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
