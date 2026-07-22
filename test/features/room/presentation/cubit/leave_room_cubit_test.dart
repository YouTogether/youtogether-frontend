import 'package:bloc_test/bloc_test.dart';
import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/room/domain/usecases/leave_room_usecase.dart';
import 'package:youtogether/features/room/presentation/cubit/leave_room_cubit.dart';
import 'package:youtogether/features/room/presentation/cubit/leave_room_state.dart';

class MockLeaveRoomUseCase extends Mock implements LeaveRoomUseCase {}

/// Unit tests for [LeaveRoomCubit] (F-R06-T3 — presentation layer).
///
/// Mirrors `delete_room_cubit_test.dart`: [LeaveRoomUseCase] returns
/// `void` on success, so [LeaveRoomState.success] carries no payload.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios R-LEA-01, R-LEA-03, R-LEA-04.
void main() {
  late MockLeaveRoomUseCase leaveRoomUseCase;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';

  setUp(() {
    leaveRoomUseCase = MockLeaveRoomUseCase();
  });

  LeaveRoomCubit buildCubit() => LeaveRoomCubit(leaveRoomUseCase);

  group('leaveRoom', () {
    blocTest<LeaveRoomCubit, LeaveRoomState>(
      'emits [loading, success] on success (R-LEA-01)',
      build: () {
        when(
          () => leaveRoomUseCase(roomId),
        ).thenAnswer((_) async => const Right(null));
        return buildCubit();
      },
      act: (cubit) => cubit.leaveRoom(roomId),
      expect: () => [
        const LeaveRoomState.loading(),
        const LeaveRoomState.success(),
      ],
    );

    blocTest<LeaveRoomCubit, LeaveRoomState>(
      'emits [loading, failure] when the caller has no active membership '
      '(R-LEA-03)',
      build: () {
        when(
          () => leaveRoomUseCase(roomId),
        ).thenAnswer((_) async => const Left(Failure.notFound()));
        return buildCubit();
      },
      act: (cubit) => cubit.leaveRoom(roomId),
      expect: () => [
        const LeaveRoomState.loading(),
        const LeaveRoomState.failure(Failure.notFound()),
      ],
    );

    blocTest<LeaveRoomCubit, LeaveRoomState>(
      'emits [loading, failure] when the owner attempts to leave (fallback '
      'in case the hidden button is somehow bypassed, R-LEA-04)',
      build: () {
        when(() => leaveRoomUseCase(roomId)).thenAnswer(
          (_) async => const Left(
            Failure.auth(
              message: 'owner cannot leave; delete the room instead',
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.leaveRoom(roomId),
      expect: () => [
        const LeaveRoomState.loading(),
        isA<LeaveRoomFailure>().having(
          (s) => s.failure,
          'failure',
          isA<AuthFailure>(),
        ),
      ],
    );
  });
}
