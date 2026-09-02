import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:youtogether/core/error/failures.dart';
import 'package:youtogether/features/auth/domain/entities/firebase_session_entity.dart';
import 'package:youtogether/features/auth/presentation/cubit/firebase_session_cubit.dart';
import 'package:youtogether/features/auth/presentation/cubit/firebase_session_state.dart';
import 'package:youtogether/features/auth/presentation/widgets/firebase_session_gate.dart';
import 'package:youtogether/l10n/generated/app_localizations.dart';

class MockFirebaseSessionCubit extends MockCubit<FirebaseSessionState>
    implements FirebaseSessionCubit {}

/// Widget tests for [FirebaseSessionGate].
///
/// The assertion that carries the most weight is that `builder` is
/// **not** called before a session is ready. Its subtree constructs
/// `PresenceCubit` with the session's uid, so an early call would write
/// presence under an empty key — which, before this ticket, meant
/// writing to the presence *parent* node and wiping every other
/// participant's entry.
///
/// @competency Unit/widget test harness, TDD cycle.
/// @competency Test scenarios A-FBS-08, A-FBS-10.
void main() {
  late MockFirebaseSessionCubit firebaseSessionCubit;

  const appUserId = '550e8400-e29b-41d4-a716-446655440000';
  const namedSession = FirebaseSessionEntity(
    uid: appUserId,
    isAnonymous: false,
  );

  setUp(() {
    firebaseSessionCubit = MockFirebaseSessionCubit();
    when(
      () =>
          firebaseSessionCubit.synchronise(appUserId: any(named: 'appUserId')),
    ).thenAnswer((_) async {});
  });

  Widget wrap(
    FirebaseSessionState state, {
    String? userId = appUserId,
    void Function(FirebaseSessionEntity)? onBuilt,
  }) {
    whenListen(
      firebaseSessionCubit,
      const Stream<FirebaseSessionState>.empty(),
      initialState: state,
    );

    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider<FirebaseSessionCubit>.value(
          value: firebaseSessionCubit,
          child: FirebaseSessionGate(
            appUserId: userId,
            builder: (context, session) {
              onBuilt?.call(session);
              return const SizedBox.shrink(key: Key('gatedSubtree'));
            },
          ),
        ),
      ),
    );
  }

  group('triggering', () {
    testWidgets('synchronises once on mount when no session is ready '
        '(A-FBS-08)', (tester) async {
      await tester.pumpWidget(wrap(const FirebaseSessionState.initial()));

      verify(
        () => firebaseSessionCubit.synchronise(appUserId: appUserId),
      ).called(1);
    });

    testWidgets('passes null for a visitor', (tester) async {
      await tester.pumpWidget(
        wrap(const FirebaseSessionState.initial(), userId: null),
      );

      verify(() => firebaseSessionCubit.synchronise(appUserId: null)).called(1);
    });

    testWidgets('does not synchronise when a session is already ready', (
      tester,
    ) async {
      // The warm path: a user who signed in on the login screen already
      // has a session by the time they reach a room.
      await tester.pumpWidget(
        wrap(const FirebaseSessionState.ready(namedSession)),
      );

      verifyNever(
        () => firebaseSessionCubit.synchronise(
          appUserId: any(named: 'appUserId'),
        ),
      );
    });

    testWidgets('does not synchronise again on a rebuild', (tester) async {
      await tester.pumpWidget(wrap(const FirebaseSessionState.initial()));
      await tester.pump();
      await tester.pump();

      verify(
        () => firebaseSessionCubit.synchronise(appUserId: appUserId),
      ).called(1);
    });

    testWidgets('re-synchronises when the application user changes', (
      tester,
    ) async {
      // A user signing in while a room is open must not keep acting
      // under the anonymous session established for them.
      await tester.pumpWidget(
        wrap(const FirebaseSessionState.initial(), userId: null),
      );
      await tester.pumpWidget(wrap(const FirebaseSessionState.initial()));

      verify(
        () => firebaseSessionCubit.synchronise(appUserId: appUserId),
      ).called(1);
    });
  });

  group('rendering', () {
    testWidgets('shows an indicator while establishing', (tester) async {
      await tester.pumpWidget(wrap(const FirebaseSessionState.establishing()));

      expect(
        find.byKey(const Key('firebaseSessionGateIndicator')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('gatedSubtree')), findsNothing);
    });

    testWidgets('does not build the subtree before a session exists '
        '(A-FBS-10)', (tester) async {
      FirebaseSessionEntity? built;

      await tester.pumpWidget(
        wrap(
          const FirebaseSessionState.establishing(),
          onBuilt: (session) => built = session,
        ),
      );

      expect(built, isNull);
    });

    testWidgets('builds the subtree with the session once ready', (
      tester,
    ) async {
      FirebaseSessionEntity? built;

      await tester.pumpWidget(
        wrap(
          const FirebaseSessionState.ready(namedSession),
          onBuilt: (session) => built = session,
        ),
      );

      expect(built, namedSession);
      expect(find.byKey(const Key('gatedSubtree')), findsOneWidget);
    });

    testWidgets('offers a retry on failure, never a spinner', (tester) async {
      await tester.pumpWidget(
        wrap(const FirebaseSessionState.failure(Failure.network())),
      );

      expect(
        find.byKey(const Key('firebaseSessionGateRetryButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('firebaseSessionGateIndicator')),
        findsNothing,
      );
      expect(find.byKey(const Key('gatedSubtree')), findsNothing);
    });

    testWidgets('re-synchronises when the retry button is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const FirebaseSessionState.failure(Failure.network())),
      );

      await tester.tap(find.byKey(const Key('firebaseSessionGateRetryButton')));
      await tester.pump();

      // Once on mount (the state is not ready), once on the tap.
      verify(
        () => firebaseSessionCubit.synchronise(appUserId: appUserId),
      ).called(2);
    });
  });
}
