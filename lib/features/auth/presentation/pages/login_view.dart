import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../cubit/login_cubit.dart';
import '../cubit/login_state.dart';

/// Login form, driven entirely by the [LoginCubit] provided by an
/// ancestor `BlocProvider` (normally `LoginPage`).
///
/// Split from `LoginPage` for the same testability reason `RegisterView`
/// is split from `RegisterPage`.
///
/// UI behaviour, per this ticket's Definition of Done:
/// - Two text fields (email, password) plus a submit button and a link
///   to the registration screen.
/// - [LoginState.loading]: every control is disabled and the submit
///   button is replaced by a [CircularProgressIndicator].
/// - [LoginState.failure] (any [Failure] subtype, including
///   [ValidationFailure]): a `SnackBar` shows a message. Unlike
///   `RegisterView`, this form does not display validation errors
///   inline — the two-field login form is simple enough that a single
///   `SnackBar` per failure covers both client-side validation and
///   server-side rejection without meaningfully hurting usability, and
///   this is what the task's Definition of Done specifies (only
///   "SnackBar" is mentioned for login failures, unlike the explicit
///   inline/SnackBar split specified for registration).
/// - [LoginState.success]: [onLoginSucceeded] is invoked. See
///   `LoginPage` for why this is a callback rather than a direct
///   `AuthBloc` dispatch.
class LoginView extends StatefulWidget {
  const LoginView({
    required this.onLoginSucceeded,
    required this.onNavigateToRegister,
    super.key,
  });

  final VoidCallback onLoginSucceeded;
  final VoidCallback onNavigateToRegister;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Cached reference to the ancestor [LoginCubit], captured in
  /// [didChangeDependencies] rather than looked up directly in [dispose].
  ///
  /// See `RegisterView`'s identical field for the full
  /// rationale: calling `context.read<LoginCubit>()` inside `dispose()`
  /// is unsafe once the ancestor `BlocProvider` may already be
  /// unmounting in the same frame.
  LoginCubit? _loginCubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loginCubit = context.read<LoginCubit>();
  }

  @override
  void dispose() {
    _loginCubit?.reset();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<LoginCubit>().login(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.loginPageTitle),
        leading: IconButton(
          key: const Key('loginBackToHomeButton'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
      ),
      body: BlocListener<LoginCubit, LoginState>(
        listener: (context, state) => switch (state) {
          LoginSuccess() => widget.onLoginSucceeded(),
          LoginFailure(:final failure) =>
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_failureMessage(l10n, failure))),
            ),
          LoginInitial() || LoginLoading() => null,
        },
        child: BlocBuilder<LoginCubit, LoginState>(
          builder: (context, state) {
            final isLoading = state is LoginLoading;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('loginEmailField'),
                    controller: _emailController,
                    enabled: !isLoading,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.loginEmailLabel,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('loginPasswordField'),
                    controller: _passwordController,
                    enabled: !isLoading,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l10n.loginPasswordLabel,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isLoading)
                    const Center(
                      child: CircularProgressIndicator(
                        key: Key('loginLoadingIndicator'),
                      ),
                    )
                  else
                    ElevatedButton(
                      key: const Key('loginSubmitButton'),
                      onPressed: _submit,
                      child: Text(l10n.loginSubmitButton),
                    ),
                  const SizedBox(height: 16),
                  TextButton(
                    key: const Key('loginRegisterLink'),
                    onPressed: isLoading ? null : widget.onNavigateToRegister,
                    child: Text(l10n.loginRegisterLinkLabel),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Maps any [Failure] to a message shown in the `SnackBar`.
  ///
  /// [ValidationFailure] is a deliberate exception to the "always
  /// localise, never render raw text" rule applied to the other
  /// subtypes: its `errors` values are already user-facing text authored
  /// by [LoginCubit] itself (not diagnostic `.message` text from the
  /// server or platform — see the internationalisation convention on
  /// `Failure`), so they are joined and shown directly.
  String _failureMessage(AppLocalizations l10n, Failure failure) {
    return switch (failure) {
      AuthFailure() => l10n.loginErrorAuth,
      ServerFailure() => l10n.loginErrorServer,
      NetworkFailure() => l10n.loginErrorNetwork,
      CacheFailure() => l10n.loginErrorCache,
      NotFoundFailure() || FirebaseFailure() => l10n.loginErrorGeneric,
      ValidationFailure(:final errors) => errors.values.join('\n'),
    };
  }
}
