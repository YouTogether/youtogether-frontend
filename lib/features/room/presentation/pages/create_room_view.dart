import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/room_entity.dart';
import '../cubit/create_room_cubit.dart';
import '../cubit/create_room_state.dart';

/// Room creation form, driven entirely by the [CreateRoomCubit] provided
/// by an ancestor `BlocProvider` (normally `CreateRoomPage`).
///
/// Split from `CreateRoomPage` for the same testability reason
/// `RegisterView`/`LoginView` are split from their pages.
///
/// UI behaviour, per this ticket's Definition of Done:
/// - Name and description fields, an `isPublic` toggle (defaulting to
///   `true`), and a submit button.
/// - [CreateRoomState.loading]: every control is disabled and the submit
///   button is replaced by a [CircularProgressIndicator].
/// - [CreateRoomState.failure] with a [ValidationFailure]: the name
///   field shows its error inline via `InputDecoration.errorText` — no
///   `SnackBar` — mirroring `RegisterView`'s identical split.
/// - [CreateRoomState.failure] with any other [Failure] subtype: a
///   `SnackBar` shows a localised, generic message. The raw
///   `.message` field is never rendered, mirroring `RegisterView`'s own
///   `_failureMessage` convention.
/// - [CreateRoomState.success]: [onRoomCreated] is invoked with the
///   created [RoomEntity]. Deliberately a callback rather than a direct
///   navigation call — mirroring `RegisterPage`/`LoginPage`'s own
///   `on*Succeeded` callbacks — because no "room detail view" page
///   exists yet in this codebase for a genuinely correct destination to
///   navigate to (see `CreateRoomPage`'s own doc comment for the
///   pragmatic choice made where this is wired).
class CreateRoomView extends StatefulWidget {
  const CreateRoomView({required this.onRoomCreated, super.key});

  final ValueChanged<RoomEntity> onRoomCreated;

  @override
  State<CreateRoomView> createState() => _CreateRoomViewState();
}

class _CreateRoomViewState extends State<CreateRoomView> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isPublic = true;

  /// Cached reference to the ancestor [CreateRoomCubit], captured in
  /// [didChangeDependencies] rather than looked up directly in
  /// [dispose] — see `RegisterView`'s identical field for the full
  /// rationale.
  CreateRoomCubit? _cubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cubit = context.read<CreateRoomCubit>();
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
      appBar: AppBar(title: Text(l10n.createRoomPageTitle)),
      body: BlocListener<CreateRoomCubit, CreateRoomState>(
        listener: (context, state) {
          if (state is CreateRoomSuccess) {
            widget.onRoomCreated(state.room);
          } else if (state is CreateRoomFailure &&
              state.failure is! ValidationFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_failureMessage(l10n, state.failure))),
            );
          }
        },
        child: BlocBuilder<CreateRoomCubit, CreateRoomState>(
          builder: (context, state) {
            final isLoading = state is CreateRoomLoading;
            final nameError =
                state is CreateRoomFailure && state.failure is ValidationFailure
                ? (state.failure as ValidationFailure).errors['name']
                : null;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('createRoomNameField'),
                    controller: _nameController,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      labelText: l10n.createRoomNameFieldLabel,
                      errorText: nameError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('createRoomDescriptionField'),
                    controller: _descriptionController,
                    enabled: !isLoading,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l10n.createRoomDescriptionFieldLabel,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    key: const Key('createRoomIsPublicSwitch'),
                    value: _isPublic,
                    onChanged: isLoading
                        ? null
                        : (value) => setState(() => _isPublic = value),
                    title: Text(l10n.createRoomIsPublicLabel),
                  ),
                  const SizedBox(height: 24),
                  if (isLoading)
                    const Center(
                      child: CircularProgressIndicator(
                        key: Key('createRoomLoadingIndicator'),
                      ),
                    )
                  else
                    ElevatedButton(
                      key: const Key('createRoomSubmitButton'),
                      onPressed: () =>
                          context.read<CreateRoomCubit>().createRoom(
                            name: _nameController.text,
                            description: _descriptionController.text.isEmpty
                                ? null
                                : _descriptionController.text,
                            isPublic: _isPublic,
                          ),
                      child: Text(l10n.createRoomSubmitButtonLabel),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Maps a non-validation [Failure] to a localised message for the
  /// `SnackBar` — mirroring `RegisterView._failureMessage` exhaustively,
  /// so no raw backend diagnostic text is ever rendered.
  String _failureMessage(AppLocalizations l10n, Failure failure) {
    return switch (failure) {
      NetworkFailure() => l10n.createRoomNetworkErrorMessage,
      ServerFailure() => l10n.createRoomServerErrorMessage,
      AuthFailure() => l10n.createRoomAuthErrorMessage,
      NotFoundFailure() => l10n.createRoomNotFoundErrorMessage,
      CacheFailure() || FirebaseFailure() => l10n.createRoomGenericErrorMessage,
      ValidationFailure() => l10n.createRoomGenericErrorMessage,
    };
  }
}
