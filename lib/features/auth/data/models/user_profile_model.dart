import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/user_entity.dart';

part 'user_profile_model.freezed.dart';

/// Data layer model for the backend's `GET /auth/me` response body.
///
/// Unlike [UserModel] (register/login/refresh), the backend's
/// `UserProfileDto` carries only the profile — no session tokens:
/// ```json
/// {
///   "id": "...", "email": "...", "username": "...",
///   "role": "registered", "createdAt": "..."
/// }
/// ```
/// A separate model exists specifically to avoid giving [UserModel]
/// nullable or fabricated token fields just to accommodate an endpoint
/// that never carries any: each data-layer model mirrors exactly one
/// wire shape, with no field present that a given endpoint would not
/// actually populate.
///
/// `fromJson` is written by hand, matching [UserModel]'s approach, for
/// consistency — this particular shape happens to be flat enough that
/// `json_serializable` could generate it, but keeping both models'
/// parsing style identical is more valuable than the marginal codegen
/// savings on this one class.
@freezed
sealed class UserProfileModel with _$UserProfileModel {
  const UserProfileModel._();

  const factory UserProfileModel({
    required String id,
    required String email,
    required String username,
    required String role,
    required DateTime createdAt,
  }) = _UserProfileModel;

  /// Parses the backend's `UserProfileDto` JSON body.
  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Converts this data-layer model to the domain's [UserEntity].
  ///
  /// See [UserModel.toDomain] for the `username` → `displayName` mapping
  /// rationale, shared identically here.
  UserEntity toDomain() {
    return UserEntity(
      id: id,
      email: email,
      displayName: username,
      role: UserRole.values.byName(role),
      createdAt: createdAt,
    );
  }
}
