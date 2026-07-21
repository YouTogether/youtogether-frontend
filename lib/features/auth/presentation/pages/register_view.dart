import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../cubit/register_cubit.dart';
import '../cubit/register_state.dart';

/// Registration form, driven entirely by the [RegisterCubit] provided by
/// an ancestor `BlocProvider` (normally `RegisterPage`).
///
/// Split from `RegisterPage` specifically so widget tests can supply an
/// already-built cubit via `BlocProvider.value` — real or a `bloc_test`
/// `MockCubit` — without needing `RegisterPage`'s own dependency wiring
/// to exist.
///
/// UI behaviour, per this ticket's Definition of Done:
/// - Three text fields (email, password, username) plus a submit button
///   and a link to the login screen.
/// - [RegisterState.loading]: every control is disabled and the submit
///   button is replaced by a [CircularProgressIndicator].
/// - [RegisterState.failure] with a [ValidationFailure]: each field shows
///   its own error inline via `InputDecoration.errorText`, keyed by field
///   name in [ValidationFailure.errors] — no `SnackBar` is shown for this
///   case.
/// - [RegisterState.failure] with any other [Failure] subtype: a
///   `SnackBar` shows a localised, generic message. Per the
///   internationalisation convention documented on `Failure`
///   (`core/error/failures.dart`), the raw `.message` field is never
///   rendered — [_failureMessage] switches exhaustively over every
///   subtype and selects the corresponding [AppLocalizations] string.
/// - [RegisterState.success]: [onRegistrationSucceeded] is invoked. See
///   `RegisterPage` for why this is a callback rather than a direct
///   `AuthBloc` dispatch.
class RegisterView extends StatefulWidget {
  const RegisterView({
    required this.onRegistrationSucceeded,
    required this.onNavigateToLogin,
    super.key,
  });

  final VoidCallback onRegistrationSucceeded;
  final VoidCallback onNavigateToLogin;

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  /// Cached reference to the ancestor [RegisterCubit], captured in
  /// [didChangeDependencies] rather than looked up directly in [dispose].
  ///
  /// Calling `context.read<RegisterCubit>()` inside `dispose()` is
  /// unsafe: when an entire subtree — including the `BlocProvider`
  /// ancestor — is unmounted in the same frame (as happens whenever a
  /// parent widget is replaced wholesale, which is exactly what
  /// `RegisterView — dispose` in `register_view_test.dart` exercises),
  /// the element tree may no longer support an ancestor lookup by the
  /// time this widget's own `dispose()` runs. Flutter's own framework
  /// assertion for this exact failure recommends the fix applied here:
  /// save the reference while the widget is still active
  /// (`didChangeDependencies`, which runs before `dispose` and whenever
  /// an inherited dependency such as `BlocProvider` changes), then use
  /// the cached reference — never `context` — at teardown time.
  RegisterCubit? _registerCubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registerCubit = context.read<RegisterCubit>();
  }

  @override
  void dispose() {
    // See RegisterCubit.reset doc comment : returns the cubit to its initial state before this widget
    // is torn down. Uses the cached reference above, not `context` —
    // see its doc comment for why.
    _registerCubit?.reset();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<RegisterCubit>().register(
      email: _emailController.text,
      password: _passwordController.text,
      username: _usernameController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profilePageTitle),
        leading: IconButton(
          key: const Key('profileBackToHomeButton'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
      ),
      body: BlocListener<RegisterCubit, RegisterState>(
        listener: (context, state) => switch (state) {
          RegisterSuccess() => widget.onRegistrationSucceeded(),
          RegisterFailure(:final failure) when failure is! ValidationFailure =>
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_failureMessage(l10n, failure))),
            ),
          RegisterInitial() || RegisterLoading() || RegisterFailure() => null,
        },
        child: BlocBuilder<RegisterCubit, RegisterState>(
          builder: (context, state) {
            final isLoading = state is RegisterLoading;
            final fieldErrors =
                state is RegisterFailure && state.failure is ValidationFailure
                ? (state.failure as ValidationFailure).errors
                : const <String, String>{};

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('registerEmailField'),
                    controller: _emailController,
                    enabled: !isLoading,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.registerEmailLabel,
                      errorText: fieldErrors['email'],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('registerPasswordField'),
                    controller: _passwordController,
                    enabled: !isLoading,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l10n.registerPasswordLabel,
                      errorText: fieldErrors['password'],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('registerUsernameField'),
                    controller: _usernameController,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      labelText: l10n.registerUsernameLabel,
                      errorText: fieldErrors['username'],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isLoading)
                    const Center(
                      child: CircularProgressIndicator(
                        key: Key('registerLoadingIndicator'),
                      ),
                    )
                  else
                    ElevatedButton(
                      key: const Key('registerSubmitButton'),
                      onPressed: _submit,
                      child: Text(l10n.registerSubmitButton),
                    ),
                  const SizedBox(height: 16),
                  TextButton(
                    key: const Key('registerLoginLink'),
                    onPressed: isLoading ? null : widget.onNavigateToLogin,
                    child: Text(l10n.registerLoginLinkLabel),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Maps a non-[ValidationFailure] to a localised, user-safe message.
  ///
  /// Every subtype is handled explicitly (Dart's exhaustiveness checking
  /// on the sealed [Failure] class enforces this at compile time), even
  /// the ones `RegisterUseCase` is not expected to produce in practice
  /// ([AuthFailure], [NotFoundFailure], [FirebaseFailure]) — defensive
  /// UI code should never crash on an unreachable-in-practice case.
  String _failureMessage(AppLocalizations l10n, Failure failure) {
    return switch (failure) {
      ServerFailure() => l10n.registerErrorServer,
      NetworkFailure() => l10n.registerErrorNetwork,
      CacheFailure() => l10n.registerErrorCache,
      AuthFailure() ||
      NotFoundFailure() ||
      FirebaseFailure() => l10n.registerErrorGeneric,
      ValidationFailure() => l10n.registerErrorGeneric,
    };
  }
}
