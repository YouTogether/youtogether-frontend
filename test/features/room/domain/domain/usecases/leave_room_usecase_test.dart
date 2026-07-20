import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/room/domain/repositories/i_room_repository.dart';
import 'package:youtogether/features/room/domain/usecases/leave_room_usecase.dart';

class MockIRoomRepository extends Mock implements IRoomRepository {}

/// Unit tests for [LeaveRoomUseCase].
///
/// The use case is a thin orchestrator; these tests verify delegation to
/// [IRoomRepository.leaveRoom], mirroring `delete_room_usecase_test.dart`
/// and the backend's own `leave-room.usecase.spec.ts`.
///
/// No dedicated `LeaveRoomParams` value object, for the same reason as
/// `JoinRoomUseCase`: the leaving user's identity is derived
/// server-side from the authenticated request, so a single `String`
/// room id is the entire input (contrast the backend's own
/// `LeaveRoomParams`, which carries `userId` out of necessity).
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios R-LEA-01, R-LEA-03, R-LEA-04.
void main() {
  late MockIRoomRepository roomRepository;
  late LeaveRoomUseCase leaveRoomUseCase;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';

  setUp(() {
    roomRepository = MockIRoomRepository();
    leaveRoomUseCase = LeaveRoomUseCase(roomRepository);
  });

  group('LeaveRoomUseCase', () {
    test(
      'should delegate to IRoomRepository.leaveRoom with the room id',
      () async {
        when(
          () => roomRepository.leaveRoom(roomId: any(named: 'roomId')),
        ).thenAnswer((_) async => const Right(null));

        await leaveRoomUseCase(roomId);

        verify(() => roomRepository.leaveRoom(roomId: roomId)).called(1);
      },
    );

    test('should return Right(null) on success (R-LEA-01)', () async {
      when(
        () => roomRepository.leaveRoom(roomId: any(named: 'roomId')),
      ).thenAnswer((_) async => const Right(null));

      final result = await leaveRoomUseCase(roomId);

      expect(result.isRight, isTrue);
    });

    test(
      'should propagate a not-found failure unchanged (no active membership, R-LEA-03)',
      () async {
        when(
          () => roomRepository.leaveRoom(roomId: any(named: 'roomId')),
        ).thenAnswer((_) async => const Left(Failure.notFound()));

        final result = await leaveRoomUseCase(roomId);

        expect(result.left, const Failure.notFound());
      },
    );

    test(
      'should propagate the owner-cannot-leave failure as AuthFailure (R-LEA-04)',
      () async {
        when(
          () => roomRepository.leaveRoom(roomId: any(named: 'roomId')),
        ).thenAnswer(
          (_) async => const Left(
            Failure.auth(
              message: 'owner cannot leave; delete the room instead',
            ),
          ),
        );

        final result = await leaveRoomUseCase(roomId);

        expect(result.isLeft, isTrue);
        expect(result.left, isA<AuthFailure>());
      },
    );
  });
}
