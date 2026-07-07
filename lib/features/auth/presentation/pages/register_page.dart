import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/register_usecase.dart';
import '../cubit/register_cubit.dart';
import 'register_view.dart';

/// Route-level widget for the registration screen.
///
/// Creates the [RegisterCubit] backing this screen from the
/// constructor-injected [RegisterUseCase]. Wiring the concrete dependency
/// graph (`get_it` / `injectable`) is the
/// concern of whichever ticket sets up application-wide routing and
/// dependency injection — out of scope here, and not yet built.
///
/// The actual form UI lives in [RegisterView], kept as a separate widget
/// so that widget tests can exercise it directly against an
/// already-built [RegisterCubit] (real or mocked via `bloc_test`'s
/// `MockCubit`), without going through this page's own dependency
/// wiring.
///
/// [onRegistrationSucceeded] and [onNavigateToLogin] are exposed as
/// callbacks rather than hardcoded navigation, because two pieces of
/// infrastructure this page's Definition of Done references do not yet
/// exist in the codebase:
/// - `AuthBloc`, which the full
///   application dispatches `AuthEvent.checkStatusRequested()` on after
///   a successful registration — built by F-A03-T3.
/// - `LoginPage`, the target of the "navigation link to LoginPage"
///   requirement — built by F-A02-T3.
///
/// Exposing callbacks instead of a direct dependency on either keeps
/// this widget compilable and testable today; whichever ticket wires
/// the application's route table supplies the real callbacks
/// (dispatching to `AuthBloc`, pushing `LoginPage`) once those types
/// exist.
class RegisterPage extends StatelessWidget {
  const RegisterPage({
    required this.registerUseCase,
    required this.onRegistrationSucceeded,
    required this.onNavigateToLogin,
    super.key,
  });

  final RegisterUseCase registerUseCase;
  final VoidCallback onRegistrationSucceeded;
  final VoidCallback onNavigateToLogin;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RegisterCubit(registerUseCase),
      child: RegisterView(
        onRegistrationSucceeded: onRegistrationSucceeded,
        onNavigateToLogin: onNavigateToLogin,
      ),
    );
  }
}
