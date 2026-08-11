import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/screens/post_game/match_summary.dart';
import 'package:dart_scoring/screens/post_game/post_game_fields.dart';
import 'package:dart_scoring/widgets/dossedart/post_game/dossedart_match_summary.dart';
import 'package:dart_scoring/widgets/dossedart/post_game/dossedart_placement_card.dart';
import 'package:dart_scoring/widgets/dossedart/post_game/dossedart_post_game_actions.dart';
import 'package:dart_scoring/widgets/dossedart/post_game/dossedart_winner_spotlight.dart';

Future<void> host(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(820, 1180);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SizedBox(width: 820, child: child))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('stat grid pads a partial last row to a clean rectangle',
      (tester) async {
    // 4 fields => 2 rows => 6 slots => 4 filled + 2 empty trailing tracks.
    await host(
      tester,
      DossedartPlacementCard(
        placement: 2,
        name: 'Mia',
        accent: Colors.cyan,
        fields: const PostGameFields(
          headlineLabel: 'SCORE',
          headlineValue: '204',
          fields: [
            StatField('A', '1'),
            StatField('B', '2'),
            StatField('C', '3'),
            StatField('D', '4'),
          ],
        ),
      ),
    );
    expect(find.byKey(const Key('statSlot')), findsNWidgets(4));
    expect(find.byKey(const Key('statSlotEmpty')), findsNWidgets(2));
  });

  testWidgets('an exactly-full row needs no padding', (tester) async {
    await host(
      tester,
      DossedartPlacementCard(
        placement: 1,
        name: 'Per',
        accent: Colors.cyan,
        fields: const PostGameFields(
          headlineLabel: 'SCORE',
          headlineValue: '412',
          fields: [
            StatField('A', '1'),
            StatField('B', '2'),
            StatField('C', '3'),
          ],
        ),
      ),
    );
    expect(find.byKey(const Key('statSlot')), findsNWidgets(3));
    expect(find.byKey(const Key('statSlotEmpty')), findsNothing);
  });

  testWidgets('a headline-only mode renders no grid at all', (tester) async {
    await host(
      tester,
      DossedartPlacementCard(
        placement: 3,
        name: 'Kari',
        accent: Colors.green,
        fields: const PostGameFields(
            headlineLabel: 'LIVES', headlineValue: '2', fields: []),
      ),
    );
    expect(find.byKey(const Key('statSlot')), findsNothing);
    expect(find.text('LIVES'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('a zero conditional field shows an em dash, not a gap',
      (tester) async {
    await host(
      tester,
      DossedartPlacementCard(
        placement: 1,
        name: 'Per',
        accent: Colors.cyan,
        fields: const PostGameFields(
          headlineLabel: 'SCORE',
          headlineValue: '412',
          fields: [StatField('STOLEN', '—', isZero: true)],
        ),
      ),
    );
    expect(find.text('STOLEN'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('a mode without Elo keeps the column and dims it',
      (tester) async {
    await host(
      tester,
      DossedartPlacementCard(
        placement: 1,
        name: 'Per',
        accent: Colors.cyan,
        showElo: false,
        ratingChange: 12.0, // present but must be ignored
        fields: const PostGameFields(
            headlineLabel: 'SCORE', headlineValue: '412', fields: []),
      ),
    );
    expect(find.text('ELO'), findsOneWidget);
    expect(find.text('▲+12.0'), findsNothing);
  });

  testWidgets('an unavailable action is dimmed, never removed',
      (tester) async {
    var continued = false;
    await host(
      tester,
      DossedartPostGameActions(
        canUndo: true,
        canContinue: false,
        canShowDetails: false,
        onBack: () {},
        onContinue: () => continued = true,
        onDetails: () {},
        onFinish: () {},
      ),
    );
    expect(find.text('▶ CONTINUE'), findsOneWidget);
    expect(find.text('▶ DETAILS'), findsOneWidget);
    expect(find.text('✓ FINISH GAME'), findsOneWidget);

    // Visible but inert — a dimmed action must not fire on a stray tap.
    await tester.tap(find.text('▶ CONTINUE'), warnIfMissed: false);
    await tester.pump();
    expect(continued, isFalse);
  });

  testWidgets('the primary action fires', (tester) async {
    var finished = false;
    await host(
      tester,
      DossedartPostGameActions(
        canUndo: false,
        canContinue: false,
        canShowDetails: false,
        onBack: () {},
        onContinue: () {},
        onDetails: () {},
        onFinish: () => finished = true,
      ),
    );
    await tester.tap(find.text('✓ FINISH GAME'));
    await tester.pump();
    expect(finished, isTrue);
  });

  testWidgets('a degraded summary keeps all six cells and flags the label',
      (tester) async {
    await host(
      tester,
      DossedartMatchSummary(summary: matchSummaryFrom(durationSeconds: 600)),
    );
    expect(find.text('DURATION'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('BIGGEST LEAD'), findsOneWidget);
    expect(find.text('NOT RECORDED'), findsOneWidget);
    expect(find.textContaining('partly unavailable'), findsOneWidget);
  });

  testWidgets('the spotlight names the winner and repeats the headline',
      (tester) async {
    await host(
      tester,
      const DossedartWinnerSpotlight(
        name: 'Jonas',
        headlineLabel: '3-DART AVG',
        headlineValue: '62.4',
        ratingChange: 12.3,
      ),
    );
    expect(find.text('★ WINNER ★'), findsOneWidget);
    expect(find.text('JONAS'), findsOneWidget);
    expect(find.text('3-DART AVG 62.4'), findsOneWidget);
    expect(find.text('+12.3'), findsOneWidget);
  });

  testWidgets('a long name shrinks rather than wrapping', (tester) async {
    const long = 'Christopher Nordbo-Hansen';
    await host(
      tester,
      const DossedartWinnerSpotlight(
        name: long,
        headlineLabel: 'SCORE',
        headlineValue: '412',
      ),
    );
    final text = tester.widget<Text>(find.text(long.toUpperCase()));
    expect(text.style!.fontSize, 13, reason: 'longest bucket of the curve');
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });
}
