import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/room_entity.dart';
import '../bloc/room_bloc.dart';
import '../bloc/room_event.dart';
import '../bloc/room_state.dart';
import '../widgets/room_card.dart';

/// The real Room listing landing page (`AppRoutes.home`), replacing
/// `PlaceholderHomePage` wholesale, exactly as that file's own doc
/// comment anticipated.
///
/// Reads two blocs from context, both already provided above this
/// widget by the time it builds:
/// - [RoomBloc] — scoped to this route only (see `RoomBloc`'s own doc
///   for why it is not an app-wide singleton like `AuthBloc`),
///   provided by the `/` `GoRoute` builder in `AppRouter`.
/// - [AuthBloc] — the existing app-wide session bloc, used here only to
///   decide whether the "create room" action is visible
///   (acceptance criteria: registered users only, not guests, not
///   unauthenticated visitors).
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            key: const Key('homeProfileButton'),
            icon: const Icon(Icons.person),
            onPressed: () => context.go(AppRoutes.profile),
          ),
        ],
      ),
      floatingActionButton: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          final canCreateRoom = switch (authState) {
            AuthAuthenticated(:final user) => user.role == UserRole.registered,
            AuthInitial() ||
            AuthLoading() ||
            AuthUnauthenticated() ||
            AuthOperationFailure() => false,
          };

          if (!canCreateRoom) {
            return const SizedBox.shrink();
          }

          return FloatingActionButton(
            key: const Key('homeCreateRoomButton'),
            // TODO(F-R02-T3): navigate to the room creation form once
            // it exists. The button is intentionally visible and
            // owner-gated already — only its destination is pending.
            onPressed: () {},
            child: const Icon(Icons.add),
          );
        },
      ),
      body: BlocBuilder<RoomBloc, RoomState>(
        builder: (context, state) {
          return switch (state) {
            RoomInitial() || RoomLoading() => const Center(
              child: CircularProgressIndicator(
                key: Key('homeLoadingIndicator'),
              ),
            ),
            RoomLoaded(:final rooms) when rooms.isEmpty => Center(
              child: Text(
                l10n.homeEmptyStateMessage,
                key: const Key('homeEmptyState'),
              ),
            ),
            RoomLoaded(:final rooms) => _RoomListView(rooms: rooms),
            RoomFailure() => _ErrorView(l10n: l10n),
          };
        },
      ),
    );
  }
}

class _RoomListView extends StatelessWidget {
  const _RoomListView({required this.rooms});

  final List<RoomEntity> rooms;

  /// Bounds the wait for a settled state after dispatching
  /// [RoomEvent.refreshRooms].
  ///
  /// `flutter_bloc`'s `Bloc.emit` skips re-emitting a state that
  /// compares equal to the current one (a built-in optimisation to
  /// avoid redundant rebuilds). If a refresh happens to return the
  /// exact same room list, no new stream event would ever arrive for
  /// `stream.firstWhere` to match, and `RefreshIndicator` would spin
  /// forever waiting on `onRefresh`'s returned future. This timeout
  /// bounds that wait; when it fires, `RefreshIndicator` simply
  /// dismisses — there being nothing new to show is an acceptable
  /// outcome, not an error.
  static const Duration _refreshTimeout = Duration(seconds: 10);

  @override
  Widget build(BuildContext context) {
    final roomBloc = context.read<RoomBloc>();

    return RefreshIndicator(
      onRefresh: () async {
        roomBloc.add(const RoomEvent.refreshRooms());
        await roomBloc.stream
            .firstWhere((state) => state is RoomLoaded || state is RoomFailure)
            .timeout(_refreshTimeout, onTimeout: () => roomBloc.state);
      },
      child: ListView.builder(
        key: const Key('homeRoomList'),
        itemCount: rooms.length,
        itemBuilder: (context, index) => RoomCard(room: rooms[index]),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.homeErrorMessage, key: const Key('homeErrorMessage')),
          const SizedBox(height: 8),
          ElevatedButton(
            key: const Key('homeRetryButton'),
            onPressed: () => context.read<RoomBloc>().add(
              const RoomEvent.fetchPublicRooms(),
            ),
            child: Text(l10n.homeRetryButtonLabel),
          ),
        ],
      ),
    );
  }
}
