import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/core/error/exceptions.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/auth/data/datasources/i_firebase_session_data_source.dart';
import 'package:youtogether/features/auth/data/datasources/i_firebase_token_remote_data_source.dart';
import 'package:youtogether/features/auth/data/models/firebase_session_model.dart';
import 'package:youtogether/features/auth/data/repositories/firebase_session_repository_impl.dart';

class MockFirebaseTokenRemoteDataSource extends Mock
    implements IFirebaseTokenRemoteDataSource {}

class MockFirebaseSessionDataSource extends Mock
    implements IFirebaseSessionDataSource {}

/// Unit tests for [FirebaseSessionRepositoryImpl].
///
/// The failure-mapping group is the reason this suite exists. This is
/// the only repository in the codebase spanning two systems, and the
/// distinction it preserves is operationally meaningful: "the backend
/// would not issue a token" and "Firebase would not accept it" have
/// entirely different remedies, and collapsing both into one failure
/// type would leave the presentation layer unable to tell the user
/// which one happened.
///
/// The 401 case is singled out deliberately. Mapping it to
/// `AuthFailure` rather than `ServerFailure` is what tells
/// `FirebaseSessionCubit` (F-A06-T3) to fall back to an anonymous
/// session instead of retrying a call that will keep failing.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios A-FBS-01, A-FBS-05, A-FBS-07.
void main() {
  late MockFirebaseTokenRemoteDataSource tokenRemoteDataSource;
  late MockFirebaseSessionDataSource sessionDataSource;
  late FirebaseSessionRepositoryImpl repository;

  const uid = '550e8400-e29b-41d4-a716-446655440000';
  const namedModel = FirebaseSessionModel(uid: uid, isAnonymous: false);
  const anonymousModel = FirebaseSessionModel(
    uid: 'anon-uid',
    isAnonymous: true,
  );

  setUp(() {
    tokenRemoteDataSource = MockFirebaseTokenRemoteDataSource();
    sessionDataSource = MockFirebaseSessionDataSource();
    repository = FirebaseSessionRepositoryImpl(
      tokenRemoteDataSource: tokenRemoteDataSource,
      sessionDataSource: sessionDataSource,
    );
  });

  group('currentSession', () {
    test('should return null when the data source holds none', () {
      when(() => sessionDataSource.currentSession).thenReturn(null);

      expect(repository.currentSession, isNull);
    });

    test('should map the model to a domain entity', () {
      when(() => sessionDataSource.currentSession).thenReturn(namedModel);

      final result = repository.currentSession;

      expect(result?.uid, uid);
      expect(result?.isAnonymous, isFalse);
    });
  });

  group('signInWithCustomToken', () {
    test(
      'should fetch a token then exchange it, in that order (A-FBS-01)',
      () async {
        final callOrder = <String>[];
        when(() => tokenRemoteDataSource.fetchCustomToken()).thenAnswer((
          _,
        ) async {
          callOrder.add('fetch');
          return 'a.b.c';
        });
        when(() => sessionDataSource.signInWithCustomToken(any())).thenAnswer((
          _,
        ) async {
          callOrder.add('exchange');
          return namedModel;
        });

        final result = await repository.signInWithCustomToken();

        expect(callOrder, ['fetch', 'exchange']);
        expect(result.right.uid, uid);
        verify(
          () => sessionDataSource.signInWithCustomToken('a.b.c'),
        ).called(1);
      },
    );

    test(
      'should map a 401 to AuthFailure, not ServerFailure (A-FBS-07)',
      () async {
        when(() => tokenRemoteDataSource.fetchCustomToken()).thenThrow(
          const ServerException(statusCode: 401, message: 'Unauthorized'),
        );

        final result = await repository.signInWithCustomToken();

        expect(result.left, isA<AuthFailure>());
        verifyNever(() => sessionDataSource.signInWithCustomToken(any()));
      },
    );

    test('should map a 502 to ServerFailure, preserving the status code '
        '(A-FBS-05)', () async {
      when(() => tokenRemoteDataSource.fetchCustomToken()).thenThrow(
        const ServerException(statusCode: 502, message: 'token unavailable'),
      );

      final result = await repository.signInWithCustomToken();

      expect(
        result.left,
        isA<ServerFailure>().having(
          (failure) => failure.statusCode,
          'statusCode',
          502,
        ),
      );
    });

    test('should map NetworkException to NetworkFailure', () async {
      when(
        () => tokenRemoteDataSource.fetchCustomToken(),
      ).thenThrow(const NetworkException());

      final result = await repository.signInWithCustomToken();

      expect(result.left, isA<NetworkFailure>());
    });

    test(
      'should map a rejected token to FirebaseFailure, not ServerFailure',
      () async {
        // The backend issued a token; Firebase refused it. Different
        // system, different remedy — usually a project or clock
        // misconfiguration rather than anything the backend did wrong.
        when(
          () => tokenRemoteDataSource.fetchCustomToken(),
        ).thenAnswer((_) async => 'a.b.c');
        when(() => sessionDataSource.signInWithCustomToken(any())).thenThrow(
          FirebaseException(
            plugin: 'firebase_auth',
            code: 'invalid-custom-token',
            message: 'The custom token format is incorrect.',
          ),
        );

        final result = await repository.signInWithCustomToken();

        expect(result.left, isA<FirebaseFailure>());
      },
    );
  });

  group('signInAnonymously', () {
    test('should return the mapped anonymous session', () async {
      when(
        () => sessionDataSource.signInAnonymously(),
      ).thenAnswer((_) async => anonymousModel);

      final result = await repository.signInAnonymously();

      expect(result.right.uid, 'anon-uid');
      expect(result.right.isAnonymous, isTrue);
    });

    test('should not call the backend at all', () async {
      // An anonymous visitor has no account here to assert, so there is
      // nothing for the backend to mint.
      when(
        () => sessionDataSource.signInAnonymously(),
      ).thenAnswer((_) async => anonymousModel);

      await repository.signInAnonymously();

      verifyNever(() => tokenRemoteDataSource.fetchCustomToken());
    });

    test('should map a FirebaseException to FirebaseFailure', () async {
      when(() => sessionDataSource.signInAnonymously()).thenThrow(
        FirebaseException(
          plugin: 'firebase_auth',
          code: 'operation-not-allowed',
          message: 'Anonymous sign-in is disabled for this project.',
        ),
      );

      final result = await repository.signInAnonymously();

      expect(result.left, isA<FirebaseFailure>());
    });
  });

  group('signOut', () {
    test('should return Right on success', () async {
      when(() => sessionDataSource.signOut()).thenAnswer((_) async {});

      final result = await repository.signOut();

      expect(result.isRight, isTrue);
    });

    test('should map a FirebaseException to FirebaseFailure', () async {
      when(() => sessionDataSource.signOut()).thenThrow(
        FirebaseException(plugin: 'firebase_auth', code: 'network-error'),
      );

      final result = await repository.signOut();

      expect(result.left, isA<FirebaseFailure>());
    });
  });
}
