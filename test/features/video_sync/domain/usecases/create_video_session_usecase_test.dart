import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/video_sync/domain/entities/video_session_metadata_entity.dart';
import 'package:youtogether/features/video_sync/domain/repositories/i_video_session_repository.dart';
import 'package:youtogether/features/video_sync/domain/usecases/create_video_session_params.dart';
import 'package:youtogether/features/video_sync/domain/usecases/create_video_session_usecase.dart';
import 'package:youtogether/features/video_sync/domain/value_objects/youtube_video_id.dart';

class MockIVideoSessionRepository extends Mock
    implements IVideoSessionRepository {}

/// Unit tests for [CreateVideoSessionUseCase].
///
/// The use case is a thin orchestrator; these tests verify delegation
/// to [IVideoSessionRepository.create] and unchanged propagation of
/// both outcomes, mirroring `get_video_session_usecase_test.dart`.
///
/// One assertion is load-bearing rather than incidental: the port is
/// called with the *unwrapped* 11-character id. `YoutubeVideoId` exists
/// so that an unvalidated string cannot reach this layer, and the data
/// layer must receive the bare id the backend expects, not a
/// stringified value object.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios VS-ADD-01, VS-ADD-04.
void main() {
  late MockIVideoSessionRepository videoSessionRepository;
  late CreateVideoSessionUseCase createVideoSessionUseCase;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';
  const rawVideoId = 'dQw4w9WgXcQ';

  final params = CreateVideoSessionParams(
    roomId: roomId,
    youtubeVideoId: YoutubeVideoId.parse(rawVideoId),
  );

  final metadata = VideoSessionMetadataEntity(
    id: 'session-uuid',
    roomId: roomId,
    youtubeVideoId: rawVideoId,
    title: 'Never Gonna Give You Up',
    thumbnailUrl: 'https://i.ytimg.com/vi/$rawVideoId/hqdefault.jpg',
    durationSeconds: 213,
    addedBy: '550e8400-e29b-41d4-a716-446655440000',
    createdAt: DateTime.utc(2026, 1, 5),
  );

  setUp(() {
    videoSessionRepository = MockIVideoSessionRepository();
    createVideoSessionUseCase = CreateVideoSessionUseCase(
      videoSessionRepository,
    );
  });

  group('CreateVideoSessionUseCase', () {
    test('should delegate to IVideoSessionRepository.create with the room id '
        'and the unwrapped video id', () async {
      when(
        () => videoSessionRepository.create(
          roomId: any(named: 'roomId'),
          youtubeVideoId: any(named: 'youtubeVideoId'),
        ),
      ).thenAnswer((_) async => Right(metadata));

      await createVideoSessionUseCase(params);

      verify(
        () => videoSessionRepository.create(
          roomId: roomId,
          youtubeVideoId: rawVideoId,
        ),
      ).called(1);
    });

    test('should unwrap the value object even when the user pasted a full '
        'URL', () async {
      when(
        () => videoSessionRepository.create(
          roomId: any(named: 'roomId'),
          youtubeVideoId: any(named: 'youtubeVideoId'),
        ),
      ).thenAnswer((_) async => Right(metadata));

      await createVideoSessionUseCase(
        CreateVideoSessionParams(
          roomId: roomId,
          youtubeVideoId: YoutubeVideoId.parse(
            'https://www.youtube.com/watch?v=$rawVideoId&t=42s',
          ),
        ),
      );

      verify(
        () => videoSessionRepository.create(
          roomId: roomId,
          youtubeVideoId: rawVideoId,
        ),
      ).called(1);
    });

    test(
      'should return Right(VideoSessionMetadataEntity) on success (VS-ADD-01)',
      () async {
        when(
          () => videoSessionRepository.create(
            roomId: any(named: 'roomId'),
            youtubeVideoId: any(named: 'youtubeVideoId'),
          ),
        ).thenAnswer((_) async => Right(metadata));

        final result = await createVideoSessionUseCase(params);

        expect(result.isRight, isTrue);
        expect(result.right, metadata);
      },
    );

    test(
      'should propagate a not-found failure unchanged (deleted room)',
      () async {
        when(
          () => videoSessionRepository.create(
            roomId: any(named: 'roomId'),
            youtubeVideoId: any(named: 'youtubeVideoId'),
          ),
        ).thenAnswer((_) async => const Left(Failure.notFound()));

        final result = await createVideoSessionUseCase(params);

        expect(result.isLeft, isTrue);
        expect(result.left, const Failure.notFound());
      },
    );

    test('should propagate a server failure unchanged, preserving the status '
        'code (VS-ADD-04)', () async {
      // The form distinguishes 400 ("this video does not exist") from
      // 502 ("try again shortly"), so the status code must survive the
      // trip through the domain layer untouched.
      when(
        () => videoSessionRepository.create(
          roomId: any(named: 'roomId'),
          youtubeVideoId: any(named: 'youtubeVideoId'),
        ),
      ).thenAnswer(
        (_) async => const Left(
          Failure.server(statusCode: 502, message: 'realtime state failed'),
        ),
      );

      final result = await createVideoSessionUseCase(params);

      expect(result.isLeft, isTrue);
      expect(result.left, isA<ServerFailure>());
    });

    test('should propagate a network failure unchanged', () async {
      when(
        () => videoSessionRepository.create(
          roomId: any(named: 'roomId'),
          youtubeVideoId: any(named: 'youtubeVideoId'),
        ),
      ).thenAnswer((_) async => const Left(Failure.network()));

      final result = await createVideoSessionUseCase(params);

      expect(result.left, isA<NetworkFailure>());
    });
  });
}
