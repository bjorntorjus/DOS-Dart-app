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

/// The mode-specific slot currently rendered inside the shared active strip
/// (TARGET/ROUND block — replaced the old last-throw text for ATC, Shanghai
/// and Splitscore).
DossedartStripSlot _modeSlot(WidgetTester tester) =>
    tester.widget<DossedartStripSlot>(find.byType(DossedartStripSlot));

/// The strip's own score block (POINTS/PROGRESS/TOTAL value).
String _scoreValue(WidgetTester tester) => tester
    .widget<DossedartActiveStrip>(find.byType(DossedartActiveStrip))
    .scoreValue;

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
  testWidgets(
      'ATC strip TARGET/THEN/PROGRESS update dart-by-dart, matching the '
      'real target progression (countMultiples steps included)', (tester) async {
    final dynamic state = await _pumpAtc(tester);

    // Fresh game: P0 targets 1, next three targets follow in order.
    expect(_modeSlot(tester).value, '1');
    expect(_modeSlot(tester).subLine, 'THEN 2 › 3 › 4');
    expect(_scoreValue(tester), '0/20');

    // Dart 1: single on target 1 — one step, target becomes 2.
    await state.onDartHitForTest(1, 1);
    await tester.pumpAndSettle();
    expect(_modeSlot(tester).value, '2');
    expect(_modeSlot(tester).subLine, 'THEN 3 › 4 › 5');
    expect(_scoreValue(tester), '1/20');

    // Dart 2: double on the new target (2) — countMultiples means 2 steps,
    // target jumps 2 → 3 → 4.
    await state.onDartHitForTest(2, 2);
    await tester.pumpAndSettle();
    expect(_modeSlot(tester).value, '4');
    expect(_modeSlot(tester).subLine, 'THEN 5 › 6 › 7');
    expect(_scoreValue(tester), '3/20');
  });

  testWidgets(
      'ATC strip shows the active player\'s own target/progress only — '
      'switching players does not bleed state', (tester) async {
    final dynamic state = await _pumpAtc(tester);

    // P0 throws a full turn: S1 (→2), D2 (→4), MISS → auto-advance to P1.
    await state.onDartHitForTest(1, 1);
    await state.onDartHitForTest(2, 2);
    await state.onDartHitForTest(0, 0);
    await tester.pumpAndSettle();

    // P1 is now active and completely fresh — target 1, not P0's target 4.
    expect(_modeSlot(tester).value, '1',
        reason: 'P1 has thrown nothing — must show P1\'s own fresh target');
    expect(_modeSlot(tester).subLine, 'THEN 2 › 3 › 4');
    expect(_scoreValue(tester), '0/20');

    // P1 throws one dart — the strip advances P1's own target only.
    await state.onDartHitForTest(1, 1);
    await tester.pumpAndSettle();
    expect(_modeSlot(tester).value, '2');
    expect(_scoreValue(tester), '1/20');

    // P1 completes the turn (two misses) → back on P0, whose progress (4,
    // 3/20) must be exactly where it was left, untouched by P1's turn.
    await state.onDartHitForTest(0, 0);
    await state.onDartHitForTest(0, 0);
    await tester.pumpAndSettle();
    expect(_modeSlot(tester).value, '4',
        reason: 'P0\'s own target must be preserved across P1\'s turn');
    expect(_modeSlot(tester).subLine, 'THEN 5 › 6 › 7');
    expect(_scoreValue(tester), '3/20');
  });

  testWidgets(
      'Splitscore strip MISS HALVES preview matches the engine\'s '
      'truncating halving exactly (~/ 2, not .ceil()) and only moves at '
      'turn boundaries', (tester) async {
    final dynamic state = await _pumpSplitscore(tester);

    // Round 1 target is 15 (fixed rounds), fresh totals start at 40.
    expect(_modeSlot(tester).value, '15');
    expect(_modeSlot(tester).subLine, 'MISS HALVES 40 › 20');
    expect(_scoreValue(tester), '40');

    // P0 hits S15 then misses — turnPoints accrue internally, but totals
    // (and therefore the preview) must not move until the turn ends.
    await state.onDartHitForTest(15, 1);
    await state.onDartHitForTest(0, 0);
    await tester.pumpAndSettle();
    expect(_modeSlot(tester).subLine, 'MISS HALVES 40 › 20',
        reason: 'the preview must track the committed total, not the '
            'in-progress turn — otherwise it lies');

    // Third dart ends the turn: 40 + 15 = 55 (deliberately odd).
    await state.onDartHitForTest(0, 0);
    await tester.pumpAndSettle();
    expect(state.totalScores[0], 55);

    // Turn passed to P1 — the strip now shows P1's own, still-untouched 40.
    expect(_modeSlot(tester).subLine, 'MISS HALVES 40 › 20');
    expect(_scoreValue(tester), '40');

    // Finish P1's round-1 turn with three misses — halves 40 → 20 — which
    // closes round 1 and opens round 2 (target 16) back on P0.
    await state.onDartHitForTest(0, 0);
    await state.onDartHitForTest(0, 0);
    await state.onDartHitForTest(0, 0);
    await tester.pumpAndSettle();
    expect(state.totalScores[1], 20, reason: 'P1 halved: 40 ~/ 2 = 20');

    expect(_modeSlot(tester).value, '16');
    expect(_modeSlot(tester).subLine, 'MISS HALVES 55 › 27',
        reason: 'truncating division: 55 ~/ 2 = 27, NOT 28 (.ceil())');

    // Miss all three on round 2 — halve the odd 55 exactly like the engine.
    await state.onDartHitForTest(0, 0);
    await state.onDartHitForTest(0, 0);
    await state.onDartHitForTest(0, 0);
    await tester.pumpAndSettle();
    expect(state.totalScores[0], 27,
        reason: 'the preview promised 27 — the engine must deliver exactly '
            'that, not 28');
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

  testWidgets(
      'Splitscore scorecard shrink-wraps to content — freed space sits '
      'below the card, not inside the magenta border', (tester) async {
    // Tall, tablet-like surface so the flexible share offered to the
    // scorecard slot is larger than the fixed-round content height — the
    // regime where the old Expanded slot left empty bordered space under
    // the SUM row.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpSplitscore(tester);

    final sum = find.text('SUM');
    final scroll =
        find.ancestor(of: sum, matching: find.byType(SingleChildScrollView));
    // Nearest Container ancestor of the scroll view = the bordered card.
    final card =
        find.ancestor(of: scroll.first, matching: find.byType(Container));
    final cardRect = tester.getRect(card.first);
    // Nearest Container ancestor of the SUM text = the SUM row itself.
    final sumRowRect = tester
        .getRect(find.ancestor(of: sum, matching: find.byType(Container)).first);

    expect(cardRect.bottom - sumRowRect.bottom, lessThan(5),
        reason: 'the bordered card must end right under the SUM row '
            '(shrink-wrap); the old Expanded slot stretched the border far '
            'below it');

    // The freed space flows below the card: a clear gap separates the card
    // from the input area, which stays anchored at the bottom.
    final inputTop = tester.getRect(find.text('D15')).top;
    expect(inputTop - cardRect.bottom, greaterThan(100),
        reason: 'freed vertical space must sit between the card and the '
            'input area, not inside the card border');
  });

  testWidgets(
      'Shanghai strip ROUND/TARGET/TOTAL update per dart and advance the '
      'round exactly when the engine does', (tester) async {
    final dynamic state = await _pumpShanghai(tester);

    // Round 1 (target 1), P0 active.
    expect(_modeSlot(tester).label, 'ROUND 1');
    expect(_modeSlot(tester).value, 'TARGET 1');
    expect(_modeSlot(tester).subLine, 'S1 · D2 · T3');
    expect(_scoreValue(tester), '0');

    // Single (+1) then miss — total updates immediately per dart in Shanghai.
    state.onHitForTest(HitType.single);
    await tester.pump();
    expect(_scoreValue(tester), '1');
    state.onHitForTest(HitType.miss);
    await tester.pump();

    // Double (+2) is the third dart — no instant Shanghai (no triple) — ends
    // the turn and advances to P1, still round 1.
    state.onHitForTest(HitType.double_);
    await tester.pump();
    expect(state.engineForTest.currentPlayerIndex, 1);
    expect(_modeSlot(tester).label, 'ROUND 1');
    expect(_scoreValue(tester), '0', reason: 'P1 is fresh — own total, not P0\'s 3');

    // P1: single then two misses — closes round 1 for both players, so the
    // engine rolls to round 2 (target 2) back on P0.
    state.onHitForTest(HitType.single);
    await tester.pump();
    expect(_scoreValue(tester), '1');
    state.onHitForTest(HitType.miss);
    await tester.pump();
    state.onHitForTest(HitType.miss);
    await tester.pump();

    expect(state.engineForTest.currentPlayerIndex, 0);
    expect(_modeSlot(tester).label, 'ROUND 2');
    expect(_modeSlot(tester).value, 'TARGET 2');
    expect(_modeSlot(tester).subLine, 'S2 · D4 · T6');
    expect(_scoreValue(tester), '3',
        reason: 'P0\'s total (1 + 2 from round 1) must be untouched by '
            'round 2 opening');
  });

  testWidgets('Shanghai undo after add-player does not desync the strip',
      (tester) async {
    final dynamic state = await _pumpShanghai(tester);

    // P0 throws one dart — strip shows the updated total.
    state.onHitForTest(HitType.single);
    await tester.pump();
    expect(_scoreValue(tester), '1');

    // Mid-game add clears the engine's undo stack (same as the screen's
    // _addSavedPlayerMidGame path does via engine.addPlayer).
    state.engineForTest.addPlayer();
    expect(state.engineForTest.canUndo, isFalse,
        reason: 'sanity: add-player must clear the engine undo stack');

    // UNDO now: the engine no-ops, so the strip must not desync either.
    state.onUndoForTest();
    await tester.pump();
    expect(_scoreValue(tester), '1',
        reason: 'undo with an empty engine stack must leave the strip alone');
    expect(state.engineForTest.totalScores[0], 1,
        reason: 'the engine score must be untouched by the no-op undo');
  });
}
