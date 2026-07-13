import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/auth/domain/entities/user_entity.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_event.dart';
import 'package:youtogether/features/auth/presentation/bloc/auth_state.dart';
import 'package:youtogether/features/auth/presentation/pages/profile_page.dart';
import 'package:youtogether/l10n/generated/app_localizations.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  late MockAuthBloc authBloc;

  setUpAll(() {
    registerFallbackValue(const AuthEvent.logoutRequested());
  });

  setUp(() {
    authBloc = MockAuthBloc();
  });

  Future<void> pumpProfilePage(
    WidgetTester tester, {
    required AuthState state,
  }) async {
    whenListen(authBloc, const Stream<AuthState>.empty(), initialState: state);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const ProfilePage(),
        ),
      ),
    );
  }

  final registeredUser = UserEntity(
    id: '550e8400-e29b-41d4-a716-446655440000',
    email: 'test@example.com',
    displayName: 'Jane Doe',
    role: UserRole.registered,
    createdAt: DateTime.utc(2025, 1, 15),
  );

  group('ProfilePage — rendering (authenticated)', () {
    testWidgets('renders the display name, email, and member-since date', (
      tester,
    ) async {
      await pumpProfilePage(
        tester,
        state: AuthState.authenticated(registeredUser),
      );

      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);

      final expectedDate = DateFormat.yMMMd().format(registeredUser.createdAt);
      expect(find.textContaining(expectedDate), findsOneWidget);
    });

    testWidgets('renders the registered role badge', (tester) async {
      await pumpProfilePage(
        tester,
        state: AuthState.authenticated(registeredUser),
      );

      expect(find.text('Registered'), findsOneWidget);
    });

    testWidgets('renders the guest role badge for a guest user', (
      tester,
    ) async {
      final guestUser = registeredUser.copyWith(role: UserRole.guest);
      await pumpProfilePage(tester, state: AuthState.authenticated(guestUser));

      expect(find.text('Guest'), findsOneWidget);
    });

    testWidgets('renders the logout button', (tester) async {
      await pumpProfilePage(
        tester,
        state: AuthState.authenticated(registeredUser),
      );

      expect(find.byKey(const Key('profileLogoutButton')), findsOneWidget);
    });
  });

  group('ProfilePage — initials avatar', () {
    testWidgets('renders both initials for a two-word display name', (
      tester,
    ) async {
      await pumpProfilePage(
        tester,
        state: AuthState.authenticated(registeredUser),
      );

      expect(find.text('JD'), findsOneWidget);
    });

    testWidgets('renders a single initial for a one-word display name', (
      tester,
    ) async {
      final singleNameUser = registeredUser.copyWith(displayName: 'Madonna');
      await pumpProfilePage(
        tester,
        state: AuthState.authenticated(singleNameUser),
      );

      expect(find.text('M'), findsOneWidget);
    });

    testWidgets(
      'always renders the avatar as initials (no image field exists on '
      'UserEntity)',
      (tester) async {
        await pumpProfilePage(
          tester,
          state: AuthState.authenticated(registeredUser),
        );

        expect(find.byKey(const Key('profileAvatar')), findsOneWidget);
        expect(find.byKey(const Key('profileAvatarInitials')), findsOneWidget);
      },
    );
  });

  group('ProfilePage — logout interaction', () {
    testWidgets('dispatches AuthEvent.logoutRequested() when tapped', (
      tester,
    ) async {
      await pumpProfilePage(
        tester,
        state: AuthState.authenticated(registeredUser),
      );

      await tester.tap(find.byKey(const Key('profileLogoutButton')));
      await tester.pump();

      verify(() => authBloc.add(const AuthEvent.logoutRequested())).called(1);
    });
  });

  group('ProfilePage — defensive rendering for non-authenticated states '
      '(no router exists yet to guard this route — see class doc)', () {
    testWidgets('renders a neutral placeholder for AuthState.initial, never '
        'user data', (tester) async {
      await pumpProfilePage(tester, state: const AuthState.initial());

      expect(find.byKey(const Key('profileLoadingIndicator')), findsOneWidget);
      expect(find.byKey(const Key('profileDisplayName')), findsNothing);
    });

    testWidgets('renders a neutral placeholder for AuthState.loading', (
      tester,
    ) async {
      await pumpProfilePage(tester, state: const AuthState.loading());

      expect(find.byKey(const Key('profileLoadingIndicator')), findsOneWidget);
    });

    testWidgets('renders a neutral placeholder for AuthState.unauthenticated, '
        'never any previously-known user data', (tester) async {
      await pumpProfilePage(tester, state: const AuthState.unauthenticated());

      expect(find.byKey(const Key('profileLoadingIndicator')), findsOneWidget);
      expect(find.byKey(const Key('profileDisplayName')), findsNothing);
      expect(find.byKey(const Key('profileEmail')), findsNothing);
    });

    testWidgets('renders a neutral placeholder for AuthState.failure', (
      tester,
    ) async {
      await pumpProfilePage(
        tester,
        state: const AuthState.failure(Failure.cache(message: 'irrelevant')),
      );

      expect(find.byKey(const Key('profileLoadingIndicator')), findsOneWidget);
    });
  });
}
