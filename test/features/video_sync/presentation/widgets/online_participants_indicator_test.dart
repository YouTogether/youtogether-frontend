import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/video_sync/domain/entities/presence_entity.dart';
import 'package:youtogether/features/video_sync/presentation/cubit/presence_cubit.dart';
import 'package:youtogether/features/video_sync/presentation/cubit/presence_state.dart';
import 'package:youtogether/features/video_sync/presentation/widgets/online_participants_indicator.dart';

class MockPresenceCubit extends MockCubit<PresenceState>
    implements PresenceCubit {}

/// Widget tests for [OnlineParticipantsIndicator].
///
/// @competency Unit/widget test harness.
/// @competency Test scenarios.
void main() {
  PresenceEntity participant(
    String name, {
    bool isOnline = true,
    bool isAnonymous = false,
  }) => PresenceEntity(
    userId: name,
    username: name,
    isOnline: isOnline,
    isAnonymous: isAnonymous,
    lastSeen: DateTime.utc(2026, 1, 5),
  );

  Widget wrap(PresenceState state) {
    final cubit = MockPresenceCubit();
    whenListen(cubit, const Stream<PresenceState>.empty(), initialState: state);

    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<PresenceCubit>.value(
          value: cubit,
          child: const OnlineParticipantsIndicator(),
        ),
      ),
    );
  }

  testWidgets('shows a zero count when nobody is present', (tester) async {
    await tester.pumpWidget(
      wrap(const PresenceState.loaded(<PresenceEntity>[])),
    );

    expect(find.byKey(const Key('onlineParticipantsCount')), findsOneWidget);
    expect(find.textContaining('0'), findsOneWidget);
  });

  testWidgets('shows the live count and every online participant\'s name', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(PresenceState.loaded([participant('Alice'), participant('Bob')])),
    );

    expect(find.textContaining('2'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets(
    'excludes participants flagged offline from both the count and the list — '
    'onDisconnect clears is_online rather than deleting the node',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          PresenceState.loaded([
            participant('Alice'),
            participant('Ghost', isOnline: false),
          ]),
        ),
      );

      expect(find.textContaining('1'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Ghost'), findsNothing);
    },
  );

  testWidgets('lists anonymous participants alongside registered ones', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        PresenceState.loaded([
          participant('Alice'),
          participant('Guest', isAnonymous: true),
        ]),
      ),
    );

    expect(find.textContaining('2'), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);
  });

  testWidgets('shows a loading indicator while presence is being established', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const PresenceState.loading()));

    expect(
      find.byKey(const Key('onlineParticipantsLoadingIndicator')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('onlineParticipantsCount')), findsNothing);
  });

  testWidgets('renders nothing in the initial state', (tester) async {
    await tester.pumpWidget(wrap(const PresenceState.initial()));

    expect(find.byKey(const Key('onlineParticipantsCount')), findsNothing);
    expect(
      find.byKey(const Key('onlineParticipantsLoadingIndicator')),
      findsNothing,
    );
  });

  testWidgets('shows an unavailable notice on failure, not a misleading zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const PresenceState.failure(Failure.firebase(message: 'lost'))),
    );

    expect(
      find.byKey(const Key('onlineParticipantsUnavailable')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('onlineParticipantsCount')), findsNothing);
  });
}
