import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/core/error/exceptions.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/video_sync/data/datasources/i_video_session_remote_data_source.dart';
import 'package:youtogether/features/video_sync/data/models/video_session_metadata_model.dart';
import 'package:youtogether/features/video_sync/data/repositories/video_session_repository_impl.dart';

class MockVideoSessionRemoteDataSource extends Mock
    implements IVideoSessionRemoteDataSource {}

/// Unit tests for [VideoSessionRepositoryImpl.getByRoomId].
///
/// Mirrors `room_repository_impl_test.dart`'s `getRoomById` suite: a
/// mocked remote data source, verifying the exception-to-[Failure]
/// mapping — including the 404 -> [NotFoundFailure] case.
///
/// @competency Unit test harness.
void main() {
  late MockVideoSessionRemoteDataSource remoteDataSource;
  late VideoSessionRepositoryImpl repository;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';

  final model = VideoSessionMetadataModel.fromJson({
    'id': 'session-uuid',
    'roomId': roomId,
    'youtubeVideoId': 'dQw4w9WgXcQ',
    'title': 'Never Gonna Give You Up',
    'thumbnailUrl': 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
    'durationSeconds': 213,
    'addedBy': '550e8400-e29b-41d4-a716-446655440000',
    'createdAt': '2026-01-05T00:00:00.000Z',
  });

  setUp(() {
    remoteDataSource = MockVideoSessionRemoteDataSource();
    repository = VideoSessionRepositoryImpl(remoteDataSource: remoteDataSource);
  });

  test('should return Right(VideoSessionMetadataEntity) on success', () async {
    when(
      () => remoteDataSource.getByRoomId(roomId: any(named: 'roomId')),
    ).thenAnswer((_) async => model);

    final result = await repository.getByRoomId(roomId: roomId);

    expect(result.isRight, isTrue);
    expect(result.right.durationSeconds, 213);
  });

  test('should map a 404 ServerException to Left(NotFoundFailure)', () async {
    when(
      () => remoteDataSource.getByRoomId(roomId: any(named: 'roomId')),
    ).thenThrow(
      const ServerException(statusCode: 404, message: 'no video session'),
    );

    final result = await repository.getByRoomId(roomId: roomId);

    expect(result.isLeft, isTrue);
    expect(result.left, isA<NotFoundFailure>());
  });

  test('should map any other ServerException to Left(ServerFailure)', () async {
    when(
      () => remoteDataSource.getByRoomId(roomId: any(named: 'roomId')),
    ).thenThrow(
      const ServerException(statusCode: 500, message: 'Internal error'),
    );

    final result = await repository.getByRoomId(roomId: roomId);

    expect(result.isLeft, isTrue);
    expect(
      result.left,
      const Failure.server(statusCode: 500, message: 'Internal error'),
    );
  });

  test('should map a NetworkException to Left(NetworkFailure)', () async {
    when(
      () => remoteDataSource.getByRoomId(roomId: any(named: 'roomId')),
    ).thenThrow(const NetworkException());

    final result = await repository.getByRoomId(roomId: roomId);

    expect(result.isLeft, isTrue);
    expect(result.left, isA<NetworkFailure>());
  });

  group('VideoSessionRepositoryImpl.create', () {
    test('should delegate to the remote data source with the room id and '
        'video id', () async {
      when(
        () => remoteDataSource.create(
          roomId: any(named: 'roomId'),
          youtubeVideoId: any(named: 'youtubeVideoId'),
        ),
      ).thenAnswer((_) async => model);

      await repository.create(roomId: roomId, youtubeVideoId: 'dQw4w9WgXcQ');

      verify(
        () => remoteDataSource.create(
          roomId: roomId,
          youtubeVideoId: 'dQw4w9WgXcQ',
        ),
      ).called(1);
    });

    test('should return Right(VideoSessionMetadataEntity) on success '
        '(VS-ADD-01)', () async {
      when(
        () => remoteDataSource.create(
          roomId: any(named: 'roomId'),
          youtubeVideoId: any(named: 'youtubeVideoId'),
        ),
      ).thenAnswer((_) async => model);

      final result = await repository.create(
        roomId: roomId,
        youtubeVideoId: 'dQw4w9WgXcQ',
      );

      expect(result.isRight, isTrue);
      expect(result.right.durationSeconds, 213);
    });

    test(
      'should map a 403 ServerException to Left(AuthFailure) (VS-ADD-03)',
      () async {
        // A non-owner should never reach this call — the form is not
        // rendered for them. This asserts the client degrades correctly
        // if the server-side guard is the one doing the rejecting, which
        // is the enforcement point that actually matters.
        when(
          () => remoteDataSource.create(
            roomId: any(named: 'roomId'),
            youtubeVideoId: any(named: 'youtubeVideoId'),
          ),
        ).thenThrow(
          const ServerException(statusCode: 403, message: 'Forbidden resource'),
        );

        final result = await repository.create(
          roomId: roomId,
          youtubeVideoId: 'dQw4w9WgXcQ',
        );

        expect(result.isLeft, isTrue);
        expect(result.left, isA<AuthFailure>());
      },
    );

    test('should map a 404 ServerException to Left(NotFoundFailure)', () async {
      when(
        () => remoteDataSource.create(
          roomId: any(named: 'roomId'),
          youtubeVideoId: any(named: 'youtubeVideoId'),
        ),
      ).thenThrow(
        const ServerException(statusCode: 404, message: 'Room not found.'),
      );

      final result = await repository.create(
        roomId: roomId,
        youtubeVideoId: 'dQw4w9WgXcQ',
      );

      expect(result.left, const Failure.notFound());
    });

    test('should map a 400 ServerException to Left(ServerFailure), preserving '
        'the status code (VS-ADD-04)', () async {
      when(
        () => remoteDataSource.create(
          roomId: any(named: 'roomId'),
          youtubeVideoId: any(named: 'youtubeVideoId'),
        ),
      ).thenThrow(
        const ServerException(
          statusCode: 400,
          message: 'YouTube video "zzzzzzzzzzz" was not found.',
        ),
      );

      final result = await repository.create(
        roomId: roomId,
        youtubeVideoId: 'zzzzzzzzzzz',
      );

      expect(result.isLeft, isTrue);
      expect(
        result.left,
        isA<ServerFailure>().having(
          (failure) => failure.statusCode,
          'statusCode',
          400,
        ),
      );
    });

    test('should map a 502 ServerException to Left(ServerFailure), preserving '
        'the status code (VS-ADD-04)', () async {
      // The form distinguishes 400 from 502: the first is a user error,
      // the second is transient and worth retrying. Collapsing both into
      // an untyped failure here would make that impossible upstream.
      when(
        () => remoteDataSource.create(
          roomId: any(named: 'roomId'),
          youtubeVideoId: any(named: 'youtubeVideoId'),
        ),
      ).thenThrow(
        const ServerException(
          statusCode: 502,
          message: 'The realtime playback state could not be initialised.',
        ),
      );

      final result = await repository.create(
        roomId: roomId,
        youtubeVideoId: 'dQw4w9WgXcQ',
      );

      expect(
        result.left,
        isA<ServerFailure>().having(
          (failure) => failure.statusCode,
          'statusCode',
          502,
        ),
      );
    });

    test('should map NetworkException to Left(NetworkFailure)', () async {
      when(
        () => remoteDataSource.create(
          roomId: any(named: 'roomId'),
          youtubeVideoId: any(named: 'youtubeVideoId'),
        ),
      ).thenThrow(const NetworkException());

      final result = await repository.create(
        roomId: roomId,
        youtubeVideoId: 'dQw4w9WgXcQ',
      );

      expect(result.left, isA<NetworkFailure>());
    });
  });
}
