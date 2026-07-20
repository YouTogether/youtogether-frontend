import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/room/domain/repositories/i_room_repository.dart';
import 'package:youtogether/features/room/domain/usecases/delete_room_usecase.dart';

class MockIRoomRepository extends Mock implements IRoomRepository {}

/// Unit tests for [DeleteRoomUseCase] (F-R04-T1 — domain layer).
///
/// The use case is a thin orchestrator; these tests verify delegation to
/// [IRoomRepository.deleteRoom], mirroring
/// `update_room_usecase_test.dart` and the backend's
/// `delete-room.usecase.spec.ts`.
///
/// No dedicated `DeleteRoomParams` value object: this task's Definition
/// of Done describes the use case as simply "takes a room ID" — a
/// single-field wrapper class would add no value over the `String`
/// itself, unlike `UpdateRoomParams` (three fields).
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios R-DEL-01, R-DEL-05.
void main() {
  late MockIRoomRepository roomRepository;
  late DeleteRoomUseCase deleteRoomUseCase;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';

  setUp(() {
    roomRepository = MockIRoomRepository();
    deleteRoomUseCase = DeleteRoomUseCase(roomRepository);
  });

  group('DeleteRoomUseCase', () {
    test(
      'should delegate to IRoomRepository.deleteRoom with the room id',
      () async {
        when(
          () => roomRepository.deleteRoom(roomId: any(named: 'roomId')),
        ).thenAnswer((_) async => const Right(null));

        await deleteRoomUseCase(roomId);

        verify(() => roomRepository.deleteRoom(roomId: roomId)).called(1);
      },
    );

    test('should return Right(null) on success (R-DEL-01)', () async {
      when(
        () => roomRepository.deleteRoom(roomId: any(named: 'roomId')),
      ).thenAnswer((_) async => const Right(null));

      final result = await deleteRoomUseCase(roomId);

      expect(result.isRight, isTrue);
    });

    test(
      'should propagate Left(Failure) unchanged on repository failure (R-DEL-05)',
      () async {
        when(
          () => roomRepository.deleteRoom(roomId: any(named: 'roomId')),
        ).thenAnswer((_) async => const Left(Failure.notFound()));

        final result = await deleteRoomUseCase(roomId);

        expect(result.isLeft, isTrue);
        expect(result.left, const Failure.notFound());
      },
    );

    test('should propagate a 403 as Left(AuthFailure)', () async {
      when(
        () => roomRepository.deleteRoom(roomId: any(named: 'roomId')),
      ).thenAnswer(
        (_) async => const Left(Failure.auth(message: 'not the owner')),
      );

      final result = await deleteRoomUseCase(roomId);

      expect(result.left, isA<AuthFailure>());
    });
  });
}
