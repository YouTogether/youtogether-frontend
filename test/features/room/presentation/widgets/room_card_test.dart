import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtogether/features/room/domain/entities/room_entity.dart';
import 'package:youtogether/features/room/presentation/widgets/room_card.dart';
import 'package:youtogether/l10n/generated/app_localizations.dart';

/// Widget tests for [RoomCard] (F-R01-T3 — presentation layer).
///
/// @competency Unit/widget test harness, TDD cycle.
void main() {
  RoomEntity buildRoom({String? description, int memberCount = 3}) =>
      RoomEntity(
        id: '7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f',
        name: 'Friday Movie Night',
        description: description,
        ownerId: '550e8400-e29b-41d4-a716-446655440000',
        isPublic: true,
        memberCount: memberCount,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

  Future<void> pumpRoomCard(WidgetTester tester, RoomEntity room) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: RoomCard(room: room)),
      ),
    );
  }

  testWidgets('renders the room name', (tester) async {
    await pumpRoomCard(tester, buildRoom(description: 'Weekly watch party'));

    expect(find.text('Friday Movie Night'), findsOneWidget);
  });

  testWidgets('renders the description when under 100 characters', (
    tester,
  ) async {
    await pumpRoomCard(tester, buildRoom(description: 'Weekly watch party'));

    expect(find.text('Weekly watch party'), findsOneWidget);
  });

  testWidgets('truncates a description longer than 100 characters', (
    tester,
  ) async {
    final longDescription = List.filled(150, 'a').join();
    await pumpRoomCard(tester, buildRoom(description: longDescription));

    final truncated = tester.widgetList<Text>(
      find.byKey(
        const Key('roomCardDescription_7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f'),
      ),
    );
    final renderedText = truncated.single.data!;
    expect(renderedText.length, lessThanOrEqualTo(101)); // 100 chars + ellipsis
  });

  testWidgets('renders no description widget when null', (tester) async {
    await pumpRoomCard(tester, buildRoom());

    expect(
      find.byKey(
        const Key('roomCardDescription_7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f'),
      ),
      findsNothing,
    );
  });

  testWidgets('renders the member count', (tester) async {
    await pumpRoomCard(tester, buildRoom(memberCount: 5));

    expect(find.textContaining('5'), findsOneWidget);
  });

  testWidgets('invokes onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RoomCard(room: buildRoom(), onTap: () => tapped = true),
        ),
      ),
    );

    await tester.tap(find.byType(RoomCard));
    await tester.pump();

    expect(tapped, isTrue);
  });

  group('RoomCard — join button (F-R05-T3)', () {
    Future<void> pumpWithJoin(
      WidgetTester tester, {
      VoidCallback? onJoin,
      bool isJoining = false,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RoomCard(
              room: buildRoom(),
              onJoin: onJoin,
              isJoining: isJoining,
            ),
          ),
        ),
      );
    }

    testWidgets('hidden when onJoin is null', (tester) async {
      await pumpWithJoin(tester, onJoin: null);

      expect(
        find.byKey(
          const Key('roomCardJoinButton_7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f'),
        ),
        findsNothing,
      );
    });

    testWidgets('visible and calls onJoin when tapped', (tester) async {
      var joined = false;
      await pumpWithJoin(tester, onJoin: () => joined = true);

      final joinButtonFinder = find.byKey(
        const Key('roomCardJoinButton_7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f'),
      );
      expect(joinButtonFinder, findsOneWidget);

      await tester.tap(joinButtonFinder);
      await tester.pump();

      expect(joined, isTrue);
    });

    testWidgets('shows a per-card progress indicator instead of the button while '
        'isJoining is true', (tester) async {
      await pumpWithJoin(tester, onJoin: () {}, isJoining: true);

      expect(
        find.byKey(
          const Key(
            'roomCardJoinLoadingIndicator_7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('roomCardJoinButton_7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f'),
        ),
        findsNothing,
      );
    });

    testWidgets('tapping the join button does not also trigger onTap', (
      tester,
    ) async {
      var tapped = false;
      var joined = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RoomCard(
              room: buildRoom(),
              onTap: () => tapped = true,
              onJoin: () => joined = true,
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(
          const Key('roomCardJoinButton_7b2e6b0a-2f2a-4b6a-8e2a-1a2b3c4d5e6f'),
        ),
      );
      await tester.pump();

      expect(joined, isTrue);
      expect(tapped, isFalse);
    });
  });
}
