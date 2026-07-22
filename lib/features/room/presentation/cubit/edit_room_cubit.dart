import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/usecases/update_room_params.dart';
import '../../domain/usecases/update_room_usecase.dart';
import 'edit_room_state.dart';

/// Cubit orchestrating the room edit form's request lifecycle.
///
/// Mirrors `CreateRoomCubit` in structure and intent, adapted to
/// [UpdateRoomUseCase]'s partial-update semantics: `description` may be
/// omitted to leave it unchanged (see `UpdateRoomParams`'s own doc),
/// but `name` is always resubmitted here since the form always shows
/// (and lets the owner re-edit) the current name — there is no "leave
/// name unchanged" affordance in this form, unlike the backend/data
/// layer's general partial-update support.
///
/// Validation mirrors `CreateRoomCubit`'s exactly (non-empty, max
/// [_maxNameLength] characters) — the same backend constraint applies
/// to both create and update.
///
/// @see UpdateRoomUseCase — the delegated domain operation
/// @see EditRoomState — the emitted state hierarchy
class EditRoomCubit extends Cubit<EditRoomState> {
  EditRoomCubit(this._updateRoomUseCase) : super(const EditRoomState.initial());

  final UpdateRoomUseCase _updateRoomUseCase;

  static const int _maxNameLength = 100;

  /// Validates [name] and, if valid, submits the room update request.
  ///
  /// Emits [EditRoomState.failure] with a [ValidationFailure]
  /// immediately if [name] is invalid — no [EditRoomState.loading] is
  /// emitted and no network call is made in that case. Otherwise emits
  /// [EditRoomState.loading], then either [EditRoomState.success]
  /// (carrying the updated [RoomEntity]) or [EditRoomState.failure]
  /// with whatever [Failure] the use case returned — including
  /// [AuthFailure] for a non-owner request that somehow still reaches
  /// this cubit (server-side `OwnershipGuard` is the actual
  /// enforcement; the client hides this form's entry point for
  /// non-owners as defence in depth, not as the source of truth).
  Future<void> updateRoom({
    required String roomId,
    required String name,
    String? description,
  }) async {
    final validationErrors = _validate(name: name);

    if (validationErrors.isNotEmpty) {
      emit(EditRoomState.failure(Failure.validation(errors: validationErrors)));
      return;
    }

    emit(const EditRoomState.loading());

    final result = await _updateRoomUseCase(
      UpdateRoomParams(roomId: roomId, name: name, description: description),
    );

    result.fold(
      (failure) => emit(EditRoomState.failure(failure)),
      (room) => emit(EditRoomState.success(room)),
    );
  }

  /// Returns the cubit to [EditRoomState.initial].
  ///
  /// Called on navigation away from the form before completion
  /// (`EditRoomView.dispose`), mirroring `CreateRoomCubit.reset`.
  void reset() => emit(const EditRoomState.initial());

  Map<String, String> _validate({required String name}) {
    final errors = <String, String>{};

    if (name.isEmpty) {
      errors['name'] = 'Room name must not be empty.';
    } else if (name.length > _maxNameLength) {
      errors['name'] = 'Room name must not exceed $_maxNameLength characters.';
    }

    return errors;
  }
}
