import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/validation/validators.dart';
import '../../domain/usecases/register_params.dart';
import '../../domain/usecases/register_usecase.dart';
import 'register_state.dart';

/// Cubit orchestrating the registration form's request lifecycle.
///
/// Owns client-side validation — a fast rejection before any network
/// call — and translates [RegisterUseCase]'s result into [RegisterState]
/// variants consumed by `RegisterPage`.
///
/// Validation rules mirror the backend's `RegisterDto` constraints
/// exactly, so that a client-accepted submission is never rejected by
/// the server for a reason the user was not already warned about:
/// - `email` must be a plausible address ([Validators.isValidEmail]).
/// - `password` must be at least [_minPasswordLength] characters.
/// - `username` must be non-empty and at most [_maxUsernameLength]
///   characters.
///
/// All three fields are validated together before anything is reported:
/// a single submission with multiple invalid fields surfaces every
/// violation at once, via the `errors` map on [ValidationFailure], rather
/// than forcing the user through one round-trip per field.
///
/// @see RegisterUseCase — the delegated domain operation
/// @see RegisterState — the emitted state hierarchy
class RegisterCubit extends Cubit<RegisterState> {
  RegisterCubit(this._registerUseCase) : super(const RegisterState.initial());

  final RegisterUseCase _registerUseCase;

  /// Minimum accepted password length, mirroring the backend's
  /// `RegisterDto.password` `@MinLength(8)` constraint.
  static const int _minPasswordLength = 8;

  /// Maximum accepted username length, mirroring the backend's
  /// `RegisterDto.username` `@MaxLength(50)` constraint (itself sourced
  /// from the `users.username VARCHAR(50)` column).
  static const int _maxUsernameLength = 50;

  /// Validates the given fields and, if all are valid, submits them via
  /// [RegisterUseCase].
  ///
  /// Emits [RegisterState.failure] with a [ValidationFailure] immediately
  /// if any field is invalid — no [RegisterState.loading] is emitted and
  /// no network call is made in that case. Otherwise emits
  /// [RegisterState.loading], then either [RegisterState.success] or
  /// [RegisterState.failure] with whatever [Failure] the use case
  /// returned.
  Future<void> register({
    required String email,
    required String password,
    required String username,
  }) async {
    final validationErrors = _validate(
      email: email,
      password: password,
      username: username,
    );

    if (validationErrors.isNotEmpty) {
      emit(RegisterState.failure(Failure.validation(errors: validationErrors)));
      return;
    }

    emit(const RegisterState.loading());

    final result = await _registerUseCase(
      RegisterParams(email: email, password: password, username: username),
    );

    result.fold(
      (failure) => emit(RegisterState.failure(failure)),
      (_) => emit(const RegisterState.success()),
    );
  }

  /// Runs every field-level check and collects all violations, keyed by
  /// field name — mirroring the shape of the backend's `ValidationPipe`
  /// error body.
  Map<String, String> _validate({
    required String email,
    required String password,
    required String username,
  }) {
    final errors = <String, String>{};

    if (!Validators.isValidEmail(email)) {
      errors['email'] = 'Please enter a valid email address.';
    }

    if (password.length < _minPasswordLength) {
      errors['password'] =
          'Password must be at least $_minPasswordLength characters.';
    }

    if (username.isEmpty) {
      errors['username'] = 'Username must not be empty.';
    } else if (username.length > _maxUsernameLength) {
      errors['username'] =
          'Username must not exceed $_maxUsernameLength characters.';
    }

    return errors;
  }
}
