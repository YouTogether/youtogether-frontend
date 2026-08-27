import 'package:bloc_test/bloc_test.dart';
import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/video_sync/domain/entities/presence_entity.dart';
import 'package:youtogether/features/video_sync/domain/usecases/remove_presence_params.dart';
import 'package:youtogether/features/video_sync/domain/usecases/remove_presence_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/set_presence_params.dart';
import 'package:youtogether/features/video_sync/domain/usecases/set_presence_usecase.dart';
import 'package:youtogether/features/video_sync/domain/usecases/subscribe_to_presence_usecase.dart';
import 'package:youtogether/features/video_sync/presentation/cubit/presence_cubit.dart';
import 'package:youtogether/features/video_sync/presentation/cubit/presence_state.dart';

class MockSetPresenceUseCase extends Mock implements SetPresenceUseCase {}

class MockRemovePresenceUseCase extends Mock implements RemovePresenceUseCase {}

class MockSubscribeToPresenceUseCase extends Mock
    implements SubscribeToPresenceUseCase {}

/// Unit tests for [PresenceCubit].
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios.
void main() {
  late MockSetPresenceUseCase setPresenceUseCase;
  late MockRemovePresenceUseCase removePresenceUseCase;
  late MockSubscribeToPresenceUseCase subscribeToPresenceUseCase;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';
  const userId = '550e8400-e29b-41d4-a716-446655440000';
  const username = 'Alice';

  PresenceEntity participant(String id) => PresenceEntity(
    userId: id,
    username: 'User $id',
    isOnline: true,
    isAnonymous: false,
    lastSeen: DateTime.utc(2026, 1, 5),
  );

  setUpAll(() {
    registerFallbackValue(
      const SetPresenceParams(
        roomId: roomId,
        userId: userId,
        username: username,
        isAnonymous: false,
      ),
    );
    registerFallbackValue(
      const RemovePresenceParams(roomId: roomId, userId: userId),
    );
  });

  setUp(() {
    setPresenceUseCase = MockSetPresenceUseCase();
    removePresenceUseCase = MockRemovePresenceUseCase();
    subscribeToPresenceUseCase = MockSubscribeToPresenceUseCase();

    when(
      () => setPresenceUseCase(any()),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => removePresenceUseCase(any()),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => subscribeToPresenceUseCase(any()),
    ).thenAnswer((_) => const Stream.empty());
  });

  PresenceCubit buildCubit() => PresenceCubit(
    roomId: roomId,
    userId: userId,
    username: username,
    isAnonymous: false,
    setPresenceUseCase: setPresenceUseCase,
    removePresenceUseCase: removePresenceUseCase,
    subscribeToPresenceUseCase: subscribeToPresenceUseCase,
  );

  group('enterSession', () {
    blocTest<PresenceCubit, PresenceState>(
      'writes this participant\'s presence and opens the live subscription',
      build: buildCubit,
      act: (cubit) => cubit.enterSession(),
      verify: (_) {
        verify(
          () => setPresenceUseCase(
            const SetPresenceParams(
              roomId: roomId,
              userId: userId,
              username: username,
              isAnonymous: false,
            ),
          ),
        ).called(1);
        verify(() => subscribeToPresenceUseCase(roomId)).called(1);
      },
    );

    blocTest<PresenceCubit, PresenceState>(
      'emits loading then loaded with the live participant list',
      build: () {
        when(() => subscribeToPresenceUseCase(any())).thenAnswer(
          (_) => Stream.value(Right([participant('a'), participant('b')])),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.enterSession(),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        const PresenceState.loading(),
        isA<PresenceLoaded>().having((s) => s.participants.length, 'count', 2),
      ],
    );

    blocTest<PresenceCubit, PresenceState>(
      'emits loaded with an empty list when nobody is present — zero is a '
      'valid count, not an error',
      build: () {
        when(
          () => subscribeToPresenceUseCase(any()),
        ).thenAnswer((_) => Stream.value(const Right(<PresenceEntity>[])));
        return buildCubit();
      },
      act: (cubit) => cubit.enterSession(),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        const PresenceState.loading(),
        const PresenceState.loaded(<PresenceEntity>[]),
      ],
    );

    blocTest<PresenceCubit, PresenceState>(
      'emits failure and does not subscribe when writing presence fails',
      build: () {
        when(() => setPresenceUseCase(any())).thenAnswer(
          (_) async => const Left(Failure.firebase(message: 'denied')),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.enterSession(),
      expect: () => [
        const PresenceState.loading(),
        const PresenceState.failure(Failure.firebase(message: 'denied')),
      ],
      verify: (_) => verifyNever(() => subscribeToPresenceUseCase(any())),
    );

    blocTest<PresenceCubit, PresenceState>(
      'emits failure when the live subscription reports a failure',
      build: () {
        when(() => subscribeToPresenceUseCase(any())).thenAnswer(
          (_) => Stream.value(const Left(Failure.firebase(message: 'lost'))),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.enterSession(),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        const PresenceState.loading(),
        const PresenceState.failure(Failure.firebase(message: 'lost')),
      ],
    );
  });

  group('anonymous participants', () {
    blocTest<PresenceCubit, PresenceState>(
      'forwards isAnonymous: true through to SetPresenceParams',
      build: () => PresenceCubit(
        roomId: roomId,
        userId: userId,
        username: 'Guest',
        isAnonymous: true,
        setPresenceUseCase: setPresenceUseCase,
        removePresenceUseCase: removePresenceUseCase,
        subscribeToPresenceUseCase: subscribeToPresenceUseCase,
      ),
      act: (cubit) => cubit.enterSession(),
      verify: (_) {
        verify(
          () => setPresenceUseCase(
            const SetPresenceParams(
              roomId: roomId,
              userId: userId,
              username: 'Guest',
              isAnonymous: true,
            ),
          ),
        ).called(1);
      },
    );
  });

  group('leaveSession', () {
    blocTest<PresenceCubit, PresenceState>(
      'clears this participant\'s presence',
      build: buildCubit,
      act: (cubit) async {
        await cubit.enterSession();
        await cubit.leaveSession();
      },
      verify: (_) {
        verify(
          () => removePresenceUseCase(
            const RemovePresenceParams(roomId: roomId, userId: userId),
          ),
        ).called(1);
      },
    );

    blocTest<PresenceCubit, PresenceState>(
      'is idempotent — a second call does not clear presence twice',
      build: buildCubit,
      act: (cubit) async {
        await cubit.enterSession();
        await cubit.leaveSession();
        await cubit.leaveSession();
      },
      verify: (_) {
        verify(() => removePresenceUseCase(any())).called(1);
      },
    );

    blocTest<PresenceCubit, PresenceState>(
      'does nothing when the session was never entered',
      build: buildCubit,
      act: (cubit) => cubit.leaveSession(),
      verify: (_) => verifyNever(() => removePresenceUseCase(any())),
    );
  });

  group('close', () {
    test('clears presence automatically on close, so leaving the player page '
        'ends participation without any explicit user action', () async {
      final cubit = buildCubit();
      await cubit.enterSession();

      await cubit.close();

      verify(
        () => removePresenceUseCase(
          const RemovePresenceParams(roomId: roomId, userId: userId),
        ),
      ).called(1);
    });

    test(
      'does not clear presence twice when leaveSession preceded close',
      () async {
        final cubit = buildCubit();
        await cubit.enterSession();
        await cubit.leaveSession();

        await cubit.close();

        verify(() => removePresenceUseCase(any())).called(1);
      },
    );
  });
}
