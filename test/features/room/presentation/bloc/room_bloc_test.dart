import 'package:bloc_test/bloc_test.dart';
import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/core/usecases/usecase.dart';
import 'package:youtogether/features/room/domain/entities/room_entity.dart';
import 'package:youtogether/features/room/domain/usecases/get_public_rooms_usecase.dart';
import 'package:youtogether/features/room/presentation/bloc/room_bloc.dart';
import 'package:youtogether/features/room/presentation/bloc/room_event.dart';
import 'package:youtogether/features/room/presentation/bloc/room_state.dart';

class MockGetPublicRoomsUseCase extends Mock implements GetPublicRoomsUseCase {}

/// Unit tests for [RoomBloc].
///
/// Uses `bloc_test`'s `blocTest` helper, the idiomatic way to assert a
/// Bloc's emitted state sequence for a given event.
///
/// @competency Unit test harness, TDD cycle.
void main() {
  late MockGetPublicRoomsUseCase getPublicRoomsUseCase;

  final rooms = [
    RoomEntity(
      id: '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f',
      name: 'Friday Movie Night',
      description: 'Weekly watch party',
      ownerId: '550e8400-e29b-41d4-a716-446655440000',
      isPublic: true,
      memberCount: 3,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
  ];

  const failure = Failure.network();

  setUp(() {
    getPublicRoomsUseCase = MockGetPublicRoomsUseCase();
  });

  RoomBloc buildBloc() =>
      RoomBloc(getPublicRoomsUseCase: getPublicRoomsUseCase);

  test('initial state is RoomState.initial()', () {
    expect(buildBloc().state, const RoomState.initial());
  });

  group('RoomEvent.fetchPublicRooms', () {
    blocTest<RoomBloc, RoomState>(
      'emits [loading, loaded] on success',
      build: () {
        when(
          () => getPublicRoomsUseCase(const NoParams()),
        ).thenAnswer((_) async => Right(rooms));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const RoomEvent.fetchPublicRooms()),
      expect: () => [const RoomState.loading(), RoomState.loaded(rooms)],
    );

    blocTest<RoomBloc, RoomState>(
      'emits [loading, failure] on repository failure',
      build: () {
        when(
          () => getPublicRoomsUseCase(const NoParams()),
        ).thenAnswer((_) async => const Left(failure));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const RoomEvent.fetchPublicRooms()),
      expect: () => [
        const RoomState.loading(),
        const RoomState.failure(failure),
      ],
    );

    blocTest<RoomBloc, RoomState>(
      'emits [loading, loaded([])] when no public rooms exist',
      build: () {
        when(
          () => getPublicRoomsUseCase(const NoParams()),
        ).thenAnswer((_) async => const Right([]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const RoomEvent.fetchPublicRooms()),
      expect: () => [const RoomState.loading(), const RoomState.loaded([])],
    );
  });

  group('RoomEvent.refreshRooms', () {
    blocTest<RoomBloc, RoomState>(
      'emits [loaded] directly on success, without an intermediate loading '
      'state (pull-to-refresh must not hide the existing list)',
      build: () {
        when(
          () => getPublicRoomsUseCase(const NoParams()),
        ).thenAnswer((_) async => Right(rooms));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const RoomEvent.refreshRooms()),
      expect: () => [RoomState.loaded(rooms)],
    );

    blocTest<RoomBloc, RoomState>(
      'emits [failure] directly on repository failure',
      build: () {
        when(
          () => getPublicRoomsUseCase(const NoParams()),
        ).thenAnswer((_) async => const Left(failure));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const RoomEvent.refreshRooms()),
      expect: () => [const RoomState.failure(failure)],
    );
  });
}
