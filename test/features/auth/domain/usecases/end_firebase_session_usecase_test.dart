import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/core/usecases/usecase.dart';
import 'package:youtogether/features/auth/domain/repositories/i_firebase_session_repository.dart';
import 'package:youtogether/features/auth/domain/usecases/end_firebase_session_usecase.dart';

class MockFirebaseSessionRepository extends Mock
    implements IFirebaseSessionRepository {}

/// Unit tests for [EndFirebaseSessionUseCase].
///
/// A thin delegation, tested as such — mirroring
/// `logout_usecase_test.dart`.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios A-FBS-06.
void main() {
  late MockFirebaseSessionRepository firebaseSessionRepository;
  late EndFirebaseSessionUseCase endFirebaseSessionUseCase;

  setUp(() {
    firebaseSessionRepository = MockFirebaseSessionRepository();
    endFirebaseSessionUseCase = EndFirebaseSessionUseCase(
      firebaseSessionRepository,
    );
  });

  group('EndFirebaseSessionUseCase', () {
    test('should delegate to IFirebaseSessionRepository.signOut', () async {
      when(
        () => firebaseSessionRepository.signOut(),
      ).thenAnswer((_) async => const Right(null));

      await endFirebaseSessionUseCase(const NoParams());

      verify(() => firebaseSessionRepository.signOut()).called(1);
    });

    test('should return Right on success (A-FBS-06)', () async {
      when(
        () => firebaseSessionRepository.signOut(),
      ).thenAnswer((_) async => const Right(null));

      final result = await endFirebaseSessionUseCase(const NoParams());

      expect(result.isRight, isTrue);
    });

    test('should propagate a failure unchanged', () async {
      when(
        () => firebaseSessionRepository.signOut(),
      ).thenAnswer((_) async => const Left(Failure.network()));

      final result = await endFirebaseSessionUseCase(const NoParams());

      expect(result.isLeft, isTrue);
      expect(result.left, isA<NetworkFailure>());
    });
  });
}
