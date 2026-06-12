import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/shanghai_engine.dart';
import 'package:dart_scoring/screens/around_the_clock_game_screen.dart';
import 'package:dart_scoring/screens/halve_it_game_screen.dart';
import 'package:dart_scoring/screens/shanghai_game_screen.dart';
import 'package:dart_scoring/widgets/dossedart/dossedart_active_strip.dart';

/// The lastThrowLabel currently rendered by the shared active strip.
String? _stripLabel(WidgetTester tester) => tester
    .widget<DossedartActiveStrip>(find.byType(DossedartActiveStrip))
    .lastThrowLabel;

Future<dynamic> _pumpAtc(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final players = [
    Player(name: 'P0', score: 0),
    Player(name: 'P1', score: 0),
  ];
  await tester.pumpWidget(MaterialApp(
    home: AroundTheClockGameScreen(
      players: players,
      config: const AroundTheClockConfig(
        includeBull: false,
        countMultiples: true,
        reverse: false,
      ),
      useDossedartDesign: true,
    ),
  ));
  await tester.pumpAndSettle();
  return tester.state<State<AroundTheClockGameScreen>>(
      find.byType(AroundTheClockGameScreen));
}

Future<dynamic> _pumpSplitscore(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final players = [
    Player(name: 'P0', score: 0),
    Player(name: 'P1', score: 0),
  ];
  await tester.pumpWidget(MaterialApp(
    home: HalveItGameScreen(
      players: players,
      config: const HalveItConfig(isRandom: false),
      useDossedartDesign: true,
    ),
  ));
  await tester.pumpAndSettle();
  return tester
      .state<State<HalveItGameScreen>>(find.byType(HalveItGameScreen));
}

Future<dynamic> _pumpShanghai(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final players = [
    Player(name: 'P0', score: 0),
    Player(name: 'P1', score: 0),
  ];
  await tester.pumpWidget(MaterialApp(
    home: ShanghaiGameScreen(
      players: players,
      config: const ShanghaiConfig(targetEnd: 7),
      useDossedartDesign: true,
    ),
  ));
  // Avoid pumpAndSettle right after initState — service init timers can keep
  // the tree busy (same approach as shanghai_postgame_undo_test.dart).
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return tester
      .state<State<ShanghaiGameScreen>>(find.byType(ShanghaiGameScreen));
}

void main() {
  testWidgets('ATC strip accumulates the turn darts live, without suffixes',
      (tester) async {
    final dynamic state = await _pumpAtc(tester);

    // Dart 1 (target 1, single) shows immediately.
    await state.onDartHitForTest(1, 1);
    await tester.pumpAndSettle();
    expect(_stripLabel(tester), 'S1',
        reason: 'the strip must show the in-progress turn after dart 1');

    // Dart 2: double on the new target (2) — old per-dart label carried a
    // "+2 steps" suffix; the joined view shows the plain label only.
    await state.onDartHitForTest(2, 2);
    await tester.pumpAndSettle();
    expect(_stripLabel(tester), 'S1 · D2',
        reason: 'the strip must grow dart-by-dart within the turn');
    expect(find.textContaining('steps'), findsNothing,
        reason: 'per-dart suffixes do not fit the joined 3-dart row');
    expect(find.textContaining('S1 · D2'), findsOneWidget,
        reason: 'the joined label must actually render in the strip');
  });

  testWidgets('ATC strip falls back to the active player\'s own previous turn',
      (tester) async {
    final dynamic state = await _pumpAtc(tester);

    // P0 throws a full turn: S1, D2, MISS → auto-advance to P1.
    await state.onDartHitForTest(1, 1);
    await state.onDartHitForTest(2, 2);
    await state.onDartHitForTest(0, 0);
    await tester.pumpAndSettle();
    expect(_stripLabel(tester), isNull,
        reason: 'P1 is active and has thrown nothing — placeholder expected');

    // P1 throws one dart — the strip shows exactly that dart.
    await state.onDartHitForTest(1, 1);
    await tester.pumpAndSettle();
    expect(_stripLabel(tester), 'S1',
        reason: 'the strip shows the active player\'s own darts only');

    // P1 completes the turn → back on P0 the strip shows P0's previous turn.
    await state.onDartHitForTest(0, 0);
    await state.onDartHitForTest(0, 0);
    await tester.pumpAndSettle();
    expect(_stripLabel(tester), 'S1 · D2 · MISS',
        reason: 'between turns the strip falls back to the previous turn');
  });

  testWidgets('Splitscore strip accumulates live and undo regroups the turn',
      (tester) async {
    final dynamic state = await _pumpSplitscore(tester);

    // Round 1 target is 15 (fixed rounds). S15, MISS, T15 ends the turn.
    await state.onDartHitForTest(15, 1);
    await state.onDartHitForTest(0, 0);
    await tester.pumpAndSettle();
    expect(_stripLabel(tester), 'S15 · MISS',
        reason: 'the strip must show the in-progress turn live — plain '
            'labels only, the "✓ (+points)" suffix is dropped');

    await state.onDartHitForTest(15, 3);
    await tester.pumpAndSettle();
    expect(_stripLabel(tester), isNull,
        reason: 'turn ended — P1 is active with no darts yet');

    // Undo crosses the turn boundary: P0 active again with two darts.
    state.undoForTest();
    await tester.pumpAndSettle();
    expect(_stripLabel(tester), 'S15 · MISS',
        reason: 'undo must roll the strip back to the in-progress turn');

    // A re-thrown dart joins the SAME turn (turnId counter was rewound).
    // It is dart 3, so the turn ends immediately — verify via the history.
    await state.onDartHitForTest(15, 2);
    await tester.pumpAndSettle();
    final turnIds =
        (state.throwHistory as List).map((t) => t.turnId).toSet();
    expect(turnIds.length, 1,
        reason: 'undo + rethrow must extend the same turn, not start a new one');
    expect(_stripLabel(tester), isNull,
        reason: 'the completed turn advanced play to P1 again');
  });

  testWidgets(
      'Splitscore scorecard renders the SUM row inside the scroll content, '
      'directly under the round rows, without overflow', (tester) async {
    await _pumpSplitscore(tester);

    expect(tester.takeException(), isNull,
        reason: 'the cockpit must build without overflow with the fixed '
            'round config');

    // The SUM row scrolls with the round rows (no pinned row with dead
    // space above it) — it must be a descendant of the scorecard's
    // SingleChildScrollView.
    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.text('SUM'),
      ),
      findsOneWidget,
      reason: 'the SUM row must sit in the scrollable column, directly '
          'under the round rows',
    );
  });

  testWidgets('Shanghai strip accumulates live and falls back between turns',
      (tester) async {
    final dynamic state = await _pumpShanghai(tester);

    // P0, round 1 (target 1): single, miss.
    state.onHitForTest(HitType.single);
    state.onHitForTest(HitType.miss);
    await tester.pump();
    expect(_stripLabel(tester), 'S1 · MISS',
        reason: 'the strip must show the in-progress turn live');

    // Third dart (double — no instant Shanghai) ends the turn → P1 active.
    state.onHitForTest(HitType.double_);
    await tester.pump();
    expect(_stripLabel(tester), isNull,
        reason: 'P1 has thrown nothing yet — placeholder expected');

    // P1 throws one dart — strip shows exactly that dart.
    state.onHitForTest(HitType.triple);
    await tester.pump();
    expect(_stripLabel(tester), 'T1',
        reason: 'the strip shows the active player\'s own darts only');

    // Undo: the dart disappears and the strip is empty again for P1.
    state.onUndoForTest();
    await tester.pump();
    expect(_stripLabel(tester), isNull,
        reason: 'undo must remove the dart from the live strip');
  });

  testWidgets('Shanghai undo after add-player does not desync the strip',
      (tester) async {
    final dynamic state = await _pumpShanghai(tester);

    // P0 throws one dart — strip shows it.
    state.onHitForTest(HitType.single);
    await tester.pump();
    expect(_stripLabel(tester), 'S1');

    // Mid-game add clears the engine's undo stack (same as the screen's
    // _addSavedPlayerMidGame path does via engine.addPlayer).
    state.engineForTest.addPlayer();
    expect(state.engineForTest.canUndo, isFalse,
        reason: 'sanity: add-player must clear the engine undo stack');

    // UNDO now: the engine no-ops, so the screen-side history must not
    // rewind either — otherwise the strip desyncs and the next dart merges
    // into the wrong turn group.
    state.onUndoForTest();
    await tester.pump();
    expect(_stripLabel(tester), 'S1',
        reason: 'undo with an empty engine stack must leave the strip alone');
    expect(state.engineForTest.totalScores[0], 1,
        reason: 'the engine score must be untouched by the no-op undo');
  });
}
