import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/presence_cubit.dart';
import '../cubit/presence_state.dart';

/// Displays who is currently watching this room's broadcast, in real
/// time — a live count plus each participant's name.
///
/// Reads the ancestor [PresenceCubit] (provided by `RoomDetailPage`).
///
/// ## Only genuinely online participants are counted
/// [PresenceState.loaded] carries every child of the room's `presence`
/// node, which is **not** the same as everyone currently watching: the
/// Firebase `onDisconnect` handler registered in F-V05-T2 sets
/// `is_online: false` rather than deleting the node, so a participant
/// who crashed or lost the network stays in that list with the flag
/// cleared. Counting `participants.length` directly would therefore
/// over-report. Filtering on [PresenceEntity.isOnline] first is what
/// makes the number match what the user actually sees.
///
/// ## Zero versus unavailable
/// A count of zero is rendered plainly, as a real answer: nobody is
/// watching this room right now. That is deliberately distinguished
/// from [PresenceState.failure], which renders an "unavailable" notice
/// instead — showing "0 watching" when presence could not be read at
/// all would assert something false, and a viewer has no way to tell
/// the two apart otherwise.
///
/// This count is **not** the room's registered member count
/// (`RoomEntity.memberCount`, rendered separately by `RoomDetailView`):
/// see [PresenceCubit]'s own doc comment for why the two answer
/// different questions and are never combined.
class OnlineParticipantsIndicator extends StatelessWidget {
  const OnlineParticipantsIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PresenceCubit, PresenceState>(
      builder: (context, state) {
        switch (state) {
          case PresenceInitial():
            return const SizedBox.shrink();

          case PresenceLoading():
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                key: Key('onlineParticipantsLoadingIndicator'),
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );

          case PresenceFailure():
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Live participant list unavailable.',
                key: Key('onlineParticipantsUnavailable'),
              ),
            );

          case PresenceLoaded(:final participants):
            final online = participants
                .where((participant) => participant.isOnline)
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${online.length} watching now',
                  key: const Key('onlineParticipantsCount'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (online.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    key: const Key('onlineParticipantsList'),
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final participant in online)
                        Chip(
                          key: Key('onlineParticipant_${participant.userId}'),
                          label: Text(participant.username),
                        ),
                    ],
                  ),
                ],
              ],
            );
        }
      },
    );
  }
}
