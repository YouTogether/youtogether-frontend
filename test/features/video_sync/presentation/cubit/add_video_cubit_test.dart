import 'package:bloc_test/bloc_test.dart';
import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/video_sync/domain/entities/video_session_metadata_entity.dart';
import 'package:youtogether/features/video_sync/domain/usecases/create_video_session_params.dart';
import 'package:youtogether/features/video_sync/domain/usecases/create_video_session_usecase.dart';
import 'package:youtogether/features/video_sync/domain/value_objects/youtube_video_id.dart';
import 'package:youtogether/features/video_sync/presentation/cubit/add_video_cubit.dart';
import 'package:youtogether/features/video_sync/presentation/cubit/add_video_state.dart';

class MockCreateVideoSessionUseCase extends Mock
    implements CreateVideoSessionUseCase {}

/// Unit tests for [AddVideoCubit].
///
/// Mirrors `join_room_cubit_test.dart` in structure.
///
/// Every stub matches on the concrete [CreateVideoSessionParams] rather
/// than on `any()`. A `Fake` subclass is not an option — `@freezed`
/// generates a sealed class, which cannot be implemented outside its
/// own library — and matching concretely is the better test anyway: it
/// asserts *which* params were built, not merely that some were.
///
/// The failure cases are enumerated by status code rather than folded
/// into one, because `AddVideoForm` renders a different message for
/// each: a 400 is a user error correctable in the field, a 502 is
/// transient. If this cubit ever normalised failures, that distinction
/// would be lost before the widget could act on it.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios VS-ADD-01, VS-ADD-03, VS-ADD-04.
void main() {
  late MockCreateVideoSessionUseCase createVideoSessionUseCase;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';
  const rawVideoId = 'dQw4w9WgXcQ';

  final youtubeVideoId = YoutubeVideoId.parse(rawVideoId);

  final params = CreateVideoSessionParams(
    roomId: roomId,
    youtubeVideoId: youtubeVideoId,
  );

  final session = VideoSessionMetadataEntity(
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
    createVideoSessionUseCase = MockCreateVideoSessionUseCase();
  });

  AddVideoCubit buildCubit() => AddVideoCubit(createVideoSessionUseCase);

  group('submit', () {
    blocTest<AddVideoCubit, AddVideoState>(
      'emits [submitting, success] on success (VS-ADD-01)',
      build: () {
        when(
          () => createVideoSessionUseCase(params),
        ).thenAnswer((_) async => Right(session));
        return buildCubit();
      },
      act: (cubit) =>
          cubit.submit(roomId: roomId, youtubeVideoId: youtubeVideoId),
      expect: () => [
        const AddVideoState.submitting(),
        AddVideoState.success(session),
      ],
    );

    blocTest<AddVideoCubit, AddVideoState>(
      'builds the params from the room id and the validated value object',
      build: () {
        when(
          () => createVideoSessionUseCase(params),
        ).thenAnswer((_) async => Right(session));
        return buildCubit();
      },
      act: (cubit) =>
          cubit.submit(roomId: roomId, youtubeVideoId: youtubeVideoId),
      verify: (_) {
        // Matching on the concrete params is the assertion: a cubit
        // that passed the wrong room id, or a differently parsed video
        // id, would leave this stub unmatched.
        verify(() => createVideoSessionUseCase(params)).called(1);
      },
    );

    blocTest<AddVideoCubit, AddVideoState>(
      'emits [submitting, failure] preserving a 400 status code (VS-ADD-04)',
      build: () {
        when(() => createVideoSessionUseCase(params)).thenAnswer(
          (_) async => const Left(
            Failure.server(statusCode: 400, message: 'video not found'),
          ),
        );
        return buildCubit();
      },
      act: (cubit) =>
          cubit.submit(roomId: roomId, youtubeVideoId: youtubeVideoId),
      expect: () => [
        const AddVideoState.submitting(),
        const AddVideoState.failure(
          Failure.server(statusCode: 400, message: 'video not found'),
        ),
      ],
    );

    blocTest<AddVideoCubit, AddVideoState>(
      'emits [submitting, failure] preserving a 502 status code (VS-ADD-04)',
      build: () {
        when(() => createVideoSessionUseCase(params)).thenAnswer(
          (_) async => const Left(
            Failure.server(
              statusCode: 502,
              message: 'realtime state unavailable',
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) =>
          cubit.submit(roomId: roomId, youtubeVideoId: youtubeVideoId),
      expect: () => [
        const AddVideoState.submitting(),
        isA<AddVideoFailure>().having(
          (state) => (state.failure as ServerFailure).statusCode,
          'statusCode',
          502,
        ),
      ],
    );

    blocTest<AddVideoCubit, AddVideoState>(
      'emits [submitting, failure(AuthFailure)] for a non-owner (VS-ADD-03)',
      build: () {
        when(() => createVideoSessionUseCase(params)).thenAnswer(
          (_) async =>
              const Left(Failure.auth(message: 'Only the owner may do this.')),
        );
        return buildCubit();
      },
      act: (cubit) =>
          cubit.submit(roomId: roomId, youtubeVideoId: youtubeVideoId),
      expect: () => [
        const AddVideoState.submitting(),
        isA<AddVideoFailure>().having(
          (state) => state.failure,
          'failure',
          isA<AuthFailure>(),
        ),
      ],
    );

    blocTest<AddVideoCubit, AddVideoState>(
      'emits [submitting, failure(NetworkFailure)] when the request never '
      'reached the backend',
      build: () {
        when(
          () => createVideoSessionUseCase(params),
        ).thenAnswer((_) async => const Left(Failure.network()));
        return buildCubit();
      },
      act: (cubit) =>
          cubit.submit(roomId: roomId, youtubeVideoId: youtubeVideoId),
      expect: () => [
        const AddVideoState.submitting(),
        const AddVideoState.failure(Failure.network()),
      ],
    );
  });
}
