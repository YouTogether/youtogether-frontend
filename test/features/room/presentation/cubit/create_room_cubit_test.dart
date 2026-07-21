import 'package:bloc_test/bloc_test.dart';
import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/room/domain/entities/room_entity.dart';
import 'package:youtogether/features/room/domain/usecases/create_room_params.dart';
import 'package:youtogether/features/room/domain/usecases/create_room_usecase.dart';
import 'package:youtogether/features/room/presentation/cubit/create_room_cubit.dart';
import 'package:youtogether/features/room/presentation/cubit/create_room_state.dart';

class MockCreateRoomUseCase extends Mock implements CreateRoomUseCase {}

/// Unit tests for [CreateRoomCubit].
///
/// Mirrors `register_cubit_test.dart`: client-side validation rejects
/// before any network call, mirroring the backend's `CreateRoomDto`
/// constraints exactly.
///
/// @competency Unit test harness, TDD cycle.
/// @competency Test scenarios R-CRE-03, R-CRE-04 (client-side mirror).
void main() {
  late MockCreateRoomUseCase createRoomUseCase;

  setUpAll(() {
    registerFallbackValue(
      CreateRoomParams(name: 'fallback', description: null, isPublic: true),
    );
  });

  setUp(() {
    createRoomUseCase = MockCreateRoomUseCase();
  });

  CreateRoomCubit buildCubit() => CreateRoomCubit(createRoomUseCase);

  final createdRoom = RoomEntity(
    id: '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f',
    name: 'Friday Movie Night',
    description: 'Weekly watch party',
    ownerId: '550e8400-e29b-41d4-a716-446655440000',
    isPublic: true,
    memberCount: 1,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  group('createRoom — validation', () {
    blocTest<CreateRoomCubit, CreateRoomState>(
      'emits failure(ValidationFailure) for an empty name, without calling '
      'the use case',
      build: buildCubit,
      act: (cubit) => cubit.createRoom(name: '', description: null),
      expect: () => [
        isA<CreateRoomFailure>().having(
          (s) => s.failure,
          'failure',
          isA<ValidationFailure>(),
        ),
      ],
      verify: (_) {
        verifyNever(() => createRoomUseCase(any()));
      },
    );

    blocTest<CreateRoomCubit, CreateRoomState>(
      'emits failure(ValidationFailure) for a name exceeding 100 characters',
      build: buildCubit,
      act: (cubit) => cubit.createRoom(
        name: List.filled(101, 'a').join(),
        description: null,
      ),
      expect: () => [
        isA<CreateRoomFailure>().having(
          (s) => (s.failure as ValidationFailure).errors,
          'errors',
          contains('name'),
        ),
      ],
    );
  });

  group('createRoom — success', () {
    blocTest<CreateRoomCubit, CreateRoomState>(
      'emits [loading, success(room)] for a valid submission',
      build: () {
        when(
          () => createRoomUseCase(any()),
        ).thenAnswer((_) async => Right(createdRoom));
        return buildCubit();
      },
      act: (cubit) => cubit.createRoom(
        name: 'Friday Movie Night',
        description: 'Weekly watch party',
        isPublic: true,
      ),
      expect: () => [
        const CreateRoomState.loading(),
        CreateRoomState.success(createdRoom),
      ],
    );

    blocTest<CreateRoomCubit, CreateRoomState>(
      'defaults isPublic to true when not specified',
      build: () {
        when(
          () => createRoomUseCase(any()),
        ).thenAnswer((_) async => Right(createdRoom));
        return buildCubit();
      },
      act: (cubit) => cubit.createRoom(name: 'Friday Movie Night'),
      verify: (_) {
        verify(
          () => createRoomUseCase(
            CreateRoomParams(
              name: 'Friday Movie Night',
              description: null,
              isPublic: true,
            ),
          ),
        ).called(1);
      },
    );
  });

  group('createRoom — server failure', () {
    blocTest<CreateRoomCubit, CreateRoomState>(
      'emits [loading, failure] when the use case returns a server '
      'validation failure',
      build: () {
        when(() => createRoomUseCase(any())).thenAnswer(
          (_) async => const Left(
            Failure.server(
              statusCode: 400,
              message: 'name must not exceed 100 characters',
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.createRoom(name: 'Friday Movie Night'),
      expect: () => [const CreateRoomState.loading(), isA<CreateRoomFailure>()],
    );
  });

  group('reset', () {
    blocTest<CreateRoomCubit, CreateRoomState>(
      'emits CreateRoomState.initial when called after a success',
      build: () {
        when(
          () => createRoomUseCase(any()),
        ).thenAnswer((_) async => Right(createdRoom));
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.createRoom(name: 'Friday Movie Night');
        cubit.reset();
      },
      expect: () => [
        const CreateRoomState.loading(),
        CreateRoomState.success(createdRoom),
        const CreateRoomState.initial(),
      ],
    );
  });
}
