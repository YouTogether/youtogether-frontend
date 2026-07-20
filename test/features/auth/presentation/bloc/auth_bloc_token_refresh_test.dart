import 'package:bloc_test/bloc_test.dart';
import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/core/usecases/usecase.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';
import 'package:youtogether/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:youtogether/features/auth/domain/usecases/logout_usecase.dart';
import 'package:youtogether/features/auth/domain/usecases/refresh_token_usecase.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_event.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_state.dart';

class MockGetCurrentUserUseCase extends Mock implements GetCurrentUserUseCase {}

class MockRefreshTokenUseCase extends Mock implements RefreshTokenUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

/// Unit tests for `AuthBloc`'s `tokenRefreshRequested` handler (F-INF-T1,
/// gap 6 of ADR-001).
///
/// This event is dispatched internally by [AuthInterceptor] on an
/// intercepted 401 — see `test/core/network/auth_interceptor_test.dart`
/// for the interceptor side of this collaboration. This file only
/// verifies the Bloc's own reaction in isolation, mirroring
/// `auth_bloc_test.dart`'s existing structure for `checkStatusRequested`.
///
/// @competency Unit test harness, TDD cycle.
void main() {
  late MockGetCurrentUserUseCase getCurrentUserUseCase;
  late MockRefreshTokenUseCase refreshTokenUseCase;
  late MockLogoutUseCase logoutUseCase;

  final mockUser = UserEntity(
    id: '550e8400-e29b-41d4-a716-446655440000',
    email: 'test@example.com',
    displayName: 'testuser',
    role: UserRole.registered,
    createdAt: DateTime.utc(2025, 1, 1),
  );

  setUp(() {
    getCurrentUserUseCase = MockGetCurrentUserUseCase();
    refreshTokenUseCase = MockRefreshTokenUseCase();
    logoutUseCase = MockLogoutUseCase();
  });

  AuthBloc buildBloc() => AuthBloc(
    getCurrentUserUseCase: getCurrentUserUseCase,
    refreshTokenUseCase: refreshTokenUseCase,
    logoutUseCase: logoutUseCase,
  );

  group('AuthBloc.tokenRefreshRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [authenticated] (no loading) on a successful refresh',
      setUp: () {
        when(
          () => refreshTokenUseCase(const NoParams()),
        ).thenAnswer((_) async => Right(mockUser));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthEvent.tokenRefreshRequested()),
      expect: () => [AuthState.authenticated(mockUser)],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [unauthenticated] (no loading) when the refresh fails',
      setUp: () {
        when(() => refreshTokenUseCase(const NoParams())).thenAnswer(
          (_) async => const Left(
            Failure.auth(message: 'Invalid or expired refresh token.'),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthEvent.tokenRefreshRequested()),
      expect: () => [const AuthState.unauthenticated()],
    );

    blocTest<AuthBloc, AuthState>(
      'calls RefreshTokenUseCase exactly once',
      setUp: () {
        when(
          () => refreshTokenUseCase(const NoParams()),
        ).thenAnswer((_) async => Right(mockUser));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthEvent.tokenRefreshRequested()),
      verify: (_) {
        verify(() => refreshTokenUseCase(const NoParams())).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'does not emit AuthState.loading — this is a silent, background '
      'refresh and must not disrupt whatever the rest of the app is '
      'currently rendering based on AuthBloc.state',
      setUp: () {
        when(
          () => refreshTokenUseCase(const NoParams()),
        ).thenAnswer((_) async => Right(mockUser));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthEvent.tokenRefreshRequested()),
      expect: () => [AuthState.authenticated(mockUser)],
    );
  });
}
