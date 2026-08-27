import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/presence_cubit.dart';
import '../cubit/presence_state.dart';

/// Displays how many people are watching this room's broadcast right
/// now, from the ancestor [PresenceCubit].
///
/// This is a live participant count, not the room's member count — see
/// [PresenceCubit]'s own doc comment for why the two are deliberately
/// kept apart. `0 watching` is a normal, correct reading whenever
/// nobody has the player open.
///
/// On [PresenceState.failure] this renders nothing at all rather than
/// falling back to `0`: a zero the user cannot distinguish from a real
/// empty room would be actively misleading, and there is no honest
/// number to show when the presence subscription is down.
class OnlineParticipantsIndicator extends StatelessWidget {
  const OnlineParticipantsIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PresenceCubit, PresenceState>(
      builder: (context, state) {
        return switch (state) {
          PresenceLoaded(:final participants) => Row(
            key: const Key('onlineParticipantsIndicator'),
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.visibility, size: 18),
              const SizedBox(width: 6),
              Text('${participants.length} watching'),
            ],
          ),
          PresenceInitial() || PresenceLoading() => const Row(
            key: Key('onlineParticipantsIndicatorLoading'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.visibility, size: 18),
              SizedBox(width: 6),
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
          PresenceFailure() => const SizedBox.shrink(),
        };
      },
    );
  }
}
