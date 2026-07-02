import 'package:freezed_annotation/freezed_annotation.dart';

part 'register_params.freezed.dart';

/// Value object encapsulating the input required to register a new
/// account.
///
/// Declared `@freezed` per "Params classes
/// are declared as `@freezed`". Field names mirror the backend's
/// `RegisterDto` wire vocabulary (`email`, `password`, `username`)
/// exactly, since this object is serialised as the outbound request body
/// by `AuthRemoteDataSourceImpl.register()` — it
/// is not the `UserEntity`, so no `displayName` aliasing applies here.
///
/// This task defines the shape only; client-side validation (RFC 5322
/// email format, 8-character minimum password, non-empty username) is
/// the responsibility of `RegisterCubit`, not this value
/// object or [RegisterUseCase].
///
/// @see RegisterUseCase
@freezed
sealed class RegisterParams with _$RegisterParams {
  const factory RegisterParams({
    required String email,
    required String password,
    required String username,
  }) = _RegisterParams;
}
