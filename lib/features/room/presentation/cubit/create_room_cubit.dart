import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/usecases/create_room_params.dart';
import '../../domain/usecases/create_room_usecase.dart';
import 'create_room_state.dart';

/// Cubit orchestrating the room creation form's request lifecycle.
///
/// Mirrors `RegisterCubit`/`LoginCubit` in structure and intent: owns
/// client-side validation — a fast rejection before any network call —
/// and translates [CreateRoomUseCase]'s result into [CreateRoomState]
/// variants consumed by `CreateRoomView`.
///
/// Validation mirrors the backend's `CreateRoomDto` constraints exactly
/// (non-empty, max [_maxNameLength] characters) — the same reasoning
/// `RegisterCubit`'s own doc gives for keeping client and server rules
/// in lockstep: a client-accepted submission should never be rejected
/// by the server for a reason the user was not already warned about.
///
/// `description` and `isPublic` carry no validation rule of their own:
/// the backend accepts any string (including empty) for `description`,
/// and `isPublic` is a plain boolean with no invalid value.
///
/// @see CreateRoomUseCase — the delegated domain operation
/// @see CreateRoomState — the emitted state hierarchy
class CreateRoomCubit extends Cubit<CreateRoomState> {
  CreateRoomCubit(this._createRoomUseCase)
    : super(const CreateRoomState.initial());

  final CreateRoomUseCase _createRoomUseCase;

  /// Maximum accepted room name length, mirroring the backend's
  /// `CreateRoomDto.name` `@MaxLength(100)` constraint (itself sourced
  /// from the `rooms.name VARCHAR(100)` column).
  static const int _maxNameLength = 100;

  /// Validates [name] and, if valid, submits the room creation request.
  ///
  /// Emits [CreateRoomState.failure] with a [ValidationFailure]
  /// immediately if [name] is invalid — no [CreateRoomState.loading] is
  /// emitted and no network call is made in that case. Otherwise emits
  /// [CreateRoomState.loading], then either [CreateRoomState.success]
  /// (carrying the created [RoomEntity]) or [CreateRoomState.failure]
  /// with whatever [Failure] the use case returned.
  ///
  /// [isPublic] defaults to `true`: the decision of what an omitted
  /// value means was deliberately left to this call site by
  /// `CreateRoomParams`'s own documentation, not baked into the domain
  /// value object.
  Future<void> createRoom({
    required String name,
    String? description,
    bool isPublic = true,
  }) async {
    final validationErrors = _validate(name: name);

    if (validationErrors.isNotEmpty) {
      emit(
        CreateRoomState.failure(Failure.validation(errors: validationErrors)),
      );
      return;
    }

    emit(const CreateRoomState.loading());

    final result = await _createRoomUseCase(
      CreateRoomParams(
        name: name,
        description: description,
        isPublic: isPublic,
      ),
    );

    result.fold(
      (failure) => emit(CreateRoomState.failure(failure)),
      (room) => emit(CreateRoomState.success(room)),
    );
  }

  /// Returns the cubit to [CreateRoomState.initial].
  ///
  /// Called on navigation away from the form before completion
  /// (`CreateRoomView.dispose`), for the same reason documented on
  /// `RegisterCubit.reset`.
  void reset() => emit(const CreateRoomState.initial());

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
