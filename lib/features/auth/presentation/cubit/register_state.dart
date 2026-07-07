import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failures.dart';

part 'register_state.freezed.dart';

/// State hierarchy for [RegisterCubit].
///
/// Declared `@freezed` as a sealed union so that `RegisterPage`
/// switches exhaustively over these variants via
/// `BlocBuilder`/`BlocListener`, rather than inspecting a loading
/// boolean and a nullable error field separately.
@freezed
sealed class RegisterState with _$RegisterState {
  /// No registration attempt has been made yet. Initial state of the cubit.
  const factory RegisterState.initial() = RegisterInitial;

  /// A registration request is in progress. The UI must disable all
  /// form controls and the submit button.
  const factory RegisterState.loading() = RegisterLoading;

  /// Registration succeeded: the account was created and the session
  /// tokens are already persisted (see `RegisterUseCase` /
  /// `AuthRepositoryImpl.register`). The UI must navigate away from the
  /// registration form.
  const factory RegisterState.success() = RegisterSuccess;

  /// The registration attempt failed — either from client-side
  /// validation (a [ValidationFailure] carrying field-specific messages,
  /// emitted before any network call) or from the use case itself (any
  /// other [Failure] subtype: duplicate email, network error, etc.).
  const factory RegisterState.failure(Failure failure) = RegisterFailure;
}
