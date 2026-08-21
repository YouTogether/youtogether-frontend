import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/video_sync/domain/entities/video_session_metadata_entity.dart';
import 'package:youtogether/features/video_sync/domain/repositories/i_video_session_repository.dart';
import 'package:youtogether/features/video_sync/domain/usecases/get_video_session_usecase.dart';

class MockVideoSessionRepository extends Mock
    implements IVideoSessionRepository {}

/// Unit tests for [GetVideoSessionUseCase].
///
/// Mirrors `get_current_playback_state_usecase_test.dart`: a thin
/// delegation with no logic of its own beyond forwarding to
/// [IVideoSessionRepository.getByRoomId].
///
/// @competency Unit test harness.
void main() {
  late MockVideoSessionRepository repository;
  late GetVideoSessionUseCase useCase;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';

  final metadata = VideoSessionMetadataEntity(
    id: 'session-uuid',
    roomId: roomId,
    youtubeVideoId: 'dQw4w9WgXcQ',
    title: 'Never Gonna Give You Up',
    thumbnailUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
    durationSeconds: 213,
    addedBy: '550e8400-e29b-41d4-a716-446655440000',
    createdAt: DateTime.utc(2026, 1, 5),
  );

  setUp(() {
    repository = MockVideoSessionRepository();
    useCase = GetVideoSessionUseCase(repository);
  });

  test(
    'should delegate to IVideoSessionRepository.getByRoomId with the given room id',
    () async {
      when(
        () => repository.getByRoomId(roomId: any(named: 'roomId')),
      ).thenAnswer((_) async => Right(metadata));

      await useCase(roomId);

      verify(() => repository.getByRoomId(roomId: roomId)).called(1);
    },
  );

  test('should return Right(VideoSessionMetadataEntity) on success', () async {
    when(
      () => repository.getByRoomId(roomId: any(named: 'roomId')),
    ).thenAnswer((_) async => Right(metadata));

    final result = await useCase(roomId);

    expect(result.isRight, isTrue);
    expect(result.right.durationSeconds, 213);
  });

  test('should propagate a Left(NotFoundFailure) unchanged', () async {
    when(
      () => repository.getByRoomId(roomId: any(named: 'roomId')),
    ).thenAnswer((_) async => const Left(Failure.notFound()));

    final result = await useCase(roomId);

    expect(result.isLeft, isTrue);
    expect(result.left, isA<NotFoundFailure>());
  });
}
