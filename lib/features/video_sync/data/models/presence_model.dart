import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/presence_entity.dart';

part 'presence_model.freezed.dart';

/// Data layer model for a single Firebase
/// `rooms/{room_id}/presence/{user_id}` node.
///
/// Mirrors `VideoSessionModel` in structure (`@freezed` with a private
/// constructor, hand-written `fromSnapshot`/`toJson` rather than
/// `json_serializable` codegen, a `Map<Object?, Object?>` input type
/// forced by the Firebase SDK). Field names mirror the Firebase schema
/// (`YouTogether_DataModel.docx`, Section 3.3) exactly: `username`,
/// `is_online`, `last_seen`.
///
/// [userId] is carried as a field for the same reason documented on
/// [PresenceEntity.userId]: the Firebase node itself does not store it
/// (it is the node's own path segment), but a `List<PresenceModel>`
/// returned by `IPresenceRemoteDataSource.subscribeToPresence` would
/// otherwise lose which child each parsed value came from. Accordingly,
/// [userId] is a constructor parameter to [fromSnapshot], not read out
/// of [json], and is excluded from [toJson]'s payload — the data source
/// writes it once, implicitly, by choosing the node's path
/// (`rooms/{roomId}/presence/{userId}`), never as a field value.
@freezed
sealed class PresenceModel with _$PresenceModel {
  const PresenceModel._();

  const factory PresenceModel({
    required String userId,
    required String username,
    required bool isOnline,
    required bool isAnonymous,
    required DateTime lastSeen,
  }) = _PresenceModel;

  /// Parses a single `rooms/{roomId}/presence/{userId}` node value.
  ///
  /// [userId] is the node's own path segment (the Firebase child key),
  /// passed in explicitly by the caller — mirroring
  /// [VideoSessionModel.fromSnapshot]'s `roomId` parameter.
  factory PresenceModel.fromSnapshot({
    required String userId,
    required Map<Object?, Object?> json,
  }) {
    return PresenceModel(
      userId: userId,
      username: json['username'] as String,
      isOnline: json['is_online'] as bool,
      // Defaults to `false` rather than being required: presence nodes
      // written before this field existed carry no `is_anonymous` key,
      // and every one of those was written by an authenticated client
      // (anonymous join did not exist yet).
      isAnonymous: (json['is_anonymous'] as bool?) ?? false,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(
        json['last_seen'] as int,
        isUtc: true,
      ),
    );
  }

  /// Serialises this model for a Firebase write
  /// (`DatabaseReference.set`/`.update`).
  ///
  /// [userId] is intentionally excluded — see this class's own doc
  /// comment for why it is never a field value inside the node.
  Map<String, Object?> toJson() {
    return {
      'username': username,
      'is_online': isOnline,
      'is_anonymous': isAnonymous,
      'last_seen': lastSeen.millisecondsSinceEpoch,
    };
  }

  /// Converts this data-layer model to the domain's [PresenceEntity].
  PresenceEntity toDomain() {
    return PresenceEntity(
      userId: userId,
      username: username,
      isOnline: isOnline,
      isAnonymous: isAnonymous,
      lastSeen: lastSeen,
    );
  }
}
