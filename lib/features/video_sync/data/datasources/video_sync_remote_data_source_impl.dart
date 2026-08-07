import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/video_session_model.dart';
import 'i_video_sync_remote_data_source.dart';

/// Concrete [IVideoSyncRemoteDataSource] backed by Firebase Realtime
/// Database.
///
/// Every method targets `rooms/{roomId}/playback_state`. `FirebaseDatabase`
/// is injected via the constructor (rather than read from
/// `FirebaseDatabase.instance` directly) so tests can supply a mocktail
/// double — mirroring how `RoomRemoteDataSourceImpl` receives its `Dio`
/// instance rather than constructing one internally.
class VideoSyncRemoteDataSourceImpl implements IVideoSyncRemoteDataSource {
  VideoSyncRemoteDataSourceImpl({required FirebaseDatabase database})
    : _database = database;

  final FirebaseDatabase _database;

  DatabaseReference _playbackStateRef(String roomId) {
    return _database.ref('rooms/$roomId/playback_state');
  }

  /// Extracts and validates a snapshot's value, throwing a
  /// [FirebaseException] if the node does not exist — mirroring how
  /// `RoomRemoteDataSourceImpl` throws `ServerException` for a 404
  /// rather than returning a null model up through the stack.
  Map<Object?, Object?> _requireValue(DataSnapshot snapshot) {
    final value = snapshot.value;
    if (!snapshot.exists || value == null) {
      throw FirebaseException(
        plugin: 'firebase_database',
        message: 'No playback state found for this room.',
      );
    }
    return value as Map<Object?, Object?>;
  }

  @override
  Future<void> updatePlaybackState({
    required String roomId,
    required bool isPlaying,
    required Duration position,
  }) {
    // A partial VideoSessionModel is built purely to reuse its toJson()
    // serialisation; roomId/youtubeVideoId/leaderId are placeholders
    // never read by toJson() (see that method's own doc comment on
    // exactly which fields it emits).
    final payload = VideoSessionModel(
      roomId: roomId,
      youtubeVideoId: '',
      isPlaying: isPlaying,
      currentPositionSeconds: position.inMilliseconds / 1000,
      leaderId: '',
      updatedAt: DateTime.now().toUtc(),
    ).toJson();

    return _playbackStateRef(roomId).update(payload);
  }

  @override
  Future<VideoSessionModel> getCurrentPlaybackState({
    required String roomId,
  }) async {
    final event = await _playbackStateRef(roomId).once();
    final value = _requireValue(event.snapshot);
    return VideoSessionModel.fromSnapshot(roomId: roomId, json: value);
  }

  @override
  Stream<VideoSessionModel> subscribeToPlaybackState({required String roomId}) {
    return _playbackStateRef(roomId).onValue.map((event) {
      final value = _requireValue(event.snapshot);
      return VideoSessionModel.fromSnapshot(roomId: roomId, json: value);
    });
  }
}
