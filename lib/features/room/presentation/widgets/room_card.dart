import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/room_entity.dart';

/// Card summarising a single room in the `HomePage` listing.
///
/// Acceptance criteria: displays the room name, a
/// description truncated at 100 characters, and the current member
/// count.
///
/// ## Join button
/// [onJoin] is a separate affordance from [onTap]: tapping the card
/// body navigates to `RoomDetailPage`, while tapping the join button
/// joins the room directly from the listing — both per this ticket's
/// requirement to support joining from either screen. `null` hides the
/// button entirely (used for unauthenticated viewers, decided by
/// `HomePage`, not by this widget). [isJoining] swaps the button for a
/// small per-card progress indicator while a request for *this*
/// specific room is in flight — `HomePage` shares one `JoinRoomCubit`
/// across every card, so only the room actually being joined shows
/// this, not the whole list.
class RoomCard extends StatelessWidget {
  const RoomCard({
    super.key,
    required this.room,
    this.onTap,
    this.onJoin,
    this.isJoining = false,
  });

  final RoomEntity room;

  /// Invoked when the card is tapped — navigates to `RoomDetailPage`
  /// from `HomePage`. `null` renders a plain, non-interactive card
  /// (used by `room_card_test.dart`'s rendering-only assertions).
  final VoidCallback? onTap;

  /// Invoked when the join button is tapped. `null` hides the button.
  final VoidCallback? onJoin;

  /// Whether a join request for this specific room is currently in
  /// flight. Ignored when [onJoin] is `null`.
  final bool isJoining;

  static const int _descriptionMaxLength = 100;

  String? get _truncatedDescription {
    final description = room.description;
    if (description == null || description.isEmpty) {
      return null;
    }
    if (description.length <= _descriptionMaxLength) {
      return description;
    }
    return '${description.substring(0, _descriptionMaxLength)}…';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final truncatedDescription = _truncatedDescription;

    return Card(
      key: Key('roomCard_${room.id}'),
      child: ListTile(
        onTap: onTap,
        title: Text(room.name, key: Key('roomCardName_${room.id}')),
        subtitle: truncatedDescription == null
            ? null
            : Text(
                truncatedDescription,
                key: Key('roomCardDescription_${room.id}'),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.homeRoomCardMemberCount(room.memberCount),
              key: Key('roomCardMemberCount_${room.id}'),
            ),
            if (onJoin != null) ...[
              const SizedBox(width: 8),
              if (isJoining)
                SizedBox(
                  key: Key('roomCardJoinLoadingIndicator_${room.id}'),
                  width: 20,
                  height: 20,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton(
                  key: Key('roomCardJoinButton_${room.id}'),
                  onPressed: onJoin,
                  child: Text(l10n.homeRoomCardJoinButtonLabel),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
