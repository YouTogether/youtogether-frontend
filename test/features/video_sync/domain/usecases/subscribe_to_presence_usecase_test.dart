import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/video_sync/domain/entities/presence_entity.dart';
import 'package:youtogether/features/video_sync/domain/repositories/i_presence_repository.dart';
import 'package:youtogether/features/video_sync/domain/usecases/subscribe_to_presence_usecase.dart';

class MockIPresenceRepository extends Mock implements IPresenceRepository {}

/// Unit tests for [SubscribeToPresenceUseCase].
///
/// Stream-returning use case, mirroring
/// `subscribe_to_playback_state_usecase_test.dart` and extending
/// `StreamUseCase`.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenario: combined presence count.
void main() {
  late MockIPresenceRepository presenceRepository;
  late SubscribeToPresenceUseCase subscribeToPresenceUseCase;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';

  final presenceList = [
    PresenceEntity(
      userId: '550e8400-e29b-41d4-a716-446655440000',
      username: 'Alice',
      isOnline: true,
      lastSeen: DateTime.utc(2026, 1, 5, 12, 30),
    ),
  ];

  setUp(() {
    presenceRepository = MockIPresenceRepository();
    subscribeToPresenceUseCase = SubscribeToPresenceUseCase(presenceRepository);
  });

  group('SubscribeToPresenceUseCase', () {
    test('should delegate to IPresenceRepository.subscribeToPresence with the '
        'room id', () {
      when(
        () => presenceRepository.subscribeToPresence(
          roomId: any(named: 'roomId'),
        ),
      ).thenAnswer((_) => Stream.value(Right(presenceList)));

      subscribeToPresenceUseCase(roomId);

      verify(
        () => presenceRepository.subscribeToPresence(roomId: roomId),
      ).called(1);
    });

    test('should forward every emitted Right(List<PresenceEntity>) unchanged '
        '(VS-PRE-02)', () async {
      when(
        () => presenceRepository.subscribeToPresence(
          roomId: any(named: 'roomId'),
        ),
      ).thenAnswer((_) => Stream.value(Right(presenceList)));

      final results = await subscribeToPresenceUseCase(roomId).toList();

      expect(results, [Right<Failure, List<PresenceEntity>>(presenceList)]);
    });
  });
}
