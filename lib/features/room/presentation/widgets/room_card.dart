import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/room_entity.dart';

/// Card summarising a single room in the `HomePage` listing.
///
/// Acceptance criteria: displays the room name, a
/// description truncated at 100 characters, and the current member
/// count. Purely presentational — no join action here (which will
/// most likely extend this widget rather
/// than replace it).
class RoomCard extends StatelessWidget {
  const RoomCard({super.key, required this.room});

  final RoomEntity room;

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
        title: Text(room.name, key: Key('roomCardName_${room.id}')),
        subtitle: truncatedDescription == null
            ? null
            : Text(
                truncatedDescription,
                key: Key('roomCardDescription_${room.id}'),
              ),
        trailing: Text(
          l10n.homeRoomCardMemberCount(room.memberCount),
          key: Key('roomCardMemberCount_${room.id}'),
        ),
      ),
    );
  }
}
