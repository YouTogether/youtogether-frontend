import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_params.freezed.dart';

/// Value object encapsulating the input required to authenticate an
/// existing account.
///
/// Declared `@freezed`. Field names mirror the backend's `LoginDto` wire
/// vocabulary (`email`, `password`) exactly, since this object is
/// serialised as the outbound request body by
/// `AuthRemoteDataSourceImpl.login()`.
///
/// This task defines the shape only; client-side validation (non-empty
/// fields, RFC 5322 email format) is the responsibility of `LoginCubit`,
/// not this value object or [LoginUseCase]. The backend does not
/// distinguish an unknown email from a wrong password (see
/// `IAuthRepository.login` doc comment), so there is no reason for this
/// object to carry more structure than the two raw credentials.
///
/// @see LoginUseCase
@freezed
sealed class LoginParams with _$LoginParams {
  const factory LoginParams({required String email, required String password}) =
      _LoginParams;
}
