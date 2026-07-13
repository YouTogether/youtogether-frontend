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

  group('AuthBloc', () {
    test('initial state is AuthState.initial', () {
      expect(buildBloc().state, const AuthState.initial());
    });

    group('checkStatusRequested', () {
      blocTest<AuthBloc, AuthState>(
        'valid cached access token: emits [loading, authenticated] and '
        'never calls RefreshTokenUseCase',
        setUp: () {
          when(
            () => getCurrentUserUseCase(const NoParams()),
          ).thenAnswer((_) async => Right(mockUser));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const AuthEvent.checkStatusRequested()),
        expect: () => [
          const AuthState.loading(),
          AuthState.authenticated(mockUser),
        ],
        verify: (_) {
          verifyNever(() => refreshTokenUseCase(const NoParams()));
        },
      );

      blocTest<AuthBloc, AuthState>(
        'expired access token, valid refresh token: emits '
        '[loading, authenticated] after a silent refresh',
        setUp: () {
          when(() => getCurrentUserUseCase(const NoParams())).thenAnswer(
            (_) async => const Left(
              Failure.auth(message: 'Invalid or expired session.'),
            ),
          );
          when(
            () => refreshTokenUseCase(const NoParams()),
          ).thenAnswer((_) async => Right(mockUser));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const AuthEvent.checkStatusRequested()),
        expect: () => [
          const AuthState.loading(),
          AuthState.authenticated(mockUser),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'both access and refresh tokens expired/invalid: emits '
        '[loading, unauthenticated]',
        setUp: () {
          when(() => getCurrentUserUseCase(const NoParams())).thenAnswer(
            (_) async => const Left(
              Failure.auth(message: 'Invalid or expired session.'),
            ),
          );
          when(() => refreshTokenUseCase(const NoParams())).thenAnswer(
            (_) async => const Left(
              Failure.auth(message: 'Invalid or expired refresh token.'),
            ),
          );
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const AuthEvent.checkStatusRequested()),
        expect: () => [
          const AuthState.loading(),
          const AuthState.unauthenticated(),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'no cached token at all: emits [loading, unauthenticated] — both '
        'use cases still get called (each resolves purely locally, per '
        'AuthRepositoryImpl F-A03-T2), but no network round-trip occurs '
        'behind them',
        setUp: () {
          when(() => getCurrentUserUseCase(const NoParams())).thenAnswer(
            (_) async =>
                const Left(Failure.auth(message: 'No active session.')),
          );
          when(() => refreshTokenUseCase(const NoParams())).thenAnswer(
            (_) async =>
                const Left(Failure.auth(message: 'No refresh token cached.')),
          );
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const AuthEvent.checkStatusRequested()),
        expect: () => [
          const AuthState.loading(),
          const AuthState.unauthenticated(),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'calls GetCurrentUserUseCase exactly once per checkStatusRequested',
        setUp: () {
          when(
            () => getCurrentUserUseCase(const NoParams()),
          ).thenAnswer((_) async => Right(mockUser));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const AuthEvent.checkStatusRequested()),
        verify: (_) {
          verify(() => getCurrentUserUseCase(const NoParams())).called(1);
        },
      );

      blocTest<AuthBloc, AuthState>(
        'calls RefreshTokenUseCase exactly once when getCurrentUser fails',
        setUp: () {
          when(() => getCurrentUserUseCase(const NoParams())).thenAnswer(
            (_) async => const Left(Failure.auth(message: 'irrelevant')),
          );
          when(
            () => refreshTokenUseCase(const NoParams()),
          ).thenAnswer((_) async => Right(mockUser));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const AuthEvent.checkStatusRequested()),
        verify: (_) {
          verify(() => refreshTokenUseCase(const NoParams())).called(1);
        },
      );
    });

    group('logoutRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [loading, unauthenticated] on successful logout',
        setUp: () {
          when(
            () => logoutUseCase(const NoParams()),
          ).thenAnswer((_) async => const Right(null));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const AuthEvent.logoutRequested()),
        expect: () => [
          const AuthState.loading(),
          const AuthState.unauthenticated(),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [loading, failure] — not unauthenticated — when '
        'LogoutUseCase fails (e.g. local tokens could not actually be '
        'cleared)',
        setUp: () {
          when(() => logoutUseCase(const NoParams())).thenAnswer(
            (_) async => const Left(
              Failure.cache(message: 'Secure storage unavailable'),
            ),
          );
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const AuthEvent.logoutRequested()),
        expect: () => [
          const AuthState.loading(),
          const AuthState.failure(
            Failure.cache(message: 'Secure storage unavailable'),
          ),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'calls LogoutUseCase exactly once per logoutRequested',
        setUp: () {
          when(
            () => logoutUseCase(const NoParams()),
          ).thenAnswer((_) async => const Right(null));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const AuthEvent.logoutRequested()),
        verify: (_) {
          verify(() => logoutUseCase(const NoParams())).called(1);
        },
      );

      blocTest<AuthBloc, AuthState>(
        'does not call GetCurrentUserUseCase or RefreshTokenUseCase '
        'during logout',
        setUp: () {
          when(
            () => logoutUseCase(const NoParams()),
          ).thenAnswer((_) async => const Right(null));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const AuthEvent.logoutRequested()),
        verify: (_) {
          verifyNever(() => getCurrentUserUseCase(const NoParams()));
          verifyNever(() => refreshTokenUseCase(const NoParams()));
        },
      );
    });
  });
}
