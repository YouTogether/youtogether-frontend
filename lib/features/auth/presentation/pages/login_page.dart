import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/login_usecase.dart';
import '../cubit/login_cubit.dart';
import 'login_view.dart';

/// Route-level widget for the login screen.
///
/// Mirrors `RegisterPage` in structure and rationale: creates
/// the [LoginCubit] backing this screen from the constructor-injected
/// [LoginUseCase], leaving dependency-graph wiring (`get_it` /
/// `injectable`) to whichever ticket sets up application-wide routing.
///
/// The actual form UI lives in [LoginView], kept separate so widget
/// tests can exercise it directly against an already-built (real or
/// `bloc_test`-mocked) [LoginCubit].
///
/// [onLoginSucceeded] and [onNavigateToRegister] are callbacks for the
/// same reason `RegisterPage` uses callbacks instead of a direct
/// dependency on `AuthBloc` / `LoginPage`: `AuthBloc`
/// (dispatched via `AuthEvent.checkStatusRequested()`
/// on success) does not exist yet. The concrete
/// navigation and `AuthBloc` dispatch are supplied by whichever ticket
/// wires the application's route table.
class LoginPage extends StatelessWidget {
  const LoginPage({
    required this.loginUseCase,
    required this.onLoginSucceeded,
    required this.onNavigateToRegister,
    super.key,
  });

  final LoginUseCase loginUseCase;
  final VoidCallback onLoginSucceeded;
  final VoidCallback onNavigateToRegister;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginCubit(loginUseCase),
      child: LoginView(
        onLoginSucceeded: onLoginSucceeded,
        onNavigateToRegister: onNavigateToRegister,
      ),
    );
  }
}
