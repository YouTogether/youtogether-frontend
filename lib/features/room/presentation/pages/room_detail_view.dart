import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../cubit/room_detail_cubit.dart';
import '../cubit/room_detail_state.dart';

/// Room detail screen content, driven by the [RoomDetailCubit] and
/// [AuthBloc] provided by ancestor `BlocProvider`s (normally
/// `RoomDetailPage`).
///
/// Split from `RoomDetailPage` for the same testability reason
/// `RegisterView`/`CreateRoomView` are split from their pages.
///
/// [roomId] is threaded through solely so the retry button can call
/// [RoomDetailCubit.fetchRoom] again after a failure — this view has no
/// other use for it, since the room itself (once loaded) carries its
/// own id.
///
/// Renders name, description, member count, and an owner badge shown
/// only when the current [AuthState] is [AuthAuthenticated] with a
/// [UserEntity.id] matching the room's `ownerId` — per this page's
/// Definition of Done ("owner-status relative to the current user").
/// An unauthenticated or non-owner viewer sees no badge at all, not a
/// "not the owner" negative indicator — there being no badge already
/// communicates that clearly enough, and a page with no owner-only
/// actions has no reason to state a negative.
class RoomDetailView extends StatelessWidget {
  const RoomDetailView({required this.roomId, super.key});

  final String roomId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocBuilder<RoomDetailCubit, RoomDetailState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              key: const Key('roomDetailBackButton'),
              icon: const Icon(Icons.arrow_back),
              tooltip: l10n.roomDetailBackButtonTooltip,
              onPressed: () => context.go(AppRoutes.home),
            ),
            title: Text(
              state is RoomDetailLoaded ? state.room.name : l10n.appTitle,
            ),
          ),
          body: switch (state) {
            RoomDetailInitial() || RoomDetailLoading() => const Center(
              child: CircularProgressIndicator(
                key: Key('roomDetailLoadingIndicator'),
              ),
            ),
            RoomDetailLoaded(:final room) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, authState) {
                      final isOwner = switch (authState) {
                        AuthAuthenticated(:final user) =>
                          user.id == room.ownerId,
                        AuthInitial() ||
                        AuthLoading() ||
                        AuthUnauthenticated() ||
                        AuthOperationFailure() => false,
                      };

                      if (!isOwner) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Chip(
                          key: const Key('roomDetailOwnerBadge'),
                          label: Text(l10n.roomDetailOwnerBadgeLabel),
                        ),
                      );
                    },
                  ),
                  if (room.description != null)
                    Text(
                      room.description!,
                      key: const Key('roomDetailDescription'),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.homeRoomCardMemberCount(room.memberCount),
                    key: const Key('roomDetailMemberCount'),
                  ),
                ],
              ),
            ),
            RoomDetailFailure() => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.roomDetailErrorMessage,
                    key: const Key('roomDetailErrorMessage'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const Key('roomDetailRetryButton'),
                    onPressed: () =>
                        context.read<RoomDetailCubit>().fetchRoom(roomId),
                    child: Text(l10n.roomDetailRetryButtonLabel),
                  ),
                ],
              ),
            ),
          },
        );
      },
    );
  }
}
