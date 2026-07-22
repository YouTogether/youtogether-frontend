import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../cubit/delete_room_cubit.dart';
import '../cubit/delete_room_state.dart';
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
/// ## Back navigation
/// This page is reached via `context.go(...)` everywhere it's linked
/// from (`HomePage`'s `RoomCard` tap, `CreateRoomPage.onRoomCreated`) —
/// `go()` replaces the current location rather than pushing onto a
/// navigation stack, so no automatic back arrow or system-back
/// behaviour is available here for free, unlike a page reached via
/// `Navigator.push`. The [AppBar]'s `leading` button is therefore an
/// explicit `context.go(AppRoutes.home)` call, present identically in
/// every [RoomDetailState] (loading, loaded, failure) — a user must
/// always be able to get back to the room listing, including while a
/// fetch is still in flight or has failed.
///
/// Renders name (as the AppBar title once loaded), description, member
/// count, and an owner badge shown only when the current [AuthState] is
/// [AuthAuthenticated] with a [UserEntity.id] matching the room's
/// `ownerId` — per this page's Definition of Done ("owner-status
/// relative to the current user"). An unauthenticated or non-owner
/// viewer sees no badge at all, not a "not the owner" negative
/// indicator — there being no badge already communicates that clearly
/// enough, and a page with no owner-only actions has no reason to
/// state a negative.
///
/// ## Deletion
/// The owner-only delete button opens a confirmation `AlertDialog`
/// (`_confirmDeletion`) before ever calling
/// [DeleteRoomCubit.deleteRoom] — deliberate friction against an
/// irreversible-from-the-user's-perspective action, per this ticket's
/// Definition of Done. A [BlocListener] wrapping the whole page reacts
/// to [DeleteRoomState.success] by navigating home
/// (`context.go(AppRoutes.home)`), which — exactly like
/// `EditRoomPage`'s navigation back to this same page — constructs a
/// fresh `RoomBloc` and re-fetches, satisfying "refresh the room list"
/// without extra plumbing.
class RoomDetailView extends StatelessWidget {
  const RoomDetailView({required this.roomId, super.key});

  final String roomId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocListener<DeleteRoomCubit, DeleteRoomState>(
      listener: (context, deleteState) {
        if (deleteState is DeleteRoomSuccess) {
          context.go(AppRoutes.home);
        } else if (deleteState is DeleteRoomFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.roomDetailDeleteErrorMessage)),
          );
        }
      },
      child: BlocBuilder<RoomDetailCubit, RoomDetailState>(
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
              actions: [
                if (state is RoomDetailLoaded)
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, authState) {
                      final isOwner = switch (authState) {
                        AuthAuthenticated(:final user) =>
                          user.id == state.room.ownerId,
                        AuthInitial() ||
                        AuthLoading() ||
                        AuthUnauthenticated() ||
                        AuthOperationFailure() => false,
                      };

                      if (!isOwner) {
                        return const SizedBox.shrink();
                      }

                      return IconButton(
                        key: const Key('roomDetailEditButton'),
                        icon: const Icon(Icons.edit),
                        tooltip: l10n.roomDetailEditButtonTooltip,
                        onPressed: () => context.go(
                          AppRoutes.editRoom(state.room.id),
                          extra: state.room,
                        ),
                      );
                    },
                  ),
                if (state is RoomDetailLoaded)
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, authState) {
                      final isOwner = switch (authState) {
                        AuthAuthenticated(:final user) =>
                          user.id == state.room.ownerId,
                        AuthInitial() ||
                        AuthLoading() ||
                        AuthUnauthenticated() ||
                        AuthOperationFailure() => false,
                      };

                      if (!isOwner) {
                        return const SizedBox.shrink();
                      }

                      return IconButton(
                        key: const Key('roomDetailDeleteButton'),
                        icon: const Icon(Icons.delete),
                        tooltip: l10n.roomDetailDeleteButtonTooltip,
                        onPressed: () =>
                            _confirmDeletion(context, l10n, state.room.id),
                      );
                    },
                  ),
              ],
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
      ),
    );
  }

  /// Shows the deletion confirmation `AlertDialog`. Only calls
  /// [DeleteRoomCubit.deleteRoom] if the owner explicitly confirms —
  /// dismissing the dialog (tapping outside, system back, or Cancel)
  /// all resolve to `null`/`false` and take no action.
  Future<void> _confirmDeletion(
    BuildContext context,
    AppLocalizations l10n,
    String roomId,
  ) async {
    final deleteRoomCubit = context.read<DeleteRoomCubit>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.roomDetailDeleteConfirmTitle),
        content: Text(l10n.roomDetailDeleteConfirmMessage),
        actions: [
          TextButton(
            key: const Key('roomDetailDeleteCancelButton'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.roomDetailDeleteCancelButtonLabel),
          ),
          TextButton(
            key: const Key('roomDetailDeleteConfirmButton'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.roomDetailDeleteConfirmButtonLabel),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await deleteRoomCubit.deleteRoom(roomId);
    }
  }
}
