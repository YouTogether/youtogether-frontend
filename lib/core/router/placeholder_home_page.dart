import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_event.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../l10n/generated/app_localizations.dart';

/// Provisional authenticated landing page, built solely so `AppRouter`'s
/// `/` route has *something* to render while F-INF-T1 wires the guard
/// and redirect logic end-to-end.
///
/// **This is not the Room listing page.** `F-R01-T3` (Sprint 2 planning
/// §5) builds the real `HomePage` — a `RoomBloc`-driven listing of
/// public rooms with a "create room" action. That ticket should
/// **replace this file wholesale**, not extend it: nothing here is
/// meant to survive past that point. Building the real listing here
/// would be exactly the kind of scope creep `ADR-001` and this
/// project's task-boundary discipline explicitly avoid — F-INF-T1's
/// job is the shell and the guard, not Room's presentation layer.
///
/// Deliberately minimal: a welcome message using the authenticated
/// user's display name, and a logout button dispatching
/// `AuthEvent.logoutRequested()` — enough to prove the full
/// authenticated round-trip (login -> guard admits -> logout -> guard
/// redirects back to `/login`) works, and nothing more.
class PlaceholderHomePage extends StatelessWidget {
  const PlaceholderHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final displayName = switch (state) {
            AuthAuthenticated(:final user) => user.displayName,
            _ => null,
          };

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (displayName != null)
                  Text(
                    l10n.homeWelcomeMessage(displayName),
                    key: const Key('placeholderHomeWelcome'),
                  ),
                const SizedBox(height: 16),
                TextButton(
                  key: const Key('placeholderHomeLogoutButton'),
                  onPressed: () => context.read<AuthBloc>().add(
                    const AuthEvent.logoutRequested(),
                  ),
                  child: Text(l10n.logoutButtonLabel),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
