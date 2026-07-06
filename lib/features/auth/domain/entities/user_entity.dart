import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_entity.freezed.dart';

/// User role, mirroring the backend's `user_role` PostgreSQL enum
/// (`registered` | `guest`) exactly — both the enum values and their
/// semantics come from the Data Model.
///
/// Naming caveat: `registered`
/// is ambiguous on its own — it does not distinguish "holds an account"
/// from "is authenticated in the current session". In this domain the two
/// are equivalent today, because every registered account requires an
/// active JWT session to reach any endpoint that returns a `UserEntity`
/// in the first place (see backend `JwtAuthGuard`, `GET /auth/me`). The
/// distinction only matters if a future feature introduces a state where
/// a `registered` account can be referenced without an active session
/// (e.g. another user's public profile) — a rename would be evaluated
/// against the backend enum at that point, not decided unilaterally on
/// the frontend.
enum UserRole { registered, guest }

/// Domain entity representing the currently known profile of a user.
///
/// Declared with `@freezed`: immutable, no `fromJson`/`toJson` (that
/// belongs to `UserModel` in the data layer).
///
/// Field mapping from the backend's `AuthResponseDto.user` /
/// `UserProfileDto`:
/// - [displayName] is populated from the backend's `username` field. The
///   backend's wire vocabulary (`username`) is a persistence/credential
///   term; `displayName` better reflects how the frontend actually uses
///   the field (rendering in the UI), independent of the backend's
///   internal column name.
@freezed
sealed class UserEntity with _$UserEntity {
  const factory UserEntity({
    /// Unique user identifier (UUID v4), stable across sessions.
    required String id,

    /// User email address.
    required String email,

    /// Display name shown in the UI. Sourced from the backend's
    /// `username` field — see class-level doc for the naming rationale.
    required String displayName,

    /// User role. Mirrors the backend's `registered` | `guest` values
    /// exactly — see [UserRole] for the naming caveat.
    required UserRole role,

    /// Account creation timestamp (UTC).
    required DateTime createdAt,
  }) = _UserEntity;
}
