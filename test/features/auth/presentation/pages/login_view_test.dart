import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/auth/presentation/cubit/login_cubit.dart';
import 'package:youtogether/features/auth/presentation/cubit/login_state.dart';
import 'package:youtogether/features/auth/presentation/pages/login_view.dart';
import 'package:youtogether/l10n/generated/app_localizations.dart';

class MockLoginCubit extends MockCubit<LoginState> implements LoginCubit {}

void main() {
  late MockLoginCubit loginCubit;
  late bool loginSucceededCalled;
  late bool navigateToRegisterCalled;

  setUp(() {
    loginCubit = MockLoginCubit();
    loginSucceededCalled = false;
    navigateToRegisterCalled = false;
    when(() => loginCubit.reset()).thenReturn(null);
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<LoginCubit>.value(value: loginCubit, child: child),
    );
  }

  Future<void> pumpLoginView(
    WidgetTester tester, {
    required LoginState initialState,
  }) async {
    whenListen(
      loginCubit,
      const Stream<LoginState>.empty(),
      initialState: initialState,
    );

    await tester.pumpWidget(
      wrap(
        LoginView(
          onLoginSucceeded: () => loginSucceededCalled = true,
          onNavigateToRegister: () => navigateToRegisterCalled = true,
        ),
      ),
    );
  }

  group('LoginView — rendering', () {
    testWidgets('renders email, password fields and submit button', (
      tester,
    ) async {
      await pumpLoginView(tester, initialState: const LoginState.initial());

      expect(find.byKey(const Key('loginEmailField')), findsOneWidget);
      expect(find.byKey(const Key('loginPasswordField')), findsOneWidget);
      expect(find.byKey(const Key('loginSubmitButton')), findsOneWidget);
    });

    testWidgets(
      'renders a functional navigation link to the registration screen',
      (tester) async {
        await pumpLoginView(tester, initialState: const LoginState.initial());

        expect(find.byKey(const Key('loginRegisterLink')), findsOneWidget);

        await tester.tap(find.byKey(const Key('loginRegisterLink')));
        await tester.pump();

        expect(navigateToRegisterCalled, isTrue);
      },
    );
  });

  group('LoginView — loading state', () {
    testWidgets('disables all fields and shows a progress indicator', (
      tester,
    ) async {
      await pumpLoginView(tester, initialState: const LoginState.loading());

      final emailField = tester.widget<TextFormField>(
        find.byKey(const Key('loginEmailField')),
      );
      final passwordField = tester.widget<TextFormField>(
        find.byKey(const Key('loginPasswordField')),
      );

      expect(emailField.enabled, isFalse);
      expect(passwordField.enabled, isFalse);
      expect(find.byKey(const Key('loginLoadingIndicator')), findsOneWidget);
      expect(find.byKey(const Key('loginSubmitButton')), findsNothing);
    });

    testWidgets('disables the register link while loading', (tester) async {
      await pumpLoginView(tester, initialState: const LoginState.loading());

      final registerLink = tester.widget<TextButton>(
        find.byKey(const Key('loginRegisterLink')),
      );

      expect(registerLink.onPressed, isNull);
    });
  });

  group('LoginView — failure (SnackBar)', () {
    testWidgets('shows a SnackBar for an AuthFailure (invalid credentials)', (
      tester,
    ) async {
      final controller = StreamController<LoginState>();
      addTearDown(controller.close);

      whenListen(
        loginCubit,
        controller.stream,
        initialState: const LoginState.initial(),
      );

      await tester.pumpWidget(
        wrap(LoginView(onLoginSucceeded: () {}, onNavigateToRegister: () {})),
      );

      controller.add(
        const LoginState.failure(
          Failure.auth(message: 'Invalid email or password.'),
        ),
      );
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('shows a SnackBar for a ValidationFailure', (tester) async {
      final controller = StreamController<LoginState>();
      addTearDown(controller.close);

      whenListen(
        loginCubit,
        controller.stream,
        initialState: const LoginState.initial(),
      );

      await tester.pumpWidget(
        wrap(LoginView(onLoginSucceeded: () {}, onNavigateToRegister: () {})),
      );

      controller.add(
        const LoginState.failure(
          Failure.validation(
            errors: {'password': 'Password must not be empty.'},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Password must not be empty.'), findsOneWidget);
    });

    testWidgets('never renders the raw ServerFailure.message in the SnackBar', (
      tester,
    ) async {
      final controller = StreamController<LoginState>();
      addTearDown(controller.close);

      whenListen(
        loginCubit,
        controller.stream,
        initialState: const LoginState.initial(),
      );

      await tester.pumpWidget(
        wrap(LoginView(onLoginSucceeded: () {}, onNavigateToRegister: () {})),
      );

      const rawBackendMessage = 'raw-backend-diagnostic-text';
      controller.add(
        const LoginState.failure(
          Failure.server(statusCode: 500, message: rawBackendMessage),
        ),
      );
      await tester.pump();

      expect(find.text(rawBackendMessage), findsNothing);
    });
  });

  group('LoginView — success', () {
    testWidgets('invokes onLoginSucceeded on LoginState.success', (
      tester,
    ) async {
      final controller = StreamController<LoginState>();
      addTearDown(controller.close);

      whenListen(
        loginCubit,
        controller.stream,
        initialState: const LoginState.initial(),
      );

      await tester.pumpWidget(
        wrap(
          LoginView(
            onLoginSucceeded: () => loginSucceededCalled = true,
            onNavigateToRegister: () {},
          ),
        ),
      );

      controller.add(const LoginState.success());
      await tester.pump();

      expect(loginSucceededCalled, isTrue);
    });
  });

  group('LoginView — dispose', () {
    testWidgets('calls LoginCubit.reset() when the widget is disposed', (
      tester,
    ) async {
      await pumpLoginView(tester, initialState: const LoginState.initial());

      await tester.pumpWidget(const SizedBox.shrink());

      verify(() => loginCubit.reset()).called(1);
    });
  });
}
