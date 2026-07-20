import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/room_entity.dart';

part 'room_model.freezed.dart';

/// Data layer model for the backend's `RoomResponseDto` response body.
///
/// Mirrors `UserModel`/`UserProfileModel`: `@freezed` with a private
/// constructor (`RoomModel._()`) enabling the extra [toDomain] method,
/// and a hand-written [fromJson] rather than `json_serializable`
/// codegen. The backend's `RoomResponseDto` shape happens to be flat
/// enough that codegen could generate this particular parser, but
/// keeping every data-layer model's parsing style identical across the
/// codebase is worth more than the marginal codegen savings on this one
/// class — the same trade-off already documented on `UserProfileModel`.
///
/// No `toJson()`: like `UserModel`/`UserProfileModel`, this model is
/// only ever deserialised from a server response. Outgoing request
/// bodies for room creation/update are built as plain `Map` literals
/// directly in `RoomRemoteDataSourceImpl`, mirroring
/// `AuthRemoteDataSourceImpl.register`/`.login` — there is no code path
/// that would ever call `RoomModel.toJson()`, so it is not provided.
///
/// Field names match the backend's `RoomResponseDto` wire vocabulary
/// exactly (`id`, `name`, `description`, `ownerId`, `isPublic`,
/// `memberCount`, `createdAt`, `updatedAt`) — no renaming applies here,
/// unlike `UserEntity.displayName` (sourced from the backend's
/// `username`).
@freezed
sealed class RoomModel with _$RoomModel {
  const RoomModel._();

  const factory RoomModel({
    required String id,
    required String name,
    required String? description,
    required String ownerId,
    required bool isPublic,
    required int memberCount,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _RoomModel;

  /// Parses a single room object from the backend's `RoomResponseDto`
  /// JSON shape (an element of the array returned by `GET /rooms`, or
  /// the object returned directly by `POST /rooms`, `GET /rooms/:id`,
  /// `PATCH /rooms/:id`, `POST /rooms/:id/join`).
  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      ownerId: json['ownerId'] as String,
      isPublic: json['isPublic'] as bool,
      memberCount: json['memberCount'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Converts this data-layer model to the domain's [RoomEntity].
  ///
  /// A pure field-for-field copy: unlike `UserModel.toDomain()`, there
  /// are no fields to drop here (no session tokens ride along on a
  /// room response) and no field renaming to apply.
  RoomEntity toDomain() {
    return RoomEntity(
      id: id,
      name: name,
      description: description,
      ownerId: ownerId,
      isPublic: isPublic,
      memberCount: memberCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
