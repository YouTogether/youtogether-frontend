import 'package:bloc_test/bloc_test.dart';
import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/room/domain/entities/room_entity.dart';
import 'package:youtogether/features/room/domain/usecases/get_room_by_id_usecase.dart';
import 'package:youtogether/features/room/presentation/cubit/room_detail_cubit.dart';
import 'package:youtogether/features/room/presentation/cubit/room_detail_state.dart';

class MockGetRoomByIdUseCase extends Mock implements GetRoomByIdUseCase {}

/// Unit tests for [RoomDetailCubit].
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios R-DET-01, R-DET-02, R-DET-03.
void main() {
  late MockGetRoomByIdUseCase getRoomByIdUseCase;

  const roomId = '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f';

  final room = RoomEntity(
    id: roomId,
    name: 'Friday Movie Night',
    description: 'Weekly watch party',
    ownerId: '550e8400-e29b-41d4-a716-446655440000',
    isPublic: true,
    memberCount: 2,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    getRoomByIdUseCase = MockGetRoomByIdUseCase();
  });

  RoomDetailCubit buildCubit() => RoomDetailCubit(getRoomByIdUseCase);

  test('initial state is RoomDetailState.initial()', () {
    expect(buildCubit().state, const RoomDetailState.initial());
  });

  group('fetchRoom', () {
    blocTest<RoomDetailCubit, RoomDetailState>(
      'emits [loading, loaded(room)] on success',
      build: () {
        when(
          () => getRoomByIdUseCase(roomId),
        ).thenAnswer((_) async => Right(room));
        return buildCubit();
      },
      act: (cubit) => cubit.fetchRoom(roomId),
      expect: () => [
        const RoomDetailState.loading(),
        RoomDetailState.loaded(room),
      ],
    );

    blocTest<RoomDetailCubit, RoomDetailState>(
      'emits [loading, failure] on a not-found failure (R-DET-02/03)',
      build: () {
        when(
          () => getRoomByIdUseCase(roomId),
        ).thenAnswer((_) async => const Left(Failure.notFound()));
        return buildCubit();
      },
      act: (cubit) => cubit.fetchRoom(roomId),
      expect: () => [
        const RoomDetailState.loading(),
        const RoomDetailState.failure(Failure.notFound()),
      ],
    );
  });
}
