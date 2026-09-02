import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/auth/domain/entities/firebase_session_entity.dart';
import 'package:youtogether/features/auth/domain/repositories/i_firebase_session_repository.dart';
import 'package:youtogether/features/auth/domain/usecases/establish_firebase_session_params.dart';
import 'package:youtogether/features/auth/domain/usecases/establish_firebase_session_usecase.dart';

/// Mocktail mock for [IFirebaseSessionRepository].
///
/// Declared locally, per the convention established across the auth
/// domain test suite (see `register_usecase_test.dart`).
class MockFirebaseSessionRepository extends Mock
    implements IFirebaseSessionRepository {}

/// Unit tests for [EstablishFirebaseSessionUseCase].
///
/// The suite is organised around the four cold-start situations named
/// in the use case's own doc comment, because the reuse decision — not
/// the delegation — is what this class exists for.
///
/// The stale-session group is the load-bearing one. A persisted Firebase
/// session belonging to a previously signed-in account is
/// indistinguishable, to the security rules, from a legitimate one:
/// they verify that `auth.uid` matches `leader_id`, not that `auth.uid`
/// is who the application currently believes the user to be. If reuse
/// were ever widened to accept it, presence nodes and playback commands
/// would be written under the wrong identity and every rule would
/// authorise them.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios A-FBS-01 to A-FBS-05.
void main() {
  late MockFirebaseSessionRepository firebaseSessionRepository;
  late EstablishFirebaseSessionUseCase establishFirebaseSessionUseCase;

  const appUserId = '550e8400-e29b-41d4-a716-446655440000';
  const otherUserId = '660e8400-e29b-41d4-a716-446655440001';

  const namedSession = FirebaseSessionEntity(
    uid: appUserId,
    isAnonymous: false,
  );
  const staleNamedSession = FirebaseSessionEntity(
    uid: otherUserId,
    isAnonymous: false,
  );
  const anonymousSession = FirebaseSessionEntity(
    uid: 'firebase-generated-anonymous-uid',
    isAnonymous: true,
  );

  const signedIn = EstablishFirebaseSessionParams(appUserId: appUserId);
  const visitor = EstablishFirebaseSessionParams(appUserId: null);

  setUp(() {
    firebaseSessionRepository = MockFirebaseSessionRepository();
    establishFirebaseSessionUseCase = EstablishFirebaseSessionUseCase(
      firebaseSessionRepository,
    );

    when(
      () => firebaseSessionRepository.signOut(),
    ).thenAnswer((_) async => const Right(null));
  });

  group('no existing session (A-FBS-01)', () {
    test('should sign in with a custom token for a signed-in user', () async {
      when(() => firebaseSessionRepository.currentSession).thenReturn(null);
      when(
        () => firebaseSessionRepository.signInWithCustomToken(),
      ).thenAnswer((_) async => const Right(namedSession));

      final result = await establishFirebaseSessionUseCase(signedIn);

      expect(result.right, namedSession);
      verify(() => firebaseSessionRepository.signInWithCustomToken()).called(1);
      verifyNever(() => firebaseSessionRepository.signInAnonymously());
    });

    test('should sign in anonymously for a visitor', () async {
      when(() => firebaseSessionRepository.currentSession).thenReturn(null);
      when(
        () => firebaseSessionRepository.signInAnonymously(),
      ).thenAnswer((_) async => const Right(anonymousSession));

      final result = await establishFirebaseSessionUseCase(visitor);

      expect(result.right, anonymousSession);
      verify(() => firebaseSessionRepository.signInAnonymously()).called(1);
      verifyNever(() => firebaseSessionRepository.signInWithCustomToken());
    });

    test(
      'should not attempt to release a session that does not exist',
      () async {
        when(() => firebaseSessionRepository.currentSession).thenReturn(null);
        when(
          () => firebaseSessionRepository.signInAnonymously(),
        ).thenAnswer((_) async => const Right(anonymousSession));

        await establishFirebaseSessionUseCase(visitor);

        verifyNever(() => firebaseSessionRepository.signOut());
      },
    );
  });

  group('reusable existing session (A-FBS-02)', () {
    test(
      'should reuse a named session belonging to the signed-in user',
      () async {
        when(
          () => firebaseSessionRepository.currentSession,
        ).thenReturn(namedSession);

        final result = await establishFirebaseSessionUseCase(signedIn);

        expect(result.right, namedSession);
        verifyNever(() => firebaseSessionRepository.signInWithCustomToken());
        verifyNever(() => firebaseSessionRepository.signOut());
      },
    );

    test('should reuse an anonymous session for a visitor', () async {
      when(
        () => firebaseSessionRepository.currentSession,
      ).thenReturn(anonymousSession);

      final result = await establishFirebaseSessionUseCase(visitor);

      expect(result.right, anonymousSession);
      verifyNever(() => firebaseSessionRepository.signInAnonymously());
      verifyNever(() => firebaseSessionRepository.signOut());
    });
  });

  group('stale existing session (A-FBS-03)', () {
    test('should replace a session belonging to a different account', () async {
      when(
        () => firebaseSessionRepository.currentSession,
      ).thenReturn(staleNamedSession);
      when(
        () => firebaseSessionRepository.signInWithCustomToken(),
      ).thenAnswer((_) async => const Right(namedSession));

      final result = await establishFirebaseSessionUseCase(signedIn);

      expect(result.right, namedSession);
      verify(() => firebaseSessionRepository.signOut()).called(1);
      verify(() => firebaseSessionRepository.signInWithCustomToken()).called(1);
    });

    test(
      'should release before signing in, never the other way round',
      () async {
        final callOrder = <String>[];
        when(
          () => firebaseSessionRepository.currentSession,
        ).thenReturn(staleNamedSession);
        when(() => firebaseSessionRepository.signOut()).thenAnswer((_) async {
          callOrder.add('signOut');
          return const Right(null);
        });
        when(
          () => firebaseSessionRepository.signInWithCustomToken(),
        ).thenAnswer((_) async {
          callOrder.add('signIn');
          return const Right(namedSession);
        });

        await establishFirebaseSessionUseCase(signedIn);

        expect(callOrder, ['signOut', 'signIn']);
      },
    );

    test('should replace an anonymous session once a user signs in', () async {
      when(
        () => firebaseSessionRepository.currentSession,
      ).thenReturn(anonymousSession);
      when(
        () => firebaseSessionRepository.signInWithCustomToken(),
      ).thenAnswer((_) async => const Right(namedSession));

      final result = await establishFirebaseSessionUseCase(signedIn);

      expect(result.right, namedSession);
      verify(() => firebaseSessionRepository.signOut()).called(1);
    });

    test('should replace a named session once the user logs out', () async {
      when(
        () => firebaseSessionRepository.currentSession,
      ).thenReturn(namedSession);
      when(
        () => firebaseSessionRepository.signInAnonymously(),
      ).thenAnswer((_) async => const Right(anonymousSession));

      final result = await establishFirebaseSessionUseCase(visitor);

      expect(result.right, anonymousSession);
      verify(() => firebaseSessionRepository.signOut()).called(1);
      verify(() => firebaseSessionRepository.signInAnonymously()).called(1);
    });
  });

  group('failure propagation (A-FBS-04, A-FBS-05)', () {
    test(
      'should report a failed release without signing in (A-FBS-04)',
      () async {
        // Signing in over a session that refused to end would leave the
        // SDK in a state nothing downstream can reason about.
        when(
          () => firebaseSessionRepository.currentSession,
        ).thenReturn(staleNamedSession);
        when(
          () => firebaseSessionRepository.signOut(),
        ).thenAnswer((_) async => const Left(Failure.network()));

        final result = await establishFirebaseSessionUseCase(signedIn);

        expect(result.isLeft, isTrue);
        expect(result.left, isA<NetworkFailure>());
        verifyNever(() => firebaseSessionRepository.signInWithCustomToken());
      },
    );

    test(
      'should propagate a token issuance failure unchanged (A-FBS-05)',
      () async {
        when(() => firebaseSessionRepository.currentSession).thenReturn(null);
        when(
          () => firebaseSessionRepository.signInWithCustomToken(),
        ).thenAnswer(
          (_) async => const Left(
            Failure.server(statusCode: 502, message: 'token unavailable'),
          ),
        );

        final result = await establishFirebaseSessionUseCase(signedIn);

        expect(
          result.left,
          isA<ServerFailure>().having(
            (failure) => failure.statusCode,
            'statusCode',
            502,
          ),
        );
      },
    );

    test('should propagate an anonymous sign-in failure unchanged', () async {
      when(() => firebaseSessionRepository.currentSession).thenReturn(null);
      when(
        () => firebaseSessionRepository.signInAnonymously(),
      ).thenAnswer((_) async => const Left(Failure.network()));

      final result = await establishFirebaseSessionUseCase(visitor);

      expect(result.left, isA<NetworkFailure>());
    });
  });
}
