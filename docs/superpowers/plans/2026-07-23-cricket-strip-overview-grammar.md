# Cricket / Strip-Family Overview Grammar (A+ w/SEGMENTS) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the shared `DossedartActiveStrip` to the approved family grammar (fixed 132px zone, identical in Cricket · ATC · Shanghai · Splitscore) and restyle Cricket's marks grid (per-player accents, live 👑 leader, DEAD tags, 3-segment marks meter inside the active tap cells).

**Architecture:** The strip becomes a fixed-height card composing the shared `DossedartOverviewHeader`, a generic `DossedartStripSlot` (mode data block) and a score block. All four strip-mode screens rewire to the new API with mode-specific slot content. Cricket's inline grid methods get the fasit restyle. No engine/rules changes.

**Tech Stack:** Flutter, flutter_test with `FontLoader` (px-accurate 132px pin).

**Fasit:** `docs/design/dossedart-handoff/cricket-strip-overview/design_handoff_cricket_strip_overview/` — `cricket-strip-overview-round.jsx` (`CricketStrip`/`StripHeader`/`LastTurnSlot`/`ScoreBlock` + `MarksGrid`/`HeadCell`/`ActiveCell` with `marksMode='seg'`, i.e. `CockpitAPlus`). `HANDOVER.md` + the brief's "Round outcome": diff plate DROPPED for Cricket (👑 in grid header carries the leader); CLOSES hint dropped (the meter implies it); sibling slot contents are illustrative — exact copy is implementation's call against real data.

## Global Constraints

- Colors: `DossedartTokens` only + white-with-alpha foregrounds; player accents via `dossedartAccent(index)`. No raw hex, no colorScheme, no borderRadius. Fonts 'PressStart2P'/'VT323'. English UI strings.
- **Family budget fasit: strip card `height: 110` inside margins `EdgeInsets.fromLTRB(14, 12, 14, 10)` = 132px zone — identical in all four strip modes, every state.** Empty content dims to 0.34, never collapses.
- Strip border/glow = active player's accent (identity; never state).
- `DART n/3` = dart being thrown (the shared header does this).
- Leader (Cricket grid): 👑 only on a UNIQUE points leader among non-removed players; **Cutthroat flips it — lowest points leads**; ties (incl. all-zero first round) → no crown.
- Removed players: excluded from leader math (and they are already excluded from the grid/strip by the screens' existing removed-handling — verify, don't regress).
- Branch: `feat/overview-grammar`. `flutter analyze` clean before every commit (exceptions only where a task explicitly stages a break for the next task).

---

### Task 1: Strip rewrite (family card) + DossedartStripSlot

**Files:**
- Modify: `lib/widgets/dossedart/dossedart_active_strip.dart` (full rewrite)
- Test: `test/widgets/dossedart/dossedart_active_strip_test.dart` (full rewrite — the old file asserts the old anatomy)

**Interfaces:**
- Consumes: `DossedartOverviewHeader` (`lib/widgets/dossedart/overview/dossedart_overview_header.dart`) — 56px avatar + name curve + pips + `DART n/3`.
- Produces:

```dart
/// Generic mode-data block for the family strip: label + big value + sub-line,
/// left hairline, fixed width so the strip never reflows between states.
class DossedartStripSlot extends StatelessWidget {
  const DossedartStripSlot({
    super.key,
    required this.label,      // e.g. 'LAST TURN', 'TARGET', 'ROUND 4'
    required this.value,      // big line, VT323 26
    required this.subLine,    // small line, VT323 14
    this.valueColor = DossedartTokens.yellow,
    this.subLineColor,        // default white-0.5
    this.dim = false,         // 0.34 opacity (rule 2 placeholder state)
    this.width = 212,
  });
  ...
}

class DossedartActiveStrip extends StatelessWidget {
  const DossedartActiveStrip({
    super.key,
    required this.playerName,
    required this.avatarPath,
    required this.accentColor,
    required this.dartsInTurn,   // 0..3
    required this.modeSlot,      // a DossedartStripSlot (or equivalent fixed-width widget)
    required this.scoreLabel,    // 'POINTS' / 'PROGRESS' / 'TOTAL' / 'TARGET'
    required this.scoreValue,
    this.smallScore = false,     // PS-22 instead of PS-30 (long values)
  });
  ...
}
```

Strip anatomy (fasit `CricketStrip`/`stripFrame`): outer `SizedBox(height: 132)` wrapping `Container(margin: fromLTRB(14,12,14,10), padding: symmetric(h:16, v:10), decoration: DossedartTokens.surface fill + 3px accentColor border + BoxShadow(accentColor 0.4, blur 14))` → `Row(crossAxisAlignment: center, children: [Expanded(DossedartOverviewHeader(...)), modeSlot, score block])`. Score block: left 1px white-0.12 hairline, paddingLeft 16, column right-aligned: label PS-7 white-0.45 letterSpacing 1 + value PS-30 (or 22) in accentColor w/ 12px glow, marginTop 5. The old gradient wash, `▶` name prefix, bottom border and `LAST · ` row are all GONE.

- [ ] **Step 1: Write the failing test** (full rewrite of the strip test file; real fonts — copy the `_loadRealFonts` helper verbatim from `test/widgets/dossedart/x01/dossedart_x01_active_card_test.dart`)

```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadRealFonts);

  Widget host(Widget strip) =>
      MaterialApp(home: Scaffold(body: Column(children: [strip])));

  DossedartActiveStrip strip({
    String name = 'Kari',
    Widget? slot,
    String scoreLabel = 'POINTS',
    String scoreValue = '58',
    bool smallScore = false,
  }) =>
      DossedartActiveStrip(
        playerName: name,
        avatarPath: null,
        accentColor: DossedartTokens.magenta,
        dartsInTurn: 1,
        modeSlot: slot ??
            const DossedartStripSlot(
                label: 'LAST TURN',
                value: 'T18 · 18 · ✗',
                subLine: '= 4 MARKS'),
        scoreLabel: scoreLabel,
        scoreValue: scoreValue,
        smallScore: smallScore,
      );

  testWidgets('132px family zone in every state (fasit pin)', (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final states = <String, DossedartActiveStrip>{
      'cricket last-turn': strip(),
      'first dart (dimmed placeholder)': strip(
          slot: const DossedartStripSlot(
              label: 'LAST TURN',
              value: '— · — · —',
              subLine: 'NO DARTS YET',
              dim: true)),
      'long name': strip(name: 'Alexander the boss bitch'),
      'small score (splitscore label)': strip(
          slot: const DossedartStripSlot(
              label: 'TARGET', value: 'D19', subLine: 'MISS HALVES 240 › 120'),
          scoreLabel: 'POINTS',
          scoreValue: '240',
          smallScore: true),
    };
    for (final e in states.entries) {
      await tester.pumpWidget(host(e.value));
      expect(tester.getSize(find.byType(DossedartActiveStrip)).height, 132.0,
          reason: 'strip zone in "${e.key}"');
    }
  });

  testWidgets('renders header, slot content and score block', (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(strip()));
    expect(find.text('Kari'), findsOneWidget);
    expect(find.text('DART 2/3'), findsOneWidget); // 1 thrown → on dart 2
    expect(find.text('LAST TURN'), findsOneWidget);
    expect(find.text('T18 · 18 · ✗'), findsOneWidget);
    expect(find.text('= 4 MARKS'), findsOneWidget);
    expect(find.text('POINTS'), findsOneWidget);
    expect(find.text('58'), findsOneWidget);
  });

  testWidgets('dimmed slot renders at 0.34 opacity', (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(strip(
        slot: const DossedartStripSlot(
            label: 'LAST TURN',
            value: '— · — · —',
            subLine: 'NO DARTS YET',
            dim: true))));
    final opacity = tester.widget<Opacity>(find.ancestor(
        of: find.text('NO DARTS YET'), matching: find.byType(Opacity)).first);
    expect(opacity.opacity, 0.34);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/dossedart/dossedart_active_strip_test.dart`
Expected: FAIL — new API doesn't exist.

- [ ] **Step 3: Rewrite the strip** per the Interfaces/anatomy block. `DossedartStripSlot` body:

```dart
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
              color: Colors.white.withValues(alpha: 0.12), width: 1),
        ),
      ),
      child: Opacity(
        opacity: dim ? 0.34 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 7,
                    color: Colors.white.withValues(alpha: 0.45),
                    letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'VT323',
                    fontSize: 26,
                    height: 1,
                    letterSpacing: 1.5,
                    color: valueColor,
                    shadows: dim
                        ? null
                        : [Shadow(color: valueColor.withValues(alpha: 0.33), blurRadius: 8)])),
            const SizedBox(height: 3),
            Text(subLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'VT323',
                    fontSize: 14,
                    height: 1,
                    letterSpacing: 1,
                    color: subLineColor ?? Colors.white.withValues(alpha: 0.5))),
          ],
        ),
      ),
    );
  }
```

The strip build: `SizedBox(height: 132, child: Container(<frame per anatomy>, child: Row([Expanded(DossedartOverviewHeader(playerName, avatarPath, accent: accentColor, dartsThrown: dartsInTurn)), const SizedBox(width: 14), modeSlot, <score block per anatomy>])))`.

- [ ] **Step 4: Run tests; expected analyze state**

Run: `flutter test test/widgets/dossedart/dossedart_active_strip_test.dart`
Expected: PASS. Project-wide `flutter analyze` will now error at the FOUR old call sites (cricket/atc/shanghai/halve_it screens) — acceptable for THIS task only; confirm those are the ONLY issues. `test/screens/strip_turn_label_test.dart` will also fail to compile (reads the removed `lastThrowLabel` field) — do NOT fix it here; Task 3 owns it. State both facts in your report.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/dossedart/dossedart_active_strip.dart test/widgets/dossedart/dossedart_active_strip_test.dart
git commit -m "feat(dossedart): family strip rewrite - fixed 132px zone, grammar header, mode slot + score block"
```

---

### Task 2: Wire Cricket's strip + grid restyle (A+ w/SEGMENTS)

**Files:**
- Modify: `lib/screens/cricket_game_screen.dart` — the strip call (~:726), `_dossedartMatrix`/`_dossedartMatrixHeader`/`_dossedartPlayerHeader` (~:771-867), `_dossedartMatrixRow` (~:869-913), `_dossedartActiveCell` (~:915-991), `_dossedartGlyph` (~:1006)
- Test: `test/screens/cricket_dossedart_grid_test.dart` (new)

**Interfaces:**
- Consumes: new strip API (Task 1), `dossedartAccent(i)`, engine getters already in the file: `marks`, `scores`, `targets`, `engine.isClosed(t, i)`, `engine.isClosedByAll(t)`, `widget.config.isCutthroat`, `dartsInTurn`, `_stripTurnLabel` (keep — it is Cricket's mode-slot content), plus the screen's existing removed-player tracking (grep how `_dossedartMatrix` and turn order already skip removed players — mirror it, don't invent a new mechanism).
- Produces: `int? get _dossedartLeaderIndex` — index of the UNIQUE best score among non-removed players (`isCutthroat` → lowest wins, else highest); null on any tie.

Strip call becomes:

```dart
              DossedartActiveStrip(
                playerName: players[currentPlayerIndex].name,
                avatarPath: players[currentPlayerIndex].avatarPath,
                accentColor: dossedartAccent(currentPlayerIndex),
                dartsInTurn: dartsInTurn,
                modeSlot: DossedartStripSlot(
                  label: 'LAST TURN',
                  value: _stripTurnLabel ?? '— · — · —',
                  subLine: _stripTurnLabel != null
                      ? '= $_lastTurnMarks MARKS'
                      : 'NO DARTS YET',
                  dim: _stripTurnLabel == null,
                ),
                scoreLabel: 'POINTS',
                scoreValue: '${scores[currentPlayerIndex]}',
              ),
```

`_lastTurnMarks`: derive from the same data `_stripTurnLabel` is built from (count of marks scored by the darts in that label's turn — read `_stripTurnLabel`'s implementation first and add a sibling getter computing the turn's total marks; if the underlying data only carries labels, count marks from the same throw records). If `_stripTurnLabel` has a different null/empty convention (e.g. empty string), adapt the null-checks to it.

Grid restyle (fasit `MarksGrid` with `marksMode='seg'`, `bigPts`):
1. **Header cells** (`_dossedartPlayerHeader`): per player — 26px `DossedartPlayerAvatar` (border in `dossedartAccent(pi)`) + handle/short name PS-8 (active: white, others white-0.75) + 👑 (10px) when `pi == _dossedartLeaderIndex` + points PS-17 in `dossedartAccent(pi)` w/ 9px glow. Active column: accent bg 0.08 + 3px accent top line. Keep the existing active/opponent flex ratio (27:10 ≈ fasit's 2.6fr:1fr).
2. **Opponent glyphs** (`_dossedartGlyphCell`/`_dossedartGlyph`): color = `dossedartAccent(pi)` (today uniform) — `·` for 0 stays white-0.18; `/`,`X` PS-20 (6 players) / PS-24, `⊗` +2px, 9px glow.
3. **Target column**: label PS-19 yellow w/ glow (BULL PS-11); when `engine.isClosedByAll(target)`: row opacity 0.3 + `DEAD` VT-11 white-0.45 under the target label (replaces nothing — added line, the row is already dimmed today).
4. **Active cell** (`_dossedartActiveCell`): keep the tap wiring (`_registerHit(target, mult)`) and the BULL/D-BULL sub-cell structure EXACTLY as-is; restyle: cell bg `accent 0.06`; sub-cell separators 1px dashed → keep current separator style if not dashed-capable, 1px `accent 0.33` solid is the approved fallback; sub-labels PS-14 (PS-11 when >3 chars) in accent w/ glow. ADD the **3-segment marks meter** pinned to the cell bottom (own marks 0-2): `Positioned(bottom: 5, left: 5, right: 5)` row of 3 `Expanded` segments (height 10, gap 3): filled (i < own) = accent fill + 2px accent border + 8px glow; empty = black-0.4 fill + 2px accent-0.4 border. `IgnorePointer` around the meter so taps pass through. When own >= 3 (closed): NO sub-cells, big `⊗` PS-26 accent 0.85 centered (today's closed behavior restyled). The old 30px own-marks glyph column inside the active cell is REMOVED (the meter replaces it). NO 'CLOSES' hint (dropped by fasit).
5. Remove the strip's old `trailing` POINTS column import leftovers; `flutter analyze` must be clean for this file.

- [ ] **Step 1: Write the failing test** (`test/screens/cricket_dossedart_grid_test.dart`) — pump the DOSSEDART cricket screen (mirror the pump-pattern from an existing dossedart screen test, e.g. `test/screens/one_up_game_screen_test.dart` or the removed-player standings test from the X01 round; `SharedPreferences.setMockInitialValues({})` and the usual test seams apply):

```dart
  // 3 players, standard cricket. Register hits via the screen's public tap
  // targets (tap 'T20' twice → 6 marks? no: T20 = 3 marks = closed) — drive
  // state through taps, not engine internals.

  testWidgets('leader crown: unique highest points, none on tie',
      (tester) async {
    // All players 0 points at game start → no crown anywhere.
    // Then: active player closes 20 (tap T20) and scores extra 20s (tap 20)
    // → they alone have points → exactly one 👑 next to their header.
  });

  testWidgets('cutthroat flips the crown to lowest points', (tester) async {
    // Cutthroat game: player who takes points (points pushed ONTO others)
    // leaves the OTHERS with points; the player with 0 = lowest = leader.
  });

  testWidgets('segments meter mirrors own marks in the active cell',
      (tester) async {
    // Tap '19' once → active cell for 19 shows 1 filled + 2 empty segments.
    // Assert via widget keys: give the meter segments ValueKey('seg-19-0')
    // etc. in the implementation, keyed per target+index, filled state
    // asserted by decoration color.
  });

  testWidgets('closed-by-all row shows DEAD tag', (tester) async {
    // Close 20 for every player (rotate turns, tap T20 for each) →
    // find.text('DEAD') appears once; row is present, not collapsed.
  });
```

Write these four tests out fully — the comments above are the scenarios; the assertions must be real (`find.text('👑')` counts, ValueKey lookups with `tester.widget<Container>` decoration checks, `find.text('DEAD')`). Give meter segments `ValueKey('seg-$target-$i')` in the implementation to make them addressable.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/cricket_dossedart_grid_test.dart`
Expected: FAIL (old grid has no crown/meter/DEAD).

- [ ] **Step 3: Implement** the strip call + grid restyle per the Interfaces block.

- [ ] **Step 4: Run tests**

Run: `flutter test test/screens/cricket_dossedart_grid_test.dart test/screens/ && flutter analyze`
Expected: new tests PASS; cricket's other screen tests still green. Analyze: only the ATC/Shanghai/Halve-It strip call sites + `strip_turn_label_test.dart` remain broken (Task 3).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/cricket_game_screen.dart test/screens/cricket_dossedart_grid_test.dart
git commit -m "feat(cricket): A+ grid - player accents, live crown, DEAD tags, segments meter + family strip wiring"
```

---

### Task 3: Wire ATC, Shanghai, Splitscore strips

**Files:**
- Modify: `lib/screens/around_the_clock_game_screen.dart` (~:1175), `lib/screens/shanghai_game_screen.dart` (~:763), `lib/screens/halve_it_game_screen.dart` (~:706)
- Modify: `test/screens/strip_turn_label_test.dart`

**Interfaces:**
- Consumes: new strip API + `DossedartStripSlot`, `dossedartAccent`.
- Slot/score content per mode (adapted from the fasit thumbnails to real data — this is the implementation-owned copy):

**ATC** (`currentTargets[currentPlayerIndex]` is the current target; the sequence comes from the screen's target-progression — read how the next targets are derived, there is an ordered list/progression the screen already walks):

```dart
                modeSlot: DossedartStripSlot(
                  label: 'TARGET',
                  value: _atcTargetLabel(currentTargets[currentPlayerIndex]), // '7' / 'BULL'
                  subLine: _atcThenLine(), // 'THEN 8 › 9 › 10' or 'THEN —' at the end
                ),
                scoreLabel: 'PROGRESS',
                scoreValue: '${_atcHitCount(currentPlayerIndex)}/${_atcTotalTargets()}',
                smallScore: true,
```

Add the small private helpers next to the build method; `_atcThenLine` shows the next up-to-3 targets joined with ' › ', `'THEN —'` when none remain (dim NOT needed — always rendered).

**Shanghai** (`engine.round`/target and totals — the screen already shows `RND n/targetEnd` in the TopBar and `engine.totalScores[...]`; the round's target number is the round number in Shanghai):

```dart
                modeSlot: DossedartStripSlot(
                  label: 'ROUND ${engine.currentRound}',           // adapt to the engine's actual round getter
                  value: 'TARGET ${engine.currentRound}',
                  subLine:
                      'S${engine.currentRound} · D${engine.currentRound * 2} · T${engine.currentRound * 3}',
                ),
                scoreLabel: 'TOTAL',
                scoreValue: '${engine.totalScores[engine.currentPlayerIndex]}',
```

(Grep the engine for the round getter the old TopBar `RND` string uses and reuse it verbatim.)

**Splitscore** (`rounds[currentRoundIndex].label` is the target label; `scores`/totals exist — grep the screen for the current player's score used by the classic scoreboard):

```dart
                modeSlot: DossedartStripSlot(
                  label: 'TARGET',
                  value: rounds[currentRoundIndex].label.toUpperCase(),
                  subLine:
                      'MISS HALVES ${_currentScore()} › ${(_currentScore() / 2).ceil()}',
                  subLineColor: DossedartTokens.red,
                ),
                scoreLabel: 'POINTS',
                scoreValue: '${_currentScore()}',
                smallScore: true,
```

(`_currentScore()` = the active player's current total, whatever the screen already calls it; the halving rule in this app — check the engine for whether halving rounds up or down (`~/ 2` vs `(x/2).ceil()`) and use the SAME function so the preview never lies.)

- `test/screens/strip_turn_label_test.dart`: the strip no longer renders last-throw text for these three modes (design-approved — the mode slot replaced it). The `_stripTurnLabel`-style getters may still feed game logs; do NOT delete the getters if referenced elsewhere. Rewrite the test file to assert the NEW slot content per mode (ATC: TARGET + THEN-line; Shanghai: ROUND/TARGET; Splitscore: TARGET + MISS HALVES) — same pump helpers, new finds. If a getter becomes truly unreferenced, delete it and say so in the report.

- [ ] **Step 1: Rewire the three screens** per above (adapting getter names to reality — each screen's build method already computes/holds the needed data nearby).

- [ ] **Step 2: Rewrite strip_turn_label_test.dart** to the new assertions (keep its pump helpers).

- [ ] **Step 3: Full verification**

Run: `flutter analyze && flutter test`
Expected: analyze fully clean (all four call sites + tests fixed); full suite green.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/around_the_clock_game_screen.dart lib/screens/shanghai_game_screen.dart lib/screens/halve_it_game_screen.dart test/screens/strip_turn_label_test.dart
git commit -m "feat(strip-family): wire ATC/Shanghai/Splitscore to the family strip (mode slots + score blocks)"
```

---

### Task 4: Verification pass

- [ ] **Step 1:** `flutter analyze && flutter test` — clean + green (full suite).
- [ ] **Step 2:** Confirm the 132px pin: `flutter test test/widgets/dossedart/dossedart_active_strip_test.dart` (the four-state pin) and grep the four screens to confirm none wraps the strip in anything height-modifying.
- [ ] **Step 3:** Commit any fixups as `fix(strip-family): <what>`. Tablet-QA of all four modes stays with Bjørn.
