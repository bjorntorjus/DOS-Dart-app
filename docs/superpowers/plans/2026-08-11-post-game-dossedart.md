# Post-game DOSSEDART Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild `PostGameScreen` in the DOSSEDART arcade language per the 2026-08-10 design round, replacing the single joined stat string with a fixed three-column grid and adding a match-summary zone.

**Architecture:** Four pinned/flex zones (TopBar 52 · Winner 196 · Scroll flex · Actions 134) where only the middle scrolls and the action bar is a sibling of the scroll view, never its last item. Two pure Dart units carry the logic — `postGameFields()` turns a mode + `PlayerResult.stats` into a headline plus an ordered field list, and `matchSummaryFrom()` derives the game-level numbers from `throwHistory`. Four presentation widgets consume them. No engine, scoring or stats behaviour changes.

**Tech Stack:** Flutter / Dart, `flutter_test`. No new dependencies.

**Fasit:** `docs/design/dossedart-handoff/post-game/design_handoff_postgame_round/` — `HANDOVER.md` plus the two spec cards in `postgame-round-spec.jsx`. Where an artboard implies behaviour the spec cards do not state, the spec cards win.

## Global Constraints

- **DOSSEDART tokens only** (`lib/theme/dossedart_tokens.dart`). No raw hex, no `colorScheme`.
- `Press Start 2P` (PS) and `VT323` (VT). **No border-radius anywhere.**
- All UI strings **English**; code and comments English.
- Player accents come from `dossedartAccent(seatIndex)` — the 5-accent cycle. Yellow and red are never player accents.
- Frame is 820 × 1180 portrait (tablet). Zone budget is fasit: `TOPBAR 52 · WINNER 196 · SCROLL flex · ACTIONS 134`.
- Reused verbatim, internals untouched: `ProgressionChart`, `GolfScoreGrid`, `DossedartCrtFrame`, `DossedartTopBar`, `DossedartPlayerAvatar`.
- Run `flutter analyze lib test` and `flutter test` before each commit.

## Deviations from the artboard — decided up front, each with a reason

1. **No `YOU` tag.** The artboard tags one standings row `YOU`. The app has no concept of a local player — it is a shared-device scorer where every seat is equally "you". Implementing it would need a new setting with no user-facing meaning. Omitted; the row header keeps its remaining elements at the same geometry.
2. **Medal colours use existing tokens.** The spec names silver `#C0C0C0`, but `DossedartTokens.silver` (`#C9D2DA`) and `DossedartTokens.bronze` already exist in the arcade palette. Using them honours the higher "tokens only, no raw hex" rule at an imperceptible colour difference.
3. **PROPOSAL 1 (duration mirrored in the TopBar) is NOT implemented** — parked by default, per the spec card. The artboard shows it; the spec card marks it a proposal, and the spec card wins.
4. **Wave-2 stat fields are not invented.** The artboard's demo data shows `100+ / 140+ / 180`, `CHECKOUT %`, `FIRST-9`, `HALVING LOSSES`, `CHAOS PEAK`. Those counters do not exist yet. Each mode declares the fields it actually has; the ordering rule appends new ones later with no layout work. Card heights therefore land one grid row shorter than the artboard for X01 and Wildcard until wave 2 ships.

---

### Task 1: Game duration reaches the result screen

**Files:**
- Modify: `lib/models/game_result.dart`
- Modify: all ten game screens' `GameResult(...)` construction
- Test: `test/screens/post_game_duration_test.dart` (create)

**Interfaces:**
- Produces: `GameResult.durationSeconds` (`int?`) — seconds from the screen's `_gameStart` to game end; null when a mode does not pass it.

**Context:** Every screen already holds `final DateTime _gameStart = DateTime.now();` and `GameHistoryEntry` already has a `durationSeconds` field, so the value exists — it just never reaches `GameResult`. DURATION is the one match-summary cell that survives the degraded state, so it cannot come from `throwHistory`.

- [ ] **Step 1: Write the failing test**

```dart
// test/screens/post_game_duration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/game_result.dart';

void main() {
  test('durationSeconds defaults to null and round-trips when set', () {
    final bare = GameResult(gameMode: 'x01', results: const []);
    expect(bare.durationSeconds, isNull);

    final timed =
        GameResult(gameMode: 'x01', results: const [], durationSeconds: 1122);
    expect(timed.durationSeconds, 1122);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/post_game_duration_test.dart`
Expected: FAIL — `No named parameter with the name 'durationSeconds'`.

- [ ] **Step 3: Write minimal implementation**

In `lib/models/game_result.dart`, add the field beside `detailEntry`:

```dart
  /// Wall-clock seconds from the screen's `_gameStart` to game end, for the
  /// post-game MATCH SUMMARY's DURATION cell. It cannot be derived from
  /// [throwHistory] — and DURATION is the one summary value that still
  /// renders when throwHistory is suppressed by a roster change.
  final int? durationSeconds;
```

and to the constructor: `this.durationSeconds,`.

Then in each of the ten screens, at the `GameResult(` that feeds `PostGameScreen`, add:

```dart
      durationSeconds: DateTime.now().difference(_gameStart).inSeconds,
```

Find them with `grep -rn "GameResult(" lib/screens/*_game_screen.dart lib/screens/game_screen.dart`. A screen with more than one construction site (a normal end and an early-termination end) gets it at every site.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/post_game_duration_test.dart && flutter analyze lib`
Expected: PASS, no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add lib/models/game_result.dart lib/screens test/screens/post_game_duration_test.dart
git commit -m "feat(post-game): carry game duration into GameResult"
```

---

### Task 2: Per-mode headline and ordered field list

**Files:**
- Create: `lib/screens/post_game/post_game_fields.dart`
- Test: `test/screens/post_game_fields_test.dart` (create)

**Interfaces:**
- Produces:
  - `class StatField { final String label; final String value; final bool isZero; }`
  - `class PostGameFields { final String headlineLabel; final String headlineValue; final List<StatField> fields; }`
  - `PostGameFields postGameFields(String gameMode, Map<String, dynamic> stats)`

**Context — this is the fasit ordering rule:** the mode's headline never enters the grid; it lives in the standings row header. The remaining fields fill left→right, top→bottom **in the order the mode declares them**, and a future wave-2 counter is appended to its mode's list and lands in the next free slot. No per-mode layout tuning.

Conditional fields at zero (`Elims`, `Stolen`, `Rounds won`, `Shanghai!`) are **rendered in place, dimmed, value `—`** — never removed, so two games of the same mode have identical geometry. That is what `isZero` marks.

The declared orders come from today's `_PlayerResultTile._buildStats` in `post_game_screen.dart`, minus each mode's headline:

| Mode | Headline | Ordered fields |
|---|---|---|
| x01 | `3-DART AVG` = `avgTurn` | BEST, DARTS, CHECKOUT |
| cricket | `POINTS` = `points` | CLOSED |
| aroundTheClock | `REACHED` = `reached` | DARTS |
| killer | `LIVES` = `lives` | — (headline only) |
| halveIt | `SCORE` = `score` | HALVED |
| gotcha | `SCORE` = `score` | KILLS, KILLED, BUSTS, BEST, DARTS |
| oneUp | `LIVES LOST` = `livesLost` | BEST, TARGETS, TURNS, LAST-DART SAVES, ROUNDS WON, ELIMS |
| golf | `STROKES` = `strokes (±vsPar)` | ACES, BOGEYS, BEST HOLE, 1ST-DART, TERMS |
| shanghai | `SCORE` = `score` | BEST ROUND, SHANGHAI! |
| wildcard | `SCORE` = `score` | JOKERS, PRIZES, STOLEN, BEST, DARTS |

A field whose stat is absent (`null`) is skipped entirely — absent is not the same as zero. A field that is present but zero **and** in the conditional set is kept with `isZero: true`.

- [ ] **Step 1: Write the failing test**

```dart
// test/screens/post_game_fields_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/screens/post_game/post_game_fields.dart';

void main() {
  test('x01: headline is the average, and it never enters the grid', () {
    final f = postGameFields('x01', {
      'avgTurn': 62.4,
      'highestTurn': 140,
      'darts': 24,
      'checkout': 'D20',
    });
    expect(f.headlineLabel, '3-DART AVG');
    expect(f.headlineValue, '62.4');
    expect(f.fields.map((e) => e.label), ['BEST', 'DARTS', 'CHECKOUT']);
    expect(f.fields.map((e) => e.value), ['140', '24', 'D20']);
  });

  test('declared order is preserved, not the map order', () {
    final f = postGameFields('gotcha', {
      'darts': 27,
      'score': 301,
      'busts': 2,
      'kills': 3,
      'timesKilled': 1,
      'highestTurn': 96,
    });
    expect(f.headlineValue, '301');
    expect(f.fields.map((e) => e.label),
        ['KILLS', 'KILLED', 'BUSTS', 'BEST', 'DARTS']);
  });

  test('a conditional field at zero is kept, dimmed, with an em dash', () {
    final f = postGameFields('wildcard', {
      'score': 204,
      'jokersHit': 1,
      'windowPrizes': 0,
      'pointsStolen': 0,
      'highestTurn': 60,
      'darts': 27,
    });
    final stolen = f.fields.firstWhere((e) => e.label == 'STOLEN');
    expect(stolen.isZero, isTrue);
    expect(stolen.value, '—');
    expect(f.fields.length, 5, reason: 'geometry must not change at zero');
  });

  test('an absent stat is skipped — absent is not zero', () {
    final f = postGameFields('x01', {'avgTurn': 40.0, 'highestTurn': 100});
    expect(f.fields.map((e) => e.label), ['BEST']);
  });

  test('golf folds vs-par into the headline value', () {
    final f = postGameFields('golf', {'strokes': 54, 'vsPar': 3});
    expect(f.headlineLabel, 'STROKES');
    expect(f.headlineValue, '54 (+3)');
  });

  test('killer is headline-only and yields an empty grid', () {
    final f = postGameFields('killer', {'lives': 2});
    expect(f.headlineValue, '2');
    expect(f.fields, isEmpty);
  });

  test('an unknown mode degrades to an empty headline rather than throwing', () {
    final f = postGameFields('nope', {});
    expect(f.headlineValue, '—');
    expect(f.fields, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/post_game_fields_test.dart`
Expected: FAIL — the library does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/screens/post_game/post_game_fields.dart` with the three types above. Shape:

```dart
/// One cell of the post-game stat grid.
class StatField {
  const StatField(this.label, this.value, {this.isZero = false});
  final String label;
  final String value;

  /// A conditional counter that resolved to zero. Rendered in place and
  /// dimmed with an em dash rather than removed, so two games of the same
  /// mode have identical grid geometry (design fasit 2026-08-10).
  final bool isZero;
}

class PostGameFields {
  const PostGameFields({
    required this.headlineLabel,
    required this.headlineValue,
    required this.fields,
  });
  final String headlineLabel;
  final String headlineValue;
  final List<StatField> fields;
}
```

Implement `postGameFields` as a `switch (gameMode)` building the list in the declared order, using small local helpers: one that formats a value, one that emits a conditional field (`isZero` when the value is 0, value `'—'`), and one that returns null for an absent stat so it can be filtered out. Reuse `vsParText` from `post_game_screen.dart` for golf — import it rather than duplicating the formatting.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/post_game_fields_test.dart`
Expected: PASS — 7 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/post_game/post_game_fields.dart test/screens/post_game_fields_test.dart
git commit -m "feat(post-game): per-mode headline + ordered stat field list"
```

---

### Task 3: Match summary computation

**Files:**
- Create: `lib/screens/post_game/match_summary.dart`
- Test: `test/screens/match_summary_test.dart` (create)

**Interfaces:**
- Produces:
  - `class MatchSummary { final String duration; final String? rounds; final String? darts; final String? bestTurn; final String? bestTurnBy; final String? hitDistribution; final String? biggestLead; bool get degraded; }`
  - `MatchSummary matchSummaryFrom({int? durationSeconds, List<DartThrow>? throws, List<String> playerNames, List<num>? Function(int seat)? seriesFor})`

**Context:** Six cells — DURATION, ROUNDS, DARTS THROWN, BEST TURN (with a `NAME · Rn` sub-line), HIT DISTRIBUTION (`T n · D n · B n · ✗ n`), BIGGEST LEAD.

**The degraded state is fasit, not an edge case.** `throwHistory` is suppressed whenever the roster changed mid-game, so DURATION renders normally and the other five become null → the widget dims them to an em dash and BEST TURN carries `NOT RECORDED`. The zone keeps its full size. The same applies to BIGGEST LEAD alone in 1UP and Killer, which have no progression series — hence `seriesFor` being nullable per seat.

Derivations, all from `DartThrow`:
- rounds = distinct `roundNumber` count.
- darts = `throws.length`.
- best turn = group by `turnId`, sum `points`, take the max; sub-line is the thrower's name plus `R{roundNumber + 1}`.
- hit distribution: triples `multiplier == 3`, doubles `multiplier == 2`, bulls `segment == 25`, misses `multiplier == 0`. Bull is counted as a bull, not also as a single/double — check `segment == 25` first.
- biggest lead = the largest gap between the best and worst series value at the same round index, across the rounds every seat has reached.

- [ ] **Step 1: Write the failing test**

```dart
// test/screens/match_summary_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/screens/post_game/match_summary.dart';

DartThrow t(int seat, int seg, int mul, {int round = 0, int turn = 0}) =>
    DartThrow(
      playerIndex: seat,
      segment: seg,
      multiplier: mul,
      points: seg * mul,
      scoreBefore: 0,
      turnNumber: 0,
      scoreAtStartOfTurn: 0,
      turnId: turn,
      roundNumber: round,
    );

void main() {
  test('duration formats as mm:ss, and past an hour as h:mm:ss', () {
    expect(matchSummaryFrom(durationSeconds: 1122).duration, '18:42');
    expect(matchSummaryFrom(durationSeconds: 59).duration, '0:59');
    expect(matchSummaryFrom(durationSeconds: 3725).duration, '1:02:05');
  });

  test('no duration renders an em dash rather than a zero clock', () {
    expect(matchSummaryFrom(durationSeconds: null).duration, '—');
  });

  test('suppressed throwHistory degrades every cell but duration', () {
    final s = matchSummaryFrom(durationSeconds: 600, throws: null);
    expect(s.degraded, isTrue);
    expect(s.duration, '10:00');
    expect(s.rounds, isNull);
    expect(s.bestTurn, isNull);
  });

  test('rounds, darts and the best turn come off the throw history', () {
    final throws = [
      t(0, 20, 3, round: 0, turn: 0), // 60
      t(0, 20, 1, round: 0, turn: 0), // 20  -> turn 0 = 80
      t(1, 5, 1, round: 0, turn: 1),
      t(0, 19, 3, round: 1, turn: 2), // 57
      t(0, 19, 3, round: 1, turn: 2), // 57  -> turn 2 = 114
    ];
    final s = matchSummaryFrom(
      durationSeconds: 60,
      throws: throws,
      playerNames: const ['Jonas', 'Mia'],
    );
    expect(s.degraded, isFalse);
    expect(s.rounds, '2');
    expect(s.darts, '5');
    expect(s.bestTurn, '114');
    expect(s.bestTurnBy, 'JONAS · R2');
  });

  test('hit distribution counts a bull as a bull, not as a double', () {
    final throws = [
      t(0, 20, 3),
      t(0, 20, 2),
      t(0, 25, 2), // double bull — a bull, counted once
      t(0, 0, 0),
    ];
    final s = matchSummaryFrom(
        durationSeconds: 1, throws: throws, playerNames: const ['A']);
    expect(s.hitDistribution, 'T 1 · D 1 · B 1 · ✗ 1');
  });

  test('biggest lead is the widest same-round gap between seats', () {
    final series = {
      0: <num>[0, 60, 140],
      1: <num>[0, 20, 45],
    };
    final s = matchSummaryFrom(
      durationSeconds: 1,
      throws: [t(0, 20, 1)],
      playerNames: const ['A', 'B'],
      seriesFor: (seat) => series[seat],
    );
    expect(s.biggestLead, '95');
  });

  test('no series means no lead, and the rest still render', () {
    final s = matchSummaryFrom(
      durationSeconds: 1,
      throws: [t(0, 20, 1)],
      playerNames: const ['A'],
    );
    expect(s.biggestLead, isNull);
    expect(s.darts, '1');
    expect(s.degraded, isFalse,
        reason: 'a missing series dims one cell, not the whole zone');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/match_summary_test.dart`
Expected: FAIL — the library does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/screens/post_game/match_summary.dart`. `degraded` is `throws == null || throws.isEmpty`. Null out every derived field in that case. Format duration with `Duration`'s components: `h:mm:ss` past an hour, `m:ss` otherwise, `—` when the seconds are null.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/match_summary_test.dart`
Expected: PASS — 7 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/post_game/match_summary.dart test/screens/match_summary_test.dart
git commit -m "feat(post-game): match summary derivation with a degraded state"
```

---

### Task 4: The four presentation widgets

**Files:**
- Create: `lib/widgets/dossedart/post_game/dossedart_winner_spotlight.dart`
- Create: `lib/widgets/dossedart/post_game/dossedart_placement_card.dart`
- Create: `lib/widgets/dossedart/post_game/dossedart_match_summary.dart`
- Create: `lib/widgets/dossedart/post_game/dossedart_post_game_actions.dart`
- Test: `test/widgets/post_game_widgets_test.dart` (create)

**Interfaces:**
- Consumes: `PostGameFields`/`StatField` (Task 2), `MatchSummary` (Task 3), `dossedartAccent`, `DossedartTokens`, `DossedartPlayerAvatar`.
- Produces: `DossedartWinnerSpotlight`, `DossedartPlacementCard`, `DossedartMatchSummary`, `DossedartPostGameActions`.

**Geometry — fasit, taken from the spec card:**

- **Winner spotlight, height 196, horizontal.** 104 px avatar with a 3 px yellow border and an 18 px glow, 👑 overhanging the top edge. `★ WINNER ★` PS-11 yellow, letter-spacing 4. Name PS 26/21/17/13 for length ≤8/≤12/≤16/longer, ellipsis not wrap. Headline repeated VT-19 beneath. Two right-hand plates (min width 150, padding 8/14): the mode headline in yellow, and ELO in green — or a dimmed em dash when the mode does not rate. Radial yellow wash at 24%/40%, ~12% opacity. No trophy emoji, no gradient card.
- **Placement card.** Fill `DossedartTokens.surface`, 2 px border in the player accent, padding 11/12/12. First place borders yellow with a 14 px glow. Header row 40 px: 38 px rank plate (gold/silver/bronze, else dim) · 40 px avatar · name PS 14/12/10/9 by the same length curve · headline label VT-15 · headline value **PS-20 in the player accent** · Elo column fixed 86 px. A tie adds a VT-15 `TIED` tag after the name.
- **Stat grid.** Three fixed columns, cell height 34, gap 6, 1 px magenta hairline, label VT-15 left, value PS-10 right. Rows = `ceil(fields / 3)`. A partial last row pads with empty dim tracks (border at ~10% opacity, no text) so every mode is a clean rectangle. `isZero` fields render at 0.34 opacity.
- **Match summary.** Three columns × two rows of label/value cells under the chart. Values in **lime**. BEST TURN carries a sub-line. A null cell dims to 0.32 with an em dash; BEST TURN's sub-line becomes `NOT RECORDED`. The section label gains `· partly unavailable` when degraded.
- **Actions, height 134, two rows.** Row 1: `↶ BACK` magenta, `▶ CONTINUE` cyan (flex 1.25), `▶ DETAILS` purple (flex 1.25). Row 2: `✓ FINISH GAME` full width, lime fill with background-coloured text and an 18 px glow. Unavailable buttons are **rendered and dimmed to 0.28, never removed**, so the primary action never moves.

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/post_game_widgets_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/screens/post_game/match_summary.dart';
import 'package:dart_scoring/screens/post_game/post_game_fields.dart';
import 'package:dart_scoring/widgets/dossedart/post_game/dossedart_match_summary.dart';
import 'package:dart_scoring/widgets/dossedart/post_game/dossedart_placement_card.dart';
import 'package:dart_scoring/widgets/dossedart/post_game/dossedart_post_game_actions.dart';

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
    // 4 fields => 2 rows => 6 slots => 2 empty trailing tracks.
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
    expect(find.byKey(const Key('statSlot')), findsNWidgets(6));
    expect(find.byKey(const Key('statSlotEmpty')), findsNWidgets(2));
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
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('an unavailable action is dimmed, never removed',
      (tester) async {
    await host(
      tester,
      DossedartPostGameActions(
        canUndo: true,
        canContinue: false,
        canShowDetails: false,
        onBack: () {},
        onContinue: () {},
        onDetails: () {},
        onFinish: () {},
      ),
    );
    expect(find.text('▶ CONTINUE'), findsOneWidget);
    expect(find.text('▶ DETAILS'), findsOneWidget);
    expect(find.text('✓ FINISH GAME'), findsOneWidget);
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
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/post_game_widgets_test.dart`
Expected: FAIL — the widget libraries do not exist.

- [ ] **Step 3: Write the implementation**

Build the four widgets to the geometry above. Give each stat slot `key: const Key('statSlot')` and empty trailing tracks an additional `Key('statSlotEmpty')` so the padding rule is testable. Keep every widget a pure `StatelessWidget` taking plain data — no service lookups, no `GameResult` — so they can be pumped in isolation.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widgets/post_game_widgets_test.dart && flutter analyze lib test`
Expected: PASS, no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/dossedart/post_game test/widgets/post_game_widgets_test.dart
git commit -m "feat(post-game): DOSSEDART spotlight, placement card, summary, actions"
```

---

### Task 5: Assemble the screen

**Files:**
- Modify: `lib/screens/post_game_screen.dart` (rewrite the build)
- Test: `test/screens/post_game_dossedart_test.dart` (create); update `test/screens/post_game_stats_test.dart`, `post_game_progression_test.dart`, `post_game_details_test.dart` as needed

**Interfaces:**
- Consumes: everything from Tasks 1-4.

**Context:** The structural fix is that **the action bar is a sibling of the scroll view, not its last item.** Today the whole screen is one `Column` with a single `Expanded` list and the buttons below, and the chart lives inside the list — which is why the buttons can be pushed off on a small frame. The new tree is:

```
DossedartCrtFrame
  Column
    DossedartTopBar            (52, pinned)
    DossedartWinnerSpotlight   (196, pinned)
    Expanded( SingleChildScrollView( Column(...) ) )   ← the only scroller
    DossedartPostGameActions   (134, pinned)
```

Scroll content order: roster-changed notice → `FINAL STANDINGS` (one `DossedartPlacementCard` per player) → `SCORECARD` + `GolfScoreGrid` (golf only) → `SCORE PER ROUND` + `ProgressionChart` → `MATCH SUMMARY`.

The existing ordering logic stays exactly as it is — `seats` sorted by placement with `withSeatTiebreak`, `sorted`, `winner = sorted.first`. Accents come from `dossedartAccent` indexed by **seat**, not by rank, so a player keeps one colour between the standings and the chart. Ties get the `TIED` tag when another result shares the placement.

BIGGEST LEAD needs a per-seat series: pass `seriesFor: (seat) => progression?.seriesFor(result.throwHistory!, playerIndex: seat)` into `matchSummaryFrom`, which is null exactly when the chart is absent.

- [ ] **Step 1: Write the failing test**

```dart
// test/screens/post_game_dossedart_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/game_result.dart';
import 'package:dart_scoring/screens/post_game_screen.dart';
import 'package:dart_scoring/widgets/dossedart/post_game/dossedart_placement_card.dart';
import 'package:dart_scoring/widgets/dossedart/post_game/dossedart_winner_spotlight.dart';

void main() {
  Future<void> pump(WidgetTester tester, GameResult r) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: PostGameScreen(result: r)));
    await tester.pumpAndSettle();
  }

  testWidgets('renders a spotlight, one card per player and the summary',
      (tester) async {
    await pump(
      tester,
      GameResult(
        gameMode: 'x01',
        durationSeconds: 1122,
        results: [
          PlayerResult(name: 'Jonas', placement: 1, stats: const {
            'avgTurn': 62.4,
            'highestTurn': 140,
            'darts': 24,
          }),
          PlayerResult(name: 'Mia', placement: 2, stats: const {
            'avgTurn': 41.8,
            'highestTurn': 100,
            'darts': 33,
          }),
        ],
      ),
    );

    expect(find.byType(DossedartWinnerSpotlight), findsOneWidget);
    expect(find.byType(DossedartPlacementCard), findsNWidgets(2));
    expect(find.text('★ WINNER ★'), findsOneWidget);
    expect(find.text('MATCH SUMMARY'), findsOneWidget);
    expect(find.text('18:42'), findsOneWidget);
  });

  testWidgets('the action bar survives a short frame — never pushed off',
      (tester) async {
    tester.view.physicalSize = const Size(820, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: PostGameScreen(
        result: GameResult(
          gameMode: 'gotcha',
          results: [
            for (var i = 0; i < 6; i++)
              PlayerResult(
                  name: 'P$i', placement: i + 1, stats: const {'score': 100}),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('✓ FINISH GAME'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/post_game_dossedart_test.dart`
Expected: FAIL — `DossedartWinnerSpotlight` is not in the tree.

- [ ] **Step 3: Write the implementation**

Rewrite `PostGameScreen.build` to the tree above. Keep `vsParText` and `golfTermDist` exported from this file — `golf_game_screen.dart` imports `golfTermDist`, and Task 2 imports `vsParText`. Delete `_PlayerResultTile` and its `_buildStats` switch; that logic now lives in `postGameFields`.

- [ ] **Step 4: Run the full suite**

Run: `flutter test`
Expected: PASS. The three existing post-game test files assert against the old Material tree (`Card`, joined stat strings such as `'Best: 140 | Darts: 24'`). Update each assertion to the new structure — a stat that was in the joined string is now its own `StatField` cell, so assert on the label and value separately. **Do not delete a test to make it pass**; if one no longer has a meaningful equivalent, say so in the commit message.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/post_game_screen.dart test/screens
git commit -m "feat(post-game): assemble the DOSSEDART result screen"
```

---

## Self-Review

**Spec coverage.** Zone budget → Task 5. Winner spotlight → Task 4. Standings + stat grid + the ordering rule → Tasks 2 and 4. Card-height derivation → falls out of `ceil(fields/3)`, no tuning. Match summary + degraded state → Tasks 1, 3, 4. Actions two-row layout with dimmed-not-removed → Task 4. Colour roles → Task 4 (tokens only, deviation 2 noted). Stress states: 6 players and the short frame → Task 5's second test; long names → the size curves in Task 4; tie → the `TIED` tag in Tasks 4 and 5; roster changed → notice + no chart + dimmed DETAILS + degraded summary, all in Task 5; Wildcard's fixed 86 px Elo column → Task 4. Reused verbatim → Task 5 places them untouched.

**Not covered, deliberately:** the `YOU` tag and PROPOSAL 1 (deviations 1 and 3); wave-2 counters (deviation 4).

**Type consistency.** `PostGameFields`/`StatField` keep one shape from Task 2 through Task 5. `MatchSummary`'s nullable fields are the single mechanism for both degraded states — whole-zone (no `throwHistory`) and single-cell (no series).

**Known risk.** Task 5 rewrites a screen three existing test files assert against, so that step carries the most churn. It is last on purpose: Tasks 1-4 are additive and independently green.
