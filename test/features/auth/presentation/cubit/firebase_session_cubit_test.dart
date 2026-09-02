import 'package:bloc_test/bloc_test.dart';
import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/core/usecases/usecase.dart';
import 'package:youtogether/features/auth/domain/entities/firebase_session_entity.dart';
import 'package:youtogether/features/auth/domain/usecases/end_firebase_session_usecase.dart';
import 'package:youtogether/features/auth/domain/usecases/establish_firebase_session_params.dart';
import 'package:youtogether/features/auth/domain/usecases/establish_firebase_session_usecase.dart';
import 'package:youtogether/features/auth/presentation/cubit/firebase_session_cubit.dart';
import 'package:youtogether/features/auth/presentation/cubit/firebase_session_state.dart';

class MockEstablishFirebaseSessionUseCase extends Mock
    implements EstablishFirebaseSessionUseCase {}

class MockEndFirebaseSessionUseCase extends Mock
    implements EndFirebaseSessionUseCase {}

/// Unit tests for [FirebaseSessionCubit].
///
/// Two behaviours are asserted for reasons beyond coverage.
///
/// The **re-entrancy guard**: `App` and `FirebaseSessionGate` can both
/// trigger a synchronisation within the same frame — a user signing in
/// and navigating straight into a room. Two concurrent sign-ins against
/// the same SDK singleton would race, and whichever resolved last would
/// win regardless of which identity it carried.
///
/// **`release` does not become an anonymous sign-in**: replacing a named
/// session with an anonymous one on logout would leave a live Firebase
/// credential on the device of a user who has just signed out. The
/// assertion that `EstablishFirebaseSessionUseCase` is never called
/// during a release is what pins that.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios A-FBS-08, A-FBS-09.
void main() {
  late MockEstablishFirebaseSessionUseCase establishFirebaseSessionUseCase;
  late MockEndFirebaseSessionUseCase endFirebaseSessionUseCase;

  const appUserId = '550e8400-e29b-41d4-a716-446655440000';
  const namedSession = FirebaseSessionEntity(
    uid: appUserId,
    isAnonymous: false,
  );
  const anonymousSession = FirebaseSessionEntity(
    uid: 'anon-uid',
    isAnonymous: true,
  );

  setUpAll(() {
    registerFallbackValue(
      const EstablishFirebaseSessionParams(appUserId: null),
    );
    registerFallbackValue(const NoParams());
  });

  setUp(() {
    establishFirebaseSessionUseCase = MockEstablishFirebaseSessionUseCase();
    endFirebaseSessionUseCase = MockEndFirebaseSessionUseCase();

    when(
      () => endFirebaseSessionUseCase(any()),
    ).thenAnswer((_) async => const Right(null));
  });

  FirebaseSessionCubit buildCubit() => FirebaseSessionCubit(
    establishFirebaseSessionUseCase: establishFirebaseSessionUseCase,
    endFirebaseSessionUseCase: endFirebaseSessionUseCase,
  );

  group('synchronise', () {
    blocTest<FirebaseSessionCubit, FirebaseSessionState>(
      'emits [establishing, ready] for a signed-in user (A-FBS-08)',
      build: () {
        when(
          () => establishFirebaseSessionUseCase(any()),
        ).thenAnswer((_) async => const Right(namedSession));
        return buildCubit();
      },
      act: (cubit) => cubit.synchronise(appUserId: appUserId),
      expect: () => [
        const FirebaseSessionState.establishing(),
        const FirebaseSessionState.ready(namedSession),
      ],
    );

    blocTest<FirebaseSessionCubit, FirebaseSessionState>(
      'emits [establishing, ready] for a visitor',
      build: () {
        when(
          () => establishFirebaseSessionUseCase(any()),
        ).thenAnswer((_) async => const Right(anonymousSession));
        return buildCubit();
      },
      act: (cubit) => cubit.synchronise(appUserId: null),
      expect: () => [
        const FirebaseSessionState.establishing(),
        const FirebaseSessionState.ready(anonymousSession),
      ],
    );

    blocTest<FirebaseSessionCubit, FirebaseSessionState>(
      'passes the application user id through to the use case, never '
      'anywhere else',
      build: () {
        when(
          () => establishFirebaseSessionUseCase(any()),
        ).thenAnswer((_) async => const Right(namedSession));
        return buildCubit();
      },
      act: (cubit) => cubit.synchronise(appUserId: appUserId),
      verify: (_) {
        verify(
          () => establishFirebaseSessionUseCase(
            const EstablishFirebaseSessionParams(appUserId: appUserId),
          ),
        ).called(1);
      },
    );

    blocTest<FirebaseSessionCubit, FirebaseSessionState>(
      'emits [establishing, failure] and keeps no session on failure',
      build: () {
        when(() => establishFirebaseSessionUseCase(any())).thenAnswer(
          (_) async => const Left(
            Failure.server(statusCode: 502, message: 'token unavailable'),
          ),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.synchronise(appUserId: appUserId),
      expect: () => [
        const FirebaseSessionState.establishing(),
        isA<FirebaseSessionFailure>(),
      ],
    );

    blocTest<FirebaseSessionCubit, FirebaseSessionState>(
      'ignores a second call while one is already in flight (A-FBS-09)',
      build: () {
        when(() => establishFirebaseSessionUseCase(any())).thenAnswer((
          _,
        ) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return const Right(namedSession);
        });
        return buildCubit();
      },
      act: (cubit) async {
        // Deliberately not awaited: this reproduces App and
        // FirebaseSessionGate triggering within the same frame.
        cubit.synchronise(appUserId: appUserId);
        await cubit.synchronise(appUserId: appUserId);
        await Future<void>.delayed(const Duration(milliseconds: 30));
      },
      expect: () => [
        const FirebaseSessionState.establishing(),
        const FirebaseSessionState.ready(namedSession),
      ],
      verify: (_) {
        verify(() => establishFirebaseSessionUseCase(any())).called(1);
      },
    );

    blocTest<FirebaseSessionCubit, FirebaseSessionState>(
      'allows a retry once a previous attempt has failed',
      build: () {
        when(
          () => establishFirebaseSessionUseCase(any()),
        ).thenAnswer((_) async => const Left(Failure.network()));
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.synchronise(appUserId: appUserId);
        await cubit.synchronise(appUserId: appUserId);
      },
      verify: (_) {
        verify(() => establishFirebaseSessionUseCase(any())).called(2);
      },
    );
  });

  group('release', () {
    blocTest<FirebaseSessionCubit, FirebaseSessionState>(
      'returns to initial and never signs in anonymously (A-FBS-09)',
      build: buildCubit,
      act: (cubit) => cubit.release(),
      expect: () => [const FirebaseSessionState.initial()],
      verify: (_) {
        verify(() => endFirebaseSessionUseCase(any())).called(1);
        verifyNever(() => establishFirebaseSessionUseCase(any()));
      },
    );

    blocTest<FirebaseSessionCubit, FirebaseSessionState>(
      'returns to initial even when the sign-out itself failed',
      build: () {
        when(
          () => endFirebaseSessionUseCase(any()),
        ).thenAnswer((_) async => const Left(Failure.network()));
        return buildCubit();
      },
      act: (cubit) => cubit.release(),
      expect: () => [const FirebaseSessionState.initial()],
    );
  });
}
