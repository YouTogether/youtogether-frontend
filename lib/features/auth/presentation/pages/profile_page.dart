import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/user_entity.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// Profile screen, reading the current [UserEntity] directly from the
/// ancestor `AuthBloc` — no dedicated use case or cubit fetches the
/// profile separately; `AuthBloc.state` is already the application's
/// single source of truth for the authenticated user (see `AuthBloc`
/// class doc).
///
/// ## Route guard — scope boundary
/// This page as a route protected by
/// `GoRouter`'s redirect callback (unauthenticated access redirects to
/// `/`). No routing package exists anywhere in this codebase yet (see
/// the identical scope boundary already documented on `AuthBloc` for)
/// — there is nothing to guard a route *with*. As
/// defence in depth for whenever a router does exist, and to keep this
/// widget safe to test and render in isolation regardless, [build]
/// itself never assumes the state is [AuthAuthenticated]: any other
/// state renders a neutral loading placeholder instead of profile data,
/// so this page cannot be made to display or leak user information for
/// a state that is not actually authenticated.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profilePageTitle)),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          return switch (state) {
            AuthAuthenticated(:final user) => _ProfileContent(user: user),
            AuthInitial() ||
            AuthLoading() ||
            AuthUnauthenticated() ||
            AuthOperationFailure() => const Center(
              child: CircularProgressIndicator(
                key: Key('profileLoadingIndicator'),
              ),
            ),
          };
        },
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.user});

  final UserEntity user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final memberSince = DateFormat.yMMMd().format(user.createdAt);
    final roleLabel = switch (user.role) {
      UserRole.registered => l10n.profileRoleRegistered,
      UserRole.guest => l10n.profileRoleGuest,
    };

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _InitialsAvatar(displayName: user.displayName),
          const SizedBox(height: 16),
          Text(
            user.displayName,
            key: const Key('profileDisplayName'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(user.email, key: const Key('profileEmail')),
          const SizedBox(height: 12),
          Chip(label: Text(roleLabel, key: const Key('profileRoleBadgeLabel'))),
          const SizedBox(height: 12),
          Text(
            l10n.profileMemberSince(memberSince),
            key: const Key('profileMemberSince'),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            key: const Key('profileLogoutButton'),
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthEvent.logoutRequested()),
            child: Text(l10n.profileLogoutButton),
          ),
        ],
      ),
    );
  }
}

/// Circular avatar showing the user's initials.
///
/// [UserEntity] carries no avatar image field at all (see its
/// class-level doc — the evolution introducing `avatarUrl` was not
/// carried through to the current implementation), so this is not a
/// "fallback used only when a picture fails to load": it is currently
/// the *only* rendering this widget can ever produce.
class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.displayName});

  final String displayName;

  String get _initials {
    final words = displayName.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) {
      return '?';
    }
    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCase();
    }
    return (words.first.substring(0, 1) + words.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      key: const Key('profileAvatar'),
      radius: 40,
      child: Text(_initials, key: const Key('profileAvatarInitials')),
    );
  }
}
