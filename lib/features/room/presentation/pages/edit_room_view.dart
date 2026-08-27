import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure_localizations.dart';
import '../../../../core/error/failures.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/room_entity.dart';
import '../cubit/edit_room_cubit.dart';
import '../cubit/edit_room_state.dart';

/// Room edit form, driven by the [EditRoomCubit] provided by an
/// ancestor `BlocProvider` (normally `EditRoomPage`).
///
/// Mirrors `CreateRoomView` almost exactly; the differences are:
/// - Fields are pre-populated from [initialRoom] rather than starting
///   empty (this ticket's Definition of Done: "form pre-populated with
///   existing values").
/// - `description` is always resubmitted alongside `name` on every
///   submission (see `EditRoomCubit`'s own doc for why this form has
///   no "leave a field unchanged" affordance, unlike the underlying
///   partial-update API it calls).
/// - A cancel button sits below the submit button, discarding the edit
///   and returning to the room detail view via [onCancel] — mirroring
///   [onRoomUpdated] as a callback rather than a hardcoded navigation,
///   for the same reason `CreateRoomPage`/`RegisterPage`/`LoginPage`
///   expose their own `on*` callbacks instead of navigating directly.
class EditRoomView extends StatefulWidget {
  const EditRoomView({
    required this.initialRoom,
    required this.onRoomUpdated,
    required this.onCancel,
    super.key,
  });

  final RoomEntity initialRoom;
  final ValueChanged<RoomEntity> onRoomUpdated;

  /// Invoked when the cancel button is tapped. Discards any unsaved
  /// changes in the form (no confirmation dialog — unlike deletion,
  /// cancelling an edit is not a destructive, hard-to-reverse action:
  /// the room itself is untouched, and the user can simply reopen the
  /// edit form to try again).
  final VoidCallback onCancel;

  @override
  State<EditRoomView> createState() => _EditRoomViewState();
}

class _EditRoomViewState extends State<EditRoomView> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  EditRoomCubit? _cubit;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialRoom.name);
    _descriptionController = TextEditingController(
      text: widget.initialRoom.description ?? '',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cubit = context.read<EditRoomCubit>();
  }

  @override
  void dispose() {
    _cubit?.reset();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editRoomPageTitle)),
      body: BlocListener<EditRoomCubit, EditRoomState>(
        listener: (context, state) {
          if (state is EditRoomSuccess) {
            widget.onRoomUpdated(state.room);
          } else if (state is EditRoomFailure &&
              state.failure is! ValidationFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_failureMessage(l10n, state.failure))),
            );
          }
        },
        child: BlocBuilder<EditRoomCubit, EditRoomState>(
          builder: (context, state) {
            final isLoading = state is EditRoomLoading;
            final nameError =
                state is EditRoomFailure && state.failure is ValidationFailure
                ? (state.failure as ValidationFailure).errors['name']
                : null;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('editRoomNameField'),
                    controller: _nameController,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      labelText: l10n.roomNameFieldLabel,
                      errorText: nameError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('editRoomDescriptionField'),
                    controller: _descriptionController,
                    enabled: !isLoading,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l10n.roomDescriptionFieldLabel,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isLoading)
                    Center(
                      child: Semantics(
                        label: l10n.commonLoadingLabel,
                        child: const CircularProgressIndicator(
                          key: Key('editRoomLoadingIndicator'),
                        ),
                      ),
                    )
                  else ...[
                    ElevatedButton(
                      key: const Key('editRoomSubmitButton'),
                      onPressed: () => context.read<EditRoomCubit>().updateRoom(
                        roomId: widget.initialRoom.id,
                        name: _nameController.text,
                        description: _descriptionController.text.isEmpty
                            ? null
                            : _descriptionController.text,
                      ),
                      child: Text(l10n.editRoomSubmitButtonLabel),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('editRoomCancelButton'),
                      onPressed: widget.onCancel,
                      child: Text(l10n.editRoomCancelButtonLabel),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Maps a non-validation [Failure] to a localised message for the
  /// `SnackBar`, via the shared [localizeFailure] resolver.
  ///
  /// Two overrides survive because they say more than the shared
  /// defaults: "Only the room owner can make this change." and "This
  /// room no longer exists." — both name the specific reason an edit was
  /// refused. Network, server, cache, and generic inherit.
  String _failureMessage(AppLocalizations l10n, Failure failure) {
    return localizeFailure(
      l10n,
      failure,
      auth: l10n.editRoomAuthErrorMessage,
      notFound: l10n.editRoomNotFoundErrorMessage,
    );
  }
}
