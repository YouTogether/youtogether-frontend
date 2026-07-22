import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/room_entity.dart';
import '../cubit/edit_room_cubit.dart';
import '../cubit/edit_room_state.dart';

/// Room edit form, driven by the [EditRoomCubit] provided by an
/// ancestor `BlocProvider` (normally `EditRoomPage`).
///
/// Mirrors `CreateRoomView` almost exactly; the two differences are:
/// - Fields are pre-populated from [initialRoom] rather than starting
///   empty (this ticket's Definition of Done: "form pre-populated with
///   existing values").
/// - `description` is always resubmitted alongside `name` on every
///   submission (see `EditRoomCubit`'s own doc for why this form has
///   no "leave a field unchanged" affordance, unlike the underlying
///   partial-update API it calls).
class EditRoomView extends StatefulWidget {
  const EditRoomView({
    required this.initialRoom,
    required this.onRoomUpdated,
    super.key,
  });

  final RoomEntity initialRoom;
  final ValueChanged<RoomEntity> onRoomUpdated;

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
                      labelText: l10n.createRoomNameFieldLabel,
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
                      labelText: l10n.createRoomDescriptionFieldLabel,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isLoading)
                    const Center(
                      child: CircularProgressIndicator(
                        key: Key('editRoomLoadingIndicator'),
                      ),
                    )
                  else
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _failureMessage(AppLocalizations l10n, Failure failure) {
    return switch (failure) {
      NetworkFailure() => l10n.editRoomNetworkErrorMessage,
      ServerFailure() => l10n.editRoomServerErrorMessage,
      AuthFailure() => l10n.editRoomAuthErrorMessage,
      NotFoundFailure() => l10n.editRoomNotFoundErrorMessage,
      CacheFailure() || FirebaseFailure() => l10n.editRoomGenericErrorMessage,
      ValidationFailure() => l10n.editRoomGenericErrorMessage,
    };
  }
}
