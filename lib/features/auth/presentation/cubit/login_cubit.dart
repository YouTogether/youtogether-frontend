import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/validation/validators.dart';
import '../../domain/usecases/login_params.dart';
import '../../domain/usecases/login_usecase.dart';
import 'login_state.dart';

/// Cubit orchestrating the login form's request lifecycle.
///
/// Mirrors `RegisterCubit` in structure and intent: owns
/// client-side validation — a fast rejection before any network call —
/// and translates [LoginUseCase]'s result into [LoginState] variants
/// consumed by `LoginPage`.
///
/// Validation rules mirror the backend's `LoginDto` constraints exactly:
/// - `email` must be a plausible address ([Validators.isValidEmail]).
/// - `password` must not be empty.
///
/// Deliberately minimal compared to `RegisterCubit`'s validation: the
/// backend does not distinguish an unknown email from a wrong password
/// (OWASP A07:2021 — see `IAuthRepository.login` doc comment), so there
/// is no password-strength rule to enforce here — any non-empty string
/// is submitted and the server is the sole authority on whether it is
/// correct.
///
/// @see LoginUseCase — the delegated domain operation
/// @see LoginState — the emitted state hierarchy
class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._loginUseCase) : super(const LoginState.initial());

  final LoginUseCase _loginUseCase;

  /// Validates the given fields and, if both are valid, submits them via
  /// [LoginUseCase].
  ///
  /// Emits [LoginState.failure] with a [ValidationFailure] immediately if
  /// either field is invalid — no [LoginState.loading] is emitted and no
  /// network call is made in that case. Otherwise emits
  /// [LoginState.loading], then either [LoginState.success] or
  /// [LoginState.failure] with whatever [Failure] the use case returned.
  Future<void> login({required String email, required String password}) async {
    final validationErrors = _validate(email: email, password: password);

    if (validationErrors.isNotEmpty) {
      emit(LoginState.failure(Failure.validation(errors: validationErrors)));
      return;
    }

    emit(const LoginState.loading());

    final result = await _loginUseCase(
      LoginParams(email: email, password: password),
    );

    result.fold(
      (failure) => emit(LoginState.failure(failure)),
      (_) => emit(const LoginState.success()),
    );
  }

  /// Returns the cubit to [LoginState.initial].
  ///
  /// Called on navigation away from the login form before completion
  /// (`LoginView.dispose`), for the same reason documented on
  /// `RegisterCubit.reset`.
  void reset() => emit(const LoginState.initial());

  Map<String, String> _validate({
    required String email,
    required String password,
  }) {
    final errors = <String, String>{};

    if (!Validators.isValidEmail(email)) {
      errors['email'] = 'Please enter a valid email address.';
    }

    if (password.isEmpty) {
      errors['password'] = 'Password must not be empty.';
    }

    return errors;
  }
}
