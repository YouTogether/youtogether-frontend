import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failures.dart';

part 'login_state.freezed.dart';

/// State hierarchy for [LoginCubit].
///
/// Declared `@freezed` as a sealed union, mirroring `RegisterState`
/// so that both auth forms share the same UI-consumption
/// pattern in `BlocBuilder`/`BlocListener`.
@freezed
sealed class LoginState with _$LoginState {
  /// No login attempt has been made yet. Initial state of the cubit.
  const factory LoginState.initial() = LoginInitial;

  /// A login request is in progress. The UI must disable all form
  /// controls and the submit button.
  const factory LoginState.loading() = LoginLoading;

  /// Login succeeded: the session tokens are already persisted (see
  /// `LoginUseCase` / `AuthRepositoryImpl.login`). The UI must navigate
  /// away from the login form.
  const factory LoginState.success() = LoginSuccess;

  /// The login attempt failed — either from client-side validation (a
  /// [ValidationFailure] with field-specific messages, emitted before
  /// any network call) or from the use case itself. Most commonly an
  /// [AuthFailure] (HTTP 401, invalid credentials), but any other
  /// [Failure] subtype the use case can produce is equally represented
  /// here.
  const factory LoginState.failure(Failure failure) = LoginFailure;
}
