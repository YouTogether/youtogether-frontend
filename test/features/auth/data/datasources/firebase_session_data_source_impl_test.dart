import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/features/auth/data/datasources/firebase_session_data_source_impl.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockUserCredential extends Mock implements UserCredential {}

/// Unit tests for [FirebaseSessionDataSourceImpl].
///
/// The SDK types are mocked rather than instantiated:
/// `FirebaseAuth.instance` requires platform channels a `flutter test`
/// process does not have, which is the whole reason
/// `IFirebaseSessionDataSource` exists.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios A-FBS-01, A-FBS-02, A-FBS-06.
void main() {
  late MockFirebaseAuth firebaseAuth;
  late FirebaseSessionDataSourceImpl dataSource;

  const uid = '550e8400-e29b-41d4-a716-446655440000';

  MockUser buildUser({required bool isAnonymous, String userId = uid}) {
    final user = MockUser();
    when(() => user.uid).thenReturn(userId);
    when(() => user.isAnonymous).thenReturn(isAnonymous);
    return user;
  }

  MockUserCredential buildCredential(User? user) {
    final credential = MockUserCredential();
    when(() => credential.user).thenReturn(user);
    return credential;
  }

  setUp(() {
    firebaseAuth = MockFirebaseAuth();
    dataSource = FirebaseSessionDataSourceImpl(firebaseAuth);
  });

  group('currentSession', () {
    test('should return null when the SDK holds no user', () {
      when(() => firebaseAuth.currentUser).thenReturn(null);

      expect(dataSource.currentSession, isNull);
    });

    test('should map a persisted named session (A-FBS-02)', () {
      final user = buildUser(isAnonymous: false);
      when(() => firebaseAuth.currentUser).thenReturn(user);

      final result = dataSource.currentSession;

      expect(result?.uid, uid);
      expect(result?.isAnonymous, isFalse);
    });

    test('should map a persisted anonymous session (A-FBS-02)', () {
      final user = buildUser(isAnonymous: true, userId: 'anon-uid');
      when(() => firebaseAuth.currentUser).thenReturn(user);

      final result = dataSource.currentSession;

      expect(result?.uid, 'anon-uid');
      expect(result?.isAnonymous, isTrue);
    });
  });

  group('signInWithCustomToken', () {
    test('should pass the token through to the SDK unchanged', () async {
      final credential = buildCredential(buildUser(isAnonymous: false));
      when(
        () => firebaseAuth.signInWithCustomToken(any()),
      ).thenAnswer((_) async => credential);

      await dataSource.signInWithCustomToken('a.b.c');

      verify(() => firebaseAuth.signInWithCustomToken('a.b.c')).called(1);
    });

    test('should map the resulting credential to a model (A-FBS-01)', () async {
      final credential = buildCredential(buildUser(isAnonymous: false));
      when(
        () => firebaseAuth.signInWithCustomToken(any()),
      ).thenAnswer((_) async => credential);

      final result = await dataSource.signInWithCustomToken('a.b.c');

      expect(result.uid, uid);
      expect(result.isAnonymous, isFalse);
    });

    test(
      'should throw FirebaseAuthException when the SDK returns no user',
      () async {
        // Nullable in the SDK's signature, never null in practice. Thrown
        // as a FirebaseAuthException rather than a StateError so the
        // repository's single FirebaseException catch clause covers it.
        final credential = buildCredential(null);
        when(
          () => firebaseAuth.signInWithCustomToken(any()),
        ).thenAnswer((_) async => credential);

        expect(
          () => dataSource.signInWithCustomToken('a.b.c'),
          throwsA(isA<FirebaseAuthException>()),
        );
      },
    );

    test('should let a FirebaseAuthException propagate unchanged', () async {
      when(
        () => firebaseAuth.signInWithCustomToken(any()),
      ).thenThrow(FirebaseAuthException(code: 'invalid-custom-token'));

      expect(
        () => dataSource.signInWithCustomToken('a.b.c'),
        throwsA(isA<FirebaseAuthException>()),
      );
    });
  });

  group('signInAnonymously', () {
    test('should map the resulting credential to an anonymous model', () async {
      final credential = buildCredential(
        buildUser(isAnonymous: true, userId: 'anon-uid'),
      );
      when(
        () => firebaseAuth.signInAnonymously(),
      ).thenAnswer((_) async => credential);

      final result = await dataSource.signInAnonymously();

      expect(result.uid, 'anon-uid');
      expect(result.isAnonymous, isTrue);
    });

    test('should let operation-not-allowed propagate unchanged', () async {
      // Raised when the Anonymous provider has not been enabled in the
      // Firebase console. A deployment prerequisite, surfaced rather
      // than swallowed so it is diagnosable.
      when(
        () => firebaseAuth.signInAnonymously(),
      ).thenThrow(FirebaseAuthException(code: 'operation-not-allowed'));

      expect(
        () => dataSource.signInAnonymously(),
        throwsA(
          isA<FirebaseAuthException>().having(
            (exception) => exception.code,
            'code',
            'operation-not-allowed',
          ),
        ),
      );
    });
  });

  group('signOut', () {
    test('should delegate to the SDK (A-FBS-06)', () async {
      when(() => firebaseAuth.signOut()).thenAnswer((_) async {});

      await dataSource.signOut();

      verify(() => firebaseAuth.signOut()).called(1);
    });
  });
}
