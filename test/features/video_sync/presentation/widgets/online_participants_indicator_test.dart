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
  late MockPresenceCubit cubit;

  PresenceEntity participant(String id) => PresenceEntity(
    userId: id,
    username: 'User $id',
    isOnline: true,
    isAnonymous: false,
    lastSeen: DateTime.utc(2026, 1, 5),
  );

  setUp(() {
    cubit = MockPresenceCubit();
  });

  Widget wrap(PresenceState state) {
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

  testWidgets('shows the live participant count', (tester) async {
    await tester.pumpWidget(
      wrap(
        PresenceState.loaded([
          participant('a'),
          participant('b'),
          participant('c'),
        ]),
      ),
    );

    expect(
      find.byKey(const Key('onlineParticipantsIndicator')),
      findsOneWidget,
    );
    expect(find.textContaining('3'), findsOneWidget);
  });

  testWidgets(
    'shows zero when nobody is watching — a valid state, not an error',
    (tester) async {
      await tester.pumpWidget(
        wrap(const PresenceState.loaded(<PresenceEntity>[])),
      );

      expect(
        find.byKey(const Key('onlineParticipantsIndicator')),
        findsOneWidget,
      );
      expect(find.textContaining('0'), findsOneWidget);
    },
  );

  testWidgets('shows a placeholder while presence is still loading', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const PresenceState.loading()));

    expect(
      find.byKey(const Key('onlineParticipantsIndicatorLoading')),
      findsOneWidget,
    );
  });

  testWidgets('renders nothing on failure rather than a misleading zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const PresenceState.failure(Failure.firebase(message: 'lost'))),
    );

    expect(find.byKey(const Key('onlineParticipantsIndicator')), findsNothing);
    expect(
      find.byKey(const Key('onlineParticipantsIndicatorLoading')),
      findsNothing,
    );
  });
}
