import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/video_sync/domain/repositories/i_presence_repository.dart';
import 'package:youtogether/features/video_sync/domain/usecases/set_presence_params.dart';
import 'package:youtogether/features/video_sync/domain/usecases/set_presence_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/remove_presence_params.dart';
import 'package:youtogether/features/video_sync/domain/usecases/remove_presence_usecase.dart';

class MockIPresenceRepository extends Mock implements IPresenceRepository {}

/// Unit tests for [SetPresenceUseCase] and [RemovePresenceUseCase].
///
/// Both are thin orchestrators; these tests verify delegation to
/// [IPresenceRepository], mirroring `update_room_usecase_test.dart`.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenario: anonymous viewer counted via presence.
void main() {
  late MockIPresenceRepository presenceRepository;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';
  const userId = '550e8400-e29b-41d4-a716-446655440000';
  const username = 'Alice';
  const isAnonymous = false;

  setUp(() {
    presenceRepository = MockIPresenceRepository();
  });

  group('SetPresenceUseCase', () {
    late SetPresenceUseCase setPresenceUseCase;

    setUp(() {
      setPresenceUseCase = SetPresenceUseCase(presenceRepository);
    });

    final params = SetPresenceParams(
      roomId: roomId,
      userId: userId,
      username: username,
      isAnonymous: isAnonymous,
    );

    test('should delegate to IPresenceRepository.setPresence with the unpacked '
        'params (VS-PRE-01)', () async {
      when(
        () => presenceRepository.setPresence(
          roomId: any(named: 'roomId'),
          userId: any(named: 'userId'),
          username: any(named: 'username'),
          isAnonymous: any(named: 'isAnonymous'),
        ),
      ).thenAnswer((_) async => const Right(null));

      await setPresenceUseCase(params);

      verify(
        () => presenceRepository.setPresence(
          roomId: roomId,
          userId: userId,
          username: username,
          isAnonymous: isAnonymous,
        ),
      ).called(1);
    });

    test(
      'should propagate Left(FirebaseFailure) unchanged on repository failure',
      () async {
        when(
          () => presenceRepository.setPresence(
            roomId: any(named: 'roomId'),
            userId: any(named: 'userId'),
            username: any(named: 'username'),
            isAnonymous: any(named: 'isAnonymous'),
          ),
        ).thenAnswer(
          (_) async => const Left(Failure.firebase(message: 'write failed')),
        );

        final result = await setPresenceUseCase(params);

        expect(result.isLeft, isTrue);
        expect(result.left, isA<FirebaseFailure>());
      },
    );
  });

  group('RemovePresenceUseCase', () {
    late RemovePresenceUseCase removePresenceUseCase;

    setUp(() {
      removePresenceUseCase = RemovePresenceUseCase(presenceRepository);
    });

    final params = RemovePresenceParams(roomId: roomId, userId: userId);

    test('should delegate to IPresenceRepository.removePresence with the '
        'unpacked params', () async {
      when(
        () => presenceRepository.removePresence(
          roomId: any(named: 'roomId'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) async => const Right(null));

      await removePresenceUseCase(params);

      verify(
        () => presenceRepository.removePresence(roomId: roomId, userId: userId),
      ).called(1);
    });

    test(
      'should propagate Left(FirebaseFailure) unchanged on repository failure',
      () async {
        when(
          () => presenceRepository.removePresence(
            roomId: any(named: 'roomId'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer(
          (_) async => const Left(Failure.firebase(message: 'remove failed')),
        );

        final result = await removePresenceUseCase(params);

        expect(result.isLeft, isTrue);
        expect(result.left, isA<FirebaseFailure>());
      },
    );
  });
}
