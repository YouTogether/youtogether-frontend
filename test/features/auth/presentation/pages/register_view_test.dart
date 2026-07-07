import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/auth/presentation/cubit/register_cubit.dart';
import 'package:youtogether/features/auth/presentation/cubit/register_state.dart';
import 'package:youtogether/features/auth/presentation/pages/register_view.dart';
import 'package:youtogether/l10n/generated/app_localizations.dart';

class MockRegisterCubit extends MockCubit<RegisterState>
    implements RegisterCubit {}

void main() {
  late MockRegisterCubit registerCubit;
  late bool registrationSucceededCalled;
  late bool navigateToLoginCalled;

  setUp(() {
    registerCubit = MockRegisterCubit();
    registrationSucceededCalled = false;
    navigateToLoginCalled = false;
    when(() => registerCubit.reset()).thenReturn(null);
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<RegisterCubit>.value(
        value: registerCubit,
        child: child,
      ),
    );
  }

  Future<void> pumpRegisterView(
    WidgetTester tester, {
    required RegisterState initialState,
  }) async {
    whenListen(
      registerCubit,
      const Stream<RegisterState>.empty(),
      initialState: initialState,
    );

    await tester.pumpWidget(
      wrap(
        RegisterView(
          onRegistrationSucceeded: () => registrationSucceededCalled = true,
          onNavigateToLogin: () => navigateToLoginCalled = true,
        ),
      ),
    );
  }

  group('RegisterView — rendering', () {
    testWidgets('renders email, password, username fields and submit button', (
      tester,
    ) async {
      await pumpRegisterView(
        tester,
        initialState: const RegisterState.initial(),
      );

      expect(find.byKey(const Key('registerEmailField')), findsOneWidget);
      expect(find.byKey(const Key('registerPasswordField')), findsOneWidget);
      expect(find.byKey(const Key('registerUsernameField')), findsOneWidget);
      expect(find.byKey(const Key('registerSubmitButton')), findsOneWidget);
    });

    testWidgets('renders a functional navigation link to the login screen', (
      tester,
    ) async {
      await pumpRegisterView(
        tester,
        initialState: const RegisterState.initial(),
      );

      expect(find.byKey(const Key('registerLoginLink')), findsOneWidget);

      await tester.tap(find.byKey(const Key('registerLoginLink')));
      await tester.pump();

      expect(navigateToLoginCalled, isTrue);
    });
  });

  group('RegisterView — loading state', () {
    testWidgets('disables all fields and shows a progress indicator', (
      tester,
    ) async {
      await pumpRegisterView(
        tester,
        initialState: const RegisterState.loading(),
      );

      final emailField = tester.widget<TextFormField>(
        find.byKey(const Key('registerEmailField')),
      );
      final passwordField = tester.widget<TextFormField>(
        find.byKey(const Key('registerPasswordField')),
      );
      final usernameField = tester.widget<TextFormField>(
        find.byKey(const Key('registerUsernameField')),
      );

      expect(emailField.enabled, isFalse);
      expect(passwordField.enabled, isFalse);
      expect(usernameField.enabled, isFalse);
      expect(find.byKey(const Key('registerLoadingIndicator')), findsOneWidget);
      expect(find.byKey(const Key('registerSubmitButton')), findsNothing);
    });

    testWidgets('disables the login link while loading', (tester) async {
      await pumpRegisterView(
        tester,
        initialState: const RegisterState.loading(),
      );

      final loginLink = tester.widget<TextButton>(
        find.byKey(const Key('registerLoginLink')),
      );

      expect(loginLink.onPressed, isNull);
    });
  });

  group('RegisterView — validation failure (inline)', () {
    testWidgets(
      'shows inline errors for each invalid field without a SnackBar',
      (tester) async {
        await pumpRegisterView(
          tester,
          initialState: const RegisterState.failure(
            Failure.validation(
              errors: {
                'email': 'Please enter a valid email address.',
                'username': 'Username must not be empty.',
              },
            ),
          ),
        );
        await tester.pump();

        expect(
          find.text('Please enter a valid email address.'),
          findsOneWidget,
        );
        expect(find.text('Username must not be empty.'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
      },
    );
  });

  group('RegisterView — non-validation failure (SnackBar)', () {
    testWidgets('shows a SnackBar for a ServerFailure', (tester) async {
      final controller = StreamController<RegisterState>();
      addTearDown(controller.close);

      whenListen(
        registerCubit,
        controller.stream,
        initialState: const RegisterState.initial(),
      );

      await tester.pumpWidget(
        wrap(
          RegisterView(
            onRegistrationSucceeded: () {},
            onNavigateToLogin: () {},
          ),
        ),
      );

      controller.add(
        const RegisterState.failure(
          Failure.server(statusCode: 409, message: 'duplicate'),
        ),
      );
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('never renders the raw ServerFailure.message in the SnackBar', (
      tester,
    ) async {
      final controller = StreamController<RegisterState>();
      addTearDown(controller.close);

      whenListen(
        registerCubit,
        controller.stream,
        initialState: const RegisterState.initial(),
      );

      await tester.pumpWidget(
        wrap(
          RegisterView(
            onRegistrationSucceeded: () {},
            onNavigateToLogin: () {},
          ),
        ),
      );

      const rawBackendMessage = 'raw-backend-diagnostic-text';
      controller.add(
        const RegisterState.failure(
          Failure.server(statusCode: 500, message: rawBackendMessage),
        ),
      );
      await tester.pump();

      expect(find.text(rawBackendMessage), findsNothing);
    });

    testWidgets('shows a SnackBar for a NetworkFailure', (tester) async {
      final controller = StreamController<RegisterState>();
      addTearDown(controller.close);

      whenListen(
        registerCubit,
        controller.stream,
        initialState: const RegisterState.initial(),
      );

      await tester.pumpWidget(
        wrap(
          RegisterView(
            onRegistrationSucceeded: () {},
            onNavigateToLogin: () {},
          ),
        ),
      );

      controller.add(const RegisterState.failure(Failure.network()));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('RegisterView — success', () {
    testWidgets('invokes onRegistrationSucceeded on RegisterState.success', (
      tester,
    ) async {
      final controller = StreamController<RegisterState>();
      addTearDown(controller.close);

      whenListen(
        registerCubit,
        controller.stream,
        initialState: const RegisterState.initial(),
      );

      await tester.pumpWidget(
        wrap(
          RegisterView(
            onRegistrationSucceeded: () => registrationSucceededCalled = true,
            onNavigateToLogin: () {},
          ),
        ),
      );

      controller.add(const RegisterState.success());
      await tester.pump();

      expect(registrationSucceededCalled, isTrue);
    });
  });

  group('RegisterView — dispose', () {
    testWidgets('calls RegisterCubit.reset() when the widget is disposed', (
      tester,
    ) async {
      await pumpRegisterView(
        tester,
        initialState: const RegisterState.initial(),
      );

      // Replace the subtree so RegisterView is disposed.
      await tester.pumpWidget(const SizedBox.shrink());

      verify(() => registerCubit.reset()).called(1);
    });
  });
}
