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
import '../cubit/join_room_cubit.dart';
import '../cubit/join_room_state.dart';
import '../widgets/room_card.dart';

/// The real Room listing landing page (`AppRoutes.home`), replacing
/// `PlaceholderHomePage` wholesale, exactly as that file's own doc
/// comment anticipated.
///
/// Reads three blocs from context, all already provided above this
/// widget by the time it builds (`AppRouter`'s `/` `GoRoute` builder):
/// - [RoomBloc] — scoped to this route only (see `RoomBloc`'s own doc
///   for why it is not an app-wide singleton like `AuthBloc`).
/// - [AuthBloc] — the existing app-wide session bloc, used here to
///   decide whether the "create room" action is visible (registered
///   users only) and whether each `RoomCard`'s join button is visible
///   (any authenticated user — see [_RoomListItem]'s own doc for why
///   this differs from the create-room restriction).
/// - [JoinRoomCubit] — shared across every `RoomCard` in the listing;
///   a `BlocListener` here navigates to the room detail
///   view on success and shows a `SnackBar` on failure.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocListener<JoinRoomCubit, JoinRoomState>(
      listener: (context, joinState) {
        if (joinState is JoinRoomSuccess) {
          context.go(AppRoutes.roomDetail(joinState.room.id));
        } else if (joinState is JoinRoomFailure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.homeJoinErrorMessage)));
        }
      },
      child: Scaffold(
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
              AuthAuthenticated(:final user) =>
                user.role == UserRole.registered,
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
              onPressed: () => context.go(AppRoutes.createRoom),
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
        // RefreshIndicator only responds to an overscroll gesture at
        // the top of the scrollable. With default physics, a list
        // whose content is shorter than the viewport (as in tests with
        // few rooms, or simply a nearly-empty listing in production)
        // has nothing to overscroll, so pull-to-refresh would silently
        // do nothing. AlwaysScrollableScrollPhysics keeps the gesture
        // working regardless of content length.
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: rooms.length,
        itemBuilder: (context, index) => _RoomListItem(room: rooms[index]),
      ),
    );
  }
}

/// Wraps a single [RoomCard], resolving its join-button visibility and
/// per-item loading state from ambient blocs.
///
/// Split into its own widget (rather than computed inline in
/// [_RoomListView.build]) so each card only rebuilds for the slice of
/// [AuthBloc]/[JoinRoomCubit] state relevant to *it* — `BlocBuilder`
/// scopes rebuilds per subtree, not per list item, when nested this way.
class _RoomListItem extends StatelessWidget {
  const _RoomListItem({required this.room});

  final RoomEntity room;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        // Unlike the create-room button (registered users only), the
        // backend places no role-based restriction on joining — only
        // `JwtAuthGuard` (see `RoomController.join`'s own doc) — so a
        // guest-role authenticated user can join exactly like a
        // registered one. Only a genuinely unauthenticated visitor
        // sees no join button.
        final isAuthenticated = authState is AuthAuthenticated;

        return BlocBuilder<JoinRoomCubit, JoinRoomState>(
          builder: (context, joinState) {
            final isJoiningThisRoom =
                joinState is JoinRoomLoading && joinState.roomId == room.id;

            return RoomCard(
              room: room,
              onTap: () => context.go(AppRoutes.roomDetail(room.id)),
              onJoin: isAuthenticated
                  ? () => context.read<JoinRoomCubit>().joinRoom(room.id)
                  : null,
              isJoining: isJoiningThisRoom,
            );
          },
        );
      },
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
