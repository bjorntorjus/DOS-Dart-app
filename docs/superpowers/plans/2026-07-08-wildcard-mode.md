# WILDCARD Game Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the WILDCARD chaos game mode (DOSSEDART-only v1): a points race over N rounds sabotaged by a chaos meter (0–10) driving turn-modifiers, hidden jokers, and instant events — with a seeded-RNG pure engine, 11 cockpit states, live board dimming, and no Elo.

**Architecture:** Data-driven event/modifier definitions (`wildcard_events.dart`) consumed by a pure `WildcardEngine` (snapshot undo, injected `math.Random`); thin game screen reusing the X01/Gotcha cockpit chrome with three new widget files (chaos meter, scorecard, moment dialogs); dartboard gains an optional dim predicate. Shanghai/Gotcha deferred-stats + post-game-undo protocol, minus Elo.

**Tech Stack:** Flutter, no new packages. Fonts `PressStart2P`/`VT323`.

## Global Constraints

- **Branch:** `feat/wildcard`, based on `feat/gotcha` (stacked — reuses Gotcha's home grid + cockpit patterns).
- **DOSSEDART-only v1** (same decision as Gotcha): no classic tile; classic `player_setup_screen.dart` gets compile-required cases only.
- **Colors:** `DossedartTokens` only. The design's PURPLE `#B15CFF` — check `DossedartTokens.purple` (`#7B3FFF`) first: use the EXISTING token, do not add a new hex. All other design hexes map to existing tokens. Board painter file is palette-exempt (CLAUDE.md) — dim colors go there as module constants.
- **All UI strings English** (guard test). Terminology LOCKED: `CHAOS METER`, `THE WINDOW`, `WINDOW PRIZE`, `HOLY TRINITY`, `joker`, `CUT!`, `REWIND`.
- **Design fasit:** `docs/design/dossedart-handoff/wildcard/` (README + `wildcard-cockpit.jsx`). Rules fasit (wins over artboards): `docs/superpowers/specs/2026-07-07-wildcard-design.md`.
- **No Elo** (spec §9 flagged decision): no `EloService` call, no rating preview, `recordGame` without `ratingsBefore/After`; H2H IS recorded (recordGame does it internally).
- **Seeded RNG:** engine takes `math.Random` in the constructor; NEVER `Random()` inside the engine. Every engine test constructs `Random(<fixed seed>)`.
- **Score floor 0** everywhere (steals/curses clamp). **Meter clamps 0–10.**
- Mode key `'wildcard'`, label `'WILDCARD'`, emoji 🃏. Config: rounds 5/10/15 default 10; starting chaos Mild=2 / Spicy=5 / Total chaos=8 default 5. Min players 2.
- Board: reuse `DossedartX01Dartboard` at full size — only ADDITION is the optional dim predicate; X01/Gotcha/Killer call sites unchanged.
- A dimmed-segment hit scores 0 but is fully alive: jokers + cursed numbers trigger, bull dialog appears, and it is NOT a meter-miss. Only the MISS button / off-board tap is a true miss (meter −1).
- Sounds: `assets/sounds/wildcard/` NOT declared in pubspec (no assets yet); TTS is the backbone (announce modifiers, joker, window prize, CUT!, REWIND, winner).
- Tests: screen tests copy the Gotcha/Shanghai harness (channel stubs, `pump()` + Durations, never `pumpAndSettle`). Engine tests are pure Dart.
- Commit after every green task.

## Locked rule interpretations (spec ambiguities resolved — implementers follow these)

1. **BLACK/WHITE segments:** black = the dark-felt set `{20,18,13,10,2,3,7,8,14,12}` (painter's `i % 2 == 0` indices of `kSegmentOrder`); white = the other ten. Bull counts as scoring for BOTH (it is neither felt).
2. **Half-board sets** (by segment center angle, 20 = 0° north, clockwise): UPPER = `{20,1,18,4,13}` ∪ `{5,12,9,14}` (centers in (270°,90°) exclusive) = 9 segments; LOWER = `{10,15,2,17,3,19,7,16,8}` (centers in (90°,270°) exclusive) = 9; boundary segments 6 (east, 90°) and 11 (west, 270°) belong to neither UPPER nor LOWER. RIGHT = `{1,18,4,13,6,10,15,2,17}`; LEFT = `{3,19,7,16,8,11,14,9,12}`; boundary 20 (north) and 3-opposite... boundary segments for L/R are 20 (north) and 5? — NO: recompute from `kSegmentOrder` = [20,1,18,4,13,6,10,15,2,17,3,19,7,16,8,11,14,9,12,5], center of index i = i·18°. RIGHT = indices 1–9 = `{1,18,4,13,6,10,15,2,17}`; LEFT = indices 11–19 = `{19,7,16,8,11,14,9,12,5}`; boundaries: index 0 (20, north) and index 10 (3, south) are in neither. UPPER = indices 16–19 ∪ 0–4 = `{14,9,12,5,20,1,18,4,13}`; LOWER = indices 6–14 = `{10,15,2,17,3,19,7,16,8}`; boundaries: index 5 (6, east) and index 15 (11, west) in neither. **Bull scores under all four half-modifiers.** Encode these as `const Set<int>` with this comment.
3. **DOUBLE TROUBLE:** a double-ring hit scores `segment × 3`; a triple-ring hit scores 0. D-Bull (25×2) is a double → scores 25×3=75; single bull unaffected (25).
4. **EVERYTHING ×2:** doubles the TURN TOTAL at turn end (not per dart display; the turn counter shows raw darts, the doubling applies when the turn is banked — sub-line explains it).
5. **GOLDEN DART:** the 3rd dart of the turn scores ×3 (applied per-dart at entry).
6. **BULL'S FORTUNE / CURSE:** ANY bull hit (25 or D-Bull) scores flat +100 / −100 for the turn total (floor 0 applies at banking). The chaos ±choice STILL happens (spec §10).
7. **HOLY TRINITY:** turn total exactly 26 at turn end → +100 bonus (any combination, not just 20-5-1).
8. **THE WINDOW:** on activation, bounds drawn from three shapes — low `[a, a+6]` with a ∈ 3..9, mid `[a, a+20]` with a ∈ 40..60, high `[a, a+40]` with a ∈ 80..120; chaos ≥7 weights low:mid:high = 3:2:1, else 1:2:2. All 3 darts must hit the board (dimming never applies during a window; a true miss voids the turn → 0, meter −1 still applies). Total inside bounds (inclusive) → turn banks flat 100 (`WINDOW PRIZE`); outside → 0.
9. **ROBIN HOOD:** steals 50 (capped at victim's total) from the highest-total player OTHER than the joker-hitter, credited to the joker-hitter. Tie for leader → the earliest seat index among tied.
10. **GIFT:** the CURRENT dart's points and the REMAINING darts of this turn credit the player in last place (lowest total among others; tie → earliest seat) instead of the thrower.
11. **FREEZE:** the current leader (highest total, tie → earliest seat, hitter included) is frozen for their NEXT turn: all darts score 0 points; meter effects and joker/bull triggers still fire. Flag dissolves after that turn or if the player is removed.
12. **CURSED NUMBER:** a new hidden number (1–20, ≠ active jokers, ≠ current cursed) scores NEGATIVE (−segment×multiplier) when hit, applied to the thrower's turn, until someone hits it (then it clears) or game end. Hitting it also clears it.
13. **SCORE SWAP:** joker-hitter swaps GAME totals with one uniformly-random OTHER living player.
14. **CUT!:** current round ends immediately — current thrower's turn banks as-is, players after them this round lose their turn; next round starts. CUT! in the final round → game ends.
15. **REWIND:** every player's this-round banked points are subtracted (engine tracks `roundStartTotals`, restored on rewind); the in-progress turn is discarded; round restarts from the round's first seat. Jokers/cursed stay as they were at round start? — NO: keep current jokers/cursed (simpler, chaos-flavored); only SCORES rewind.
16. **Modifier roll:** at turn start, per the §3 frequency table; a frozen player still gets no modifier (pointless); THE WINDOW never rolls while the thrower is frozen. Announcement overlay shows before the first dart.
17. **Bull dart order of operations:** dart scores (incl. FORTUNE/CURSE transform) → joker check (bull is never a joker; jokers are 1–20) → `needsBullChoice` returned; the screen shows the dialog; `resolveBullChoice(delta)` applies meter change under the SAME undo entry as the dart.
18. **Winner announce/tiebreak (spec §2):** highest total; tie → highest single banked turn in the game (engine tracks per-player `highestTurn`); still tied → shared placement.
19. **Chaos-0 baseline:** at level 0, zero modifiers, zero jokers, no events, meter can still move (triple +1 raises it FROM 0 — level 0 is not sticky). "Deterministic baseline" = a chaos-0 START with no triples/bulls stays a plain race.
20. **Per-player accents:** new util `dossedartAccent(int index)` cycling `[cyan, magenta, green, purple, orange]` from `DossedartTokens` (yellow reserved for leader/labels, red for danger). The design README's "use player_colors palette" is overridden by the tokens-only rule — the JSX's own placeholder accents ARE these tokens.
21. **Overlay interactions:** bull dialog blocks until a choice; all other dialogs (announce/joker/event/cut/rewind) are tap-anywhere-to-continue; winner dialog leads to the post-game flow (tap → PostGameScreen). Board input is blocked while any overlay is up.

## File Structure

```
lib/models/wildcard_events.dart        — ModifierDef / InstantEventDef + all definitions, segment sets, window gen, chaos tables (pure)
lib/models/wildcard_engine.dart        — WildcardEngine + WildcardDartResult + snapshot undo (pure)
lib/utils/dossedart_player_accents.dart — dossedartAccent(index)
lib/widgets/dossedart/wildcard/dossedart_chaos_meter.dart
lib/widgets/dossedart/wildcard/dossedart_wildcard_scorecard.dart   — scorecard + _DartSlots + _ThrowDirective + _Standings
lib/widgets/dossedart/wildcard/dossedart_wildcard_dialogs.dart     — WildcardOverlay + WildcardDialog + BullChoiceDialog
lib/screens/wildcard_game_screen.dart
lib/screens/dossedart/dossedart_wildcard_setup_screen.dart
(modified) lib/widgets/dossedart/x01/dossedart_x01_dartboard.dart  — optional isDim predicate
(modified) game_mode.dart, game_config.dart, player_setup_screen.dart, dossedart_home_screen.dart,
           post_game_screen.dart, stats_screen.dart, dossedart_stats_screen.dart, game_detail_screen.dart,
           lib/stats/profile_stats.dart
```

---

### Task 0: Branch

- [ ] **Step 1:** `git checkout feat/gotcha && git checkout -b feat/wildcard`.
- [ ] **Step 2:** `flutter analyze` clean; `flutter test test/` all green (baseline 460).

---

### Task 1: Event & modifier definitions (`wildcard_events.dart`)

**Files:**
- Create: `lib/models/wildcard_events.dart`
- Test: `test/models/wildcard_events_test.dart`

**Interfaces (produces — binding for Tasks 2–4 and the widgets):**

```dart
enum WcSeverity { mild, medium, wild }

/// A per-turn personal modifier (spec §4).
class WcModifierDef {
  final String id;          // 'onlyEvens', 'window', 'holyTrinity', ...
  final String name;        // 'ONLY EVENS' — UI headline, locked terminology
  final String icon;        // emoji glyph
  final String desc;        // directive sub-line, e.g. 'Only even numbers score this turn'
  final WcSeverity severity;
  /// Segments that do NOT score under this modifier (null = no restriction).
  /// Also drives board dimming. Bull is handled by [bullScores].
  final bool Function(int segment)? dims;
  final bool bullScores;    // false only for pure restriction modifiers where bull is excluded (always true per locked rules)
  const WcModifierDef({...});
}

/// An instant event fired by a joker (spec §5).
class WcInstantEventDef {
  final String id;          // 'chaosSurge', 'robinHood', ...
  final String name;        // 'ROBIN HOOD'
  final String icon;
  final WcSeverity severity;
  const WcInstantEventDef({...});
}

// All definitions, exact ids:
const wcModifiers = <WcModifierDef>[ onlyEvens, onlyOdds, onlyBlack, onlyWhite,
  divideByThree, upperHalf, lowerHalf, leftHalf, rightHalf,
  everythingX2, goldenDart, holyTrinity, bullsFortune, bullsCurse,
  doubleTrouble, theWindow ];
const wcInstantEvents = <WcInstantEventDef>[ chaosSurge, scoreSwap, robinHood,
  gift, freeze, cursedNumber, doubleJeopardy, cutEvent, rewindEvent ];

// Segment sets (locked interpretation #1/#2, with the index-derivation comment):
const Set<int> wcBlackSegments;  // {20,18,13,10,2,3,7,8,14,12}
const Set<int> wcUpperHalf;      // {14,9,12,5,20,1,18,4,13}
const Set<int> wcLowerHalf;      // {10,15,2,17,3,19,7,16,8}
const Set<int> wcRightHalf;      // {1,18,4,13,6,10,15,2,17}
const Set<int> wcLeftHalf;       // {19,7,16,8,11,14,9,12,5}

/// §3 chaos tables. modifierChancePct(level): 0,10,10,25,25,45,45,70,70,100,100.
int wcModifierChancePct(int level);
/// jokers on board: 0→0, 1–6→1, 7–8→ (rng-independent base 1; doubleJeopardy adds), 9–10→2.
int wcJokerCount(int level);
/// severity pool: 0→[], 1–4→[mild], 5–6→[mild,medium], 7–8→all, 9–10→all (wild ×2 weight).
List<WcSeverity> wcSeverityPool(int level);
/// THE WINDOW bounds (locked rule #8). Uses [rng].
({int lo, int hi}) wcRollWindow(math.Random rng, int chaosLevel);
/// meter heat color name per level for widgets: returns a DossedartTokens color.
Color wcChaosColor(int level);   // 1–2 cyan · 3–4 green · 5–6 yellow · 7–8 orange · 9–10 red (0 → cyan)
String wcChaosLabel(int level);  // DORMANT/MILD/BUBBLING/SPICY/WILD/TOTAL CHAOS
```

- [ ] **Step 1: Failing tests** — one test per definition + tables (all pure, no RNG except window):

```dart
test('segment sets are disjoint halves per locked interpretation', () {
  expect(wcUpperHalf.intersection(wcLowerHalf), isEmpty);
  expect(wcUpperHalf.length, 9); expect(wcLowerHalf.length, 9);
  expect(wcUpperHalf.contains(6), isFalse);  // east boundary in neither
  expect(wcLowerHalf.contains(11), isFalse); // west boundary in neither
  expect(wcRightHalf.contains(20), isFalse); // north boundary in neither L/R
  expect(wcBlackSegments.length, 10);
});
test('onlyEvens dims odd segments', () {
  expect(wcModifiers.firstWhere((m) => m.id == 'onlyEvens').dims!(7), isTrue);
  expect(wcModifiers.firstWhere((m) => m.id == 'onlyEvens').dims!(8), isFalse);
});
test('divideByThree dims non-multiples', () { /* 9,12,15,18,3,6 score; 20 dims */ });
test('modifier chance table matches spec §3', () {
  expect([for (var l = 0; l <= 10; l++) wcModifierChancePct(l)],
      [0,10,10,25,25,45,45,70,70,100,100]);
});
test('severity pools per level', () {
  expect(wcSeverityPool(0), isEmpty);
  expect(wcSeverityPool(3), [WcSeverity.mild]);
  expect(wcSeverityPool(6), containsAll([WcSeverity.mild, WcSeverity.medium]));
  expect(wcSeverityPool(9).where((s) => s == WcSeverity.wild).length, 2); // wild weighted up
});
test('window bounds: low shape spans 6, within 3..15', () {
  final rng = math.Random(42);
  for (var i = 0; i < 200; i++) {
    final w = wcRollWindow(rng, 8);
    expect(w.hi - w.lo, isIn([6, 20, 40]));
    expect(w.lo, greaterThanOrEqualTo(3));
  }
});
test('chaos color + label bands', () {
  expect(wcChaosColor(2), DossedartTokens.cyan);
  expect(wcChaosColor(10), DossedartTokens.red);
  expect(wcChaosLabel(0), 'DORMANT'); expect(wcChaosLabel(10), 'TOTAL CHAOS');
});
```

- [ ] **Step 2:** FAIL (file missing). **Step 3:** Implement — plain const data + pure functions, doc comments citing spec §3–§5 and the locked-interpretation numbers. **Step 4:** PASS + analyze clean.
- [ ] **Step 5:** Commit `feat(wildcard): data-driven modifier/event definitions, chaos tables, segment sets`

---

### Task 2: WildcardEngine core — points race, meter, snapshot undo

**Files:**
- Create: `lib/models/wildcard_engine.dart`
- Test: `test/models/wildcard_engine_test.dart`

**Interfaces (produces):**

```dart
class WildcardDartResult {
  final int points;              // effective points credited THIS dart (after modifier/curse/freeze; may be negative pre-floor)
  final int meterDelta;          // applied (post-clamp) meter movement from this dart
  final int? jokerHit;           // revealed joker number, or null
  final WcInstantEventDef? instantEvent;  // event fired by the joker (resolution details on engine fields)
  final bool needsBullChoice;    // true → screen must call resolveBullChoice(±1|±3)
  final int bullChoiceMagnitude; // 1 or 3 when needsBullChoice
  final bool turnEnded;
  final bool roundEnded;
  final bool gameOver;
}

class WildcardEngine {
  WildcardEngine({required int playerCount, required this.rounds,
      required int startingChaos, required math.Random rng});
  final int rounds;
  int chaos;                       // 0–10, clamped
  int round;                       // 1-based
  int currentPlayerIndex; int dartsInTurn;
  late List<int> totals;
  List<String> turnDartLabels;     // display values for the 3 slots ('T19','20','DBL','—')
  int turnPoints;                  // running effective turn total (pre-banking transforms)
  WcModifierDef? activeModifier;   // null = open throw
  ({int lo, int hi})? window;      // non-null only while activeModifier.id == 'window'
  Set<int> jokers;                 // hidden numbers (test-visible)
  int? cursedNumber;
  int? frozenPlayer;               // scores 0 on their next turn
  int chaosPeak;                   // max level reached (stats)
  late List<int> highestTurn;      // best banked turn per player (tiebreak + stats)
  late List<int> jokersHitCount, windowPrizes, pointsStolen;  // stats
  bool gameOver; int? winnerIndex;
  bool get canUndo; bool isSkipped(int i); int get activePlayerCount;
  bool Function(int segment)? get dimPredicate; // from activeModifier.dims; null during window/open
  /// Ranked indices: totals desc, tiebreak highestTurn desc, then seat; excludes skipped.
  List<int> ranking();
  WildcardDartResult applyDart(int segment, int multiplier);  // segment 0 = TRUE miss (button/off-board)
  void resolveBullChoice(int signedDelta);   // ±1 or ±3; same undo entry as the bull dart
  void undo(); void clearUndoStack();
  void addPlayer({int initialScore = 0});    // joins at 0 per spec §7.2
  void removePlayer(int index);
  /// Dev/QA override: force the next turn-modifier roll / next joker event (spec §8).
  void debugForceModifier(String id); void debugForceEvent(String id);
}
```

Core mechanics THIS task (modifiers/jokers stubbed off — chaos-0 behavior): 3-dart turns, banking `turnPoints` into `totals` at turn end (floor 0), round advance after last seat, `roundStartTotals` capture at each round start, game over after round `rounds` with ranking + shared-placement tiebreak, meter arithmetic (triple +1, true miss −1, clamp 0–10, `chaosPeak` tracking), bull detection returning `needsBullChoice` (+`resolveBullChoice` applying ±delta into the SAME undo entry), full snapshot undo (every mutable field listed above + `roundStartTotals` + RNG is NOT snapshotted — documented), roster add/remove (remove → seat advance, ≤1 active ends game; FREEZE dissolves on removal — field exists now, set later).

- [ ] **Step 1: Failing tests** (seeded `math.Random(7)` everywhere):

```dart
WildcardEngine plain({int players = 3, int rounds = 5}) => WildcardEngine(
    playerCount: players, rounds: rounds, startingChaos: 0, rng: math.Random(7));

test('chaos-0 baseline: a plain points race, no modifiers, no jokers', () {
  final e = plain();
  for (var r = 0; r < 5 * 3 * 3; r++) {
    expect(e.activeModifier, isNull);
    expect(e.jokers, isEmpty);
    if (e.gameOver) break;
    e.applyDart(5, 1); // no triples/bulls → meter stays 0
  }
  expect(e.gameOver, isTrue);
  expect(e.chaos, 0);
});
test('turn banks at 3 darts and rotation advances', () {
  final e = plain();
  e.applyDart(20, 1); e.applyDart(20, 1);
  final r = e.applyDart(20, 1);
  expect(r.turnEnded, isTrue);
  expect(e.totals[0], 60);
  expect(e.currentPlayerIndex, 1);
  expect(e.turnPoints, 0);
});
test('meter: triple +1, true miss −1, clamps at 0 and 10', () {
  final e = plain();
  final r1 = e.applyDart(0, 0);          // miss at 0 → clamped
  expect(r1.meterDelta, 0); expect(e.chaos, 0);
  final r2 = e.applyDart(20, 3);
  expect(r2.meterDelta, 1); expect(e.chaos, 1);
});
test('bull requires a choice and the choice lands in the same undo entry', () {
  final e = plain();
  final r = e.applyDart(25, 2);          // D-Bull
  expect(r.needsBullChoice, isTrue);
  expect(r.bullChoiceMagnitude, 3);
  e.resolveBullChoice(3);
  expect(e.chaos, 3);
  e.undo();                               // one undo removes dart AND meter change
  expect(e.chaos, 0);
  expect(e.turnPoints, 0);
});
test('game over after final round; ranking by totals, tiebreak highest banked turn', () {
  final e = plain(players: 2, rounds: 1);
  e.applyDart(20, 1); e.applyDart(20, 1); e.applyDart(20, 1); // P0: 60 in one turn
  e.applyDart(20, 3); e.applyDart(0, 0); e.applyDart(0, 0);   // P1: 60 with a 60-turn
  expect(e.gameOver, isTrue);
  expect(e.totals, [60, 60]);
  expect(e.ranking(), [0, 1].where((_) => true).toList()); // REPLACE: assert ranking().first by highestTurn rule — both turns are 60 → shared → seat order [0,1]
});
test('undo restores everything incl. round/turn state', () { /* two darts, turn boundary, undo × 2, assert fields */ });
test('remove current player advances seat; ≤1 active ends game with survivor', () { /* Gotcha-pattern asserts */ });
```

(While writing, replace the marked ranking assertion with concrete non-shared and shared-tiebreak cases — one test each.)

- [ ] **Step 2:** FAIL → **Step 3:** implement (mirror `gotcha_engine.dart` file style: result class, `_WcUndoEntry` snapshot with EVERY mutable field, F7 rotation guard) → **Step 4:** PASS + full suite green.
- [ ] **Step 5:** Commit `feat(wildcard): engine core — points race, chaos meter, bull choice, snapshot undo`

---

### Task 3: Engine — turn-modifiers & THE WINDOW

**Files:** modify `lib/models/wildcard_engine.dart`, extend `test/models/wildcard_engine_test.dart`.

Behavior: at each turn start (first dart of a turn triggers the roll lazily OR an explicit `beginTurn()` — pick: roll INSIDE `applyDart` when `dartsInTurn == 0`, BEFORE scoring, storing `activeModifier`; the screen reads `pendingAnnouncement` — better: roll at TURN START = when the previous turn banks, so the screen can show the announce overlay before any dart. Implement `activeModifier` rolled in `_advanceTurn()` and exposed; the initial turn of the game rolls in the constructor). Chance per `wcModifierChancePct(chaos)`; definition drawn uniformly from `wcModifiers` filtered to `wcSeverityPool(chaos)`; `theWindow` activation also rolls `window = wcRollWindow(rng, chaos)`. Frozen player → no modifier. `debugForceModifier(id)` overrides the next roll.

Scoring per locked interpretations: restriction dims (dart on dimmed segment → 0 points, still alive), DOUBLE TROUBLE (double→×3, triple→0), GOLDEN DART (3rd dart ×3), EVERYTHING ×2 + HOLY TRINITY (+100 at 26) + WINDOW (flat 100 inside, else 0) applied at BANKING time, BULL'S FORTUNE/CURSE (±100 per bull dart), window true-miss voiding, freeze (all darts 0). `dimPredicate` exposed for the board; null during window (window never dims).

- [ ] **Step 1: Failing tests** — per-modifier, all seeded + `debugForceModifier`:

```dart
test('ONLY EVENS: odd segment scores 0 and is dimmed; even scores; meter unaffected by dimmed hit', () {
  final e = plain()..debugForceModifier('onlyEvens');
  e.applyDart(20, 1); e.applyDart(20, 1); e.applyDart(20, 1); // P0 banks; P1's turn rolls forced modifier
  expect(e.activeModifier?.id, 'onlyEvens');
  expect(e.dimPredicate!(7), isTrue);
  final r = e.applyDart(7, 3);   // dimmed triple: 0 points AND NO meter +1? — LOCKED: triple on dimmed segment still +1? NO: a dimmed hit scores 0 and is not a meter-miss; the +1 triple rule follows the DART, keep +1 (meter reacts to throwing skill). REPLACE with decided assert: meterDelta == 1, points == 0.
  expect(r.points, 0);
});
test('DOUBLE TROUBLE: D20 → 60, T20 → 0', () { ... });
test('GOLDEN DART: third dart triples', () { ... });
test('EVERYTHING ×2 doubles the banked turn', () { ... });
test('HOLY TRINITY: exactly 26 banks 126, 27 banks 27', () { ... });
test('BULL FORTUNE: bull dart +100; CURSE: −100 and floor 0 at banking; choice still required', () { ... });
test('WINDOW: inside → banks flat 100 and windowPrizes++, outside → 0', () {
  final e = plain()..debugForceModifier('window');
  ...
});
test('WINDOW: a true miss voids the turn (0) but meter still −1', () { ... });
test('frozen player scores 0 all turn, unfreezes after', () { /* set frozenPlayer directly */ });
test('modifier announcement is per-turn: cleared after banking', () { ... });
test('undo across a modifier roll restores the previous modifier state', () { ... });
```

(The ONLY EVENS meter question is LOCKED as: dimmed triple still moves the meter +1 — encode that exact assert.)

- [ ] **Step 2–4:** FAIL → implement → PASS, full suite green.
- [ ] **Step 5:** Commit `feat(wildcard): engine turn-modifiers — restrictions, transforms, THE WINDOW, freeze`

---

### Task 4: Engine — jokers, instant events, CUT!/REWIND

**Files:** modify `lib/models/wildcard_engine.dart`, extend tests.

Behavior: joker assignment at round start per `wcJokerCount(chaos)` (+DOUBLE JEOPARDY → 2 next round), numbers 1–20 unique, never equal to `cursedNumber`. Hitting a joker (any multiplier, dimmed included; NOT bull): dart scores per rules, meter +2, event drawn from `wcInstantEvents` filtered by `wcSeverityPool(chaos)` (wild double-weighted at 9–10), joker re-rolls to a new number excluding the just-hit one and other actives. `debugForceEvent(id)` overrides the next draw. Events per locked interpretations #9–#15 (`lastEventResolution` field: `({String playerFlagText, int playerIndex, bool good})?` list for standings flags + a human `detail` string for the dialog, e.g. `'Steal 50 from the leader — KARI 288 → 238'`). CUT!/REWIND mutate round flow. Undo across EVERY event type restores byte-for-byte (snapshot already covers it — tests prove it).

- [ ] **Step 1: Failing tests** (seeded; force events):

```dart
test('joker: reveal, meter +2, re-roll excludes just-hit and actives', () { ... });
test('two jokers never share a number', () { /* chaos 9 start, inspect e.jokers */ });
test('CHAOS SURGE: meter +3 clamped', () { ... });
test('SCORE SWAP: totals swap with another living player', () { ... });
test('ROBIN HOOD: steals min(50, victim) from highest OTHER; pointsStolen++', () { ... });
test('GIFT: current + remaining darts credit last place', () { ... });
test('FREEZE: leader flagged; dissolves if leader removed', () { ... });
test('CURSED NUMBER: hit scores negative and clears the curse', () { ... });
test('DOUBLE JEOPARDY: next round has 2 jokers', () { ... });
test('CUT!: players yet to throw lose their turn; in final round ends game', () { ... });
test('REWIND: round scores wiped to roundStartTotals, restart from first seat; jokers unchanged', () { ... });
test('REWIND on round 1 restarts from zero scores', () { ... });
test('undo across joker+event restores meter, totals, joker set, and re-hides the joker', () { ... });
test('undo across REWIND restores the pre-rewind totals and seat', () { ... });
```

Every `...` must be written as a concrete seeded scenario with exact expected numbers (the implementer derives them by hand from the locked rules and asserts literals — no `expect(x, x)` tautologies).

- [ ] **Step 2–4:** FAIL → implement → PASS, full suite green. Engine is now spec-complete (§2–§5, §10).
- [ ] **Step 5:** Commit `feat(wildcard): engine jokers, instant events, CUT!/REWIND, undo across every event`

---

### Task 5: `GameMode.wildcard` + `WildcardConfig` + switch sweep

**Files:** `lib/models/game_mode.dart`, `lib/models/game_config.dart`, `lib/screens/dossedart/dossedart_home_screen.dart` (`_startGame`), `lib/screens/player_setup_screen.dart` (dispatch + options + fields), test `test/models/game_mode_test.dart`.

Identical procedure to Gotcha's Task 4 (that commit, `fc2b75b`, is the template):
- Enum value + `label == 'WILDCARD'`, `emoji == '🃏'`; metadata test first.
- `class WildcardConfig extends GameConfig { final int rounds; final int startingChaos; const WildcardConfig({this.rounds = 10, this.startingChaos = 5}) : super(GameMode.wildcard); }`
- `flutter analyze` → fix EVERY missing-case error: home `_startGame` + classic dispatch get `throw UnimplementedError('replaced in Task 10/11')` placeholders; `_buildModeOptions` gets a REAL options card now — two rows mirroring the file's Gotcha/Shanghai cases: `SegmentedButton<int>` rounds `5/10/15` bound to new `int _wildcardRounds = 10;` and `SegmentedButton<int>` chaos `Mild(2)/Spicy(5)/Total chaos(8)` bound to `int _wildcardChaos = 5;` (labels 'Mild'/'Spicy'/'Chaos' if width-constrained).
- [ ] Commit `feat(wildcard): GameMode.wildcard, WildcardConfig, exhaustive-switch sweep`

---

### Task 6: Dartboard dim support

**Files:** modify `lib/widgets/dossedart/x01/dossedart_x01_dartboard.dart`; test `test/widgets/dossedart_dartboard_dim_test.dart`.

**Interfaces:** `DossedartX01Dartboard({required this.onTap, this.isDim})` — `final bool Function(int segment)? isDim;` default null = today's rendering, all existing call sites untouched.

Painter changes (this file is palette-exempt; add module constants mirroring the JSX):
```dart
const Color _dimSingle = Color(0xFF0B0618);
const Color _dimRing = Color(0xFF140A24);
const Color _dimNumber = Color(0x38D9D2C2); // phosphor @ ~0.22
```
`_DartboardPainter(this.isDim)`: per wedge, if `isDim?.call(n) == true` use `_dimSingle`/`_dimRing` and `_dimNumber` for the label; bull rings NEVER dim. `shouldRepaint` → `oldDelegate.isDim != isDim` (pass the predicate through; also repaint when non-null — simplest correct: `true` when either is non-null, with a comment).

- [ ] **Step 1:** Failing widget test: pump the board with `isDim: (n) => n.isOdd`, tap resolves zones exactly as before (hit-testing unaffected — assert `DartZone.single(20)` etc. from taps at computed offsets, reusing any existing dartboard test's tap math if one exists — check `test/widgets/` first); golden-free paint smoke: `CustomPaint` present; and a pure test on `zoneForPolar` unchanged.
- [ ] **Steps 2–4:** FAIL → implement → PASS + full suite (proves X01/Gotcha/Killer screens still green).
- [ ] Commit `feat(wildcard): dartboard dim states (optional isDim predicate, hit-testing untouched)`

---

### Task 7: Chaos meter + player accents

**Files:**
- Create: `lib/utils/dossedart_player_accents.dart`, `lib/widgets/dossedart/wildcard/dossedart_chaos_meter.dart`
- Test: `test/widgets/dossedart_chaos_meter_test.dart`

**Interfaces:**
```dart
// dossedart_player_accents.dart
const dossedartAccents = [DossedartTokens.cyan, DossedartTokens.magenta,
    DossedartTokens.green, DossedartTokens.purple, DossedartTokens.orange];
Color dossedartAccent(int index) => dossedartAccents[index % dossedartAccents.length];

// dossedart_chaos_meter.dart
class DossedartChaosMeter extends StatelessWidget {
  const DossedartChaosMeter({required this.level});  // 0–10
}
```

Blueprint (JSX `ChaosMeter`, all values there): container margin `fromLTRB(16,12,16,0)`, padding `(16,12,16,13)`, 2px border in `wcChaosColor(level)`, gradient bg `c@.11→c@.02`, glow `c@.33 blur 20` (+ inset red feel at max via an extra red shadow); left column `CHAOS` label (PressStart2P 10, glow) + `<level>` (PressStart2P 42, glow, letterSpacing −2) + `/10` (PressStart2P 14 white40, baseline row); right: Row of 10 `Expanded` heat cells (height 26, gap 4) — cell n: filled `wcChaosColor(n)` when `n <= level` (lead cell `n == level` brighter: white-ish inner glow), else white@.07 with white@.12 border; below: `wcChaosLabel(level)` (PressStart2P 10, heat color) left + right VT323 14 white50 `EVENTS EVERY TURN · 2 JOKERS` at ≥9 else `events @ <wcModifierChancePct(level)>%`. Max (≥9): container pulses (AnimationController, 1.1s, glow intensity — respect `MediaQuery.disableAnimations`, dispose).

- [ ] **Step 1:** Failing tests: level 3 renders `3`, `/10`, `BUBBLING`, `events @ 25%`; level 10 renders `TOTAL CHAOS` and `EVENTS EVERY TURN · 2 JOKERS`; accent util cycles (index 5 → cyan again).
- [ ] **Steps 2–4:** implement → PASS. Commit `feat(wildcard): chaos meter widget + DOSSEDART player accent cycle`

---

### Task 8: Scorecard widget (dart slots · THIS TURN directive · standings)

**Files:**
- Create: `lib/widgets/dossedart/wildcard/dossedart_wildcard_scorecard.dart`
- Test: `test/widgets/dossedart_wildcard_scorecard_test.dart`

**Interfaces (produces):**
```dart
class WcStandingEntry {
  const WcStandingEntry({required this.name, required this.accent, required this.total,
      required this.isActive, this.flagText, this.flagGood = false});
}
class WcDirective {   // built by the SCREEN from engine state (window > modifier > open)
  const WcDirective({required this.icon, required this.color, required this.head, required this.sub});
}
class DossedartWildcardScorecard extends StatelessWidget {
  const DossedartWildcardScorecard({
    required this.playerName, required this.handle, required this.accent,
    required this.round, required this.rounds,
    required this.dartLabels,        // List<String?> length 3: 'T19'/'20'/'DBL'/'—' or null
    required this.turnPoints, required this.gameTotal,
    required this.rank, required this.toLead,   // 0 → LEADER
    required this.directive,          // WcDirective
    required this.standings,          // List<WcStandingEntry>, already ranked
    required this.modifierActive,     // true → themed purple instead of accent
  });
}
```

Blueprint from JSX `WCScoreCard`/`DartSlots`/`ThrowDirective`/`Standings` — port values, not React. Highlights: themed color = `DossedartTokens.purple` when `modifierActive` else `accent`; ribbon `▶ SCORECARD · R<round>/<rounds>`; avatar box 46×46 (3-letter handle, PressStart2P 12); name PressStart2P 15 (reuse the Gotcha card's downscale helper approach); dart slots minWidth 44 height 32 with the four states (thrown/miss/current-pulsing `▸`/empty dashed `·`) + `DART n/3` VT323 14; TURN (PressStart2P 30, accent) and GAME (PressStart2P 32 white, yellow glow, left 2px white12 divider) columns; `#<rank> · <−n TO LEAD | LEADER>` VT323 14; directive band 3px border `d.color`, gradient, tab `THIS TURN` (PressStart2P 8), icon 34, head PressStart2P 18 white double-glow, sub VT323 19 white78; standings caption `STANDINGS` PressStart2P 7 white35 + hairline, one cell per player (rank digit — yellow when idx 0; 7×7 accent dot; name PressStart2P 8 ellipsized; total VT323 20 accent glow; then flag tag (PressStart2P 7, green/red border) OR 👑 idx 0 / ▽ last when leader≠last). Current-slot pulse: 0.9s opacity — single AnimationController, disableAnimations-aware, disposed. Dashed empty slots: solid white@.16 border (accepted Flutter deviation, comment it).

- [ ] **Step 1:** Failing tests: (a) default — `OPEN THROW · SCORE MAX` head when passed as directive, `DART 2/3` for one thrown dart, `LEADER` when toLead 0, 👑 on first standing, ▽ on last; (b) modifier — purple theming assertable via a `Container` decoration predicate + head text `ONLY EVENS`; (c) flags — `+50 STEAL` and `−50 ROBBED` render.
- [ ] **Steps 2–4:** implement → PASS. Commit `feat(wildcard): scorecard — dart slots, THIS TURN directive, demoted standings`

---

### Task 9: Moment dialogs

**Files:**
- Create: `lib/widgets/dossedart/wildcard/dossedart_wildcard_dialogs.dart`
- Test: `test/widgets/dossedart_wildcard_dialogs_test.dart`

**Interfaces:**
```dart
/// Full-screen scrim + centred dialog. Rendered inside the screen's Stack.
class WildcardOverlay extends StatelessWidget {
  const WildcardOverlay({required this.tint, required this.child, this.onTap});
}
class WildcardDialog extends StatelessWidget {   // generic (announce/joker/event/cut/rewind/winner)
  const WildcardDialog({required this.accent, required this.icon, required this.title,
      this.titleSize = 46, this.spin = false, required this.children});
}
class BullChoiceDialog extends StatelessWidget {
  const BullChoiceDialog({required this.magnitude, required this.onIgnite, required this.onCalm});
}
```

Blueprint (JSX `WCOverlay`/`WCDialog`/`BullDialog`): scrim = radial tint@.15→BG@.9 (skip backdrop blur — BackdropFilter is expensive on tablet; a darker scrim compensates, comment the deviation); dialog width 600 max 86%, BG fill, 3px accent border, big glow + inset; icon 42 with pop-in scale animation (or spin for REWIND ⟲, 1.1s linear repeat); title PressStart2P `titleSize` accent, `textShadow`-equivalent glow + 4px magenta offset shadow. Bull dialog: yellow accent, `BULL · 25`/`DOUBLE BULL · 50` title 20, sub `YOU CONTROL THE CHAOS — CHOOSE ±<m>` VT323 20, two tappable panels `▲ +m / IGNITE · MORE CHAOS` (red) and `▼ −m / CALM · COOL IT DOWN` (cyan), footer `LEADERS COOL · TRAILERS IGNITE · BULL SCORES EITHER WAY` VT323 15 white45. All animations disableAnimations-aware + disposed.

- [ ] **Step 1:** Failing tests: bull dialog fires `onIgnite`/`onCalm` on panel taps and renders `±3` for magnitude 3; generic dialog renders icon/title/children; overlay `onTap` fires (tap-to-continue).
- [ ] **Steps 2–4:** implement → PASS. Commit `feat(wildcard): moment dialogs — generic overlay, bull choice`

---

### Task 10: WildcardGameScreen — cockpit, input, overlay state machine, undo

**Files:**
- Create: `lib/screens/wildcard_game_screen.dart`
- Modify: `lib/screens/player_setup_screen.dart` (replace placeholder → `WildcardGameScreen(players: players, config: WildcardConfig(rounds: _wildcardRounds, startingChaos: _wildcardChaos))` + import)
- Test: `test/screens/wildcard_game_screen_test.dart`

Structure templates: `gotcha_game_screen.dart` (state shape, service wiring, throwHistory bookkeeping, `@visibleForTesting` hooks, `_confirmExit`, player sheet) + this cockpit layout:

`Scaffold > DossedartCrtFrame > SafeArea > Stack[ Column[ DossedartTopBar(title: '🃏 WILDCARD', trailing: 'ROUND ${engine.round}/${engine.rounds}'), DossedartChaosMeter(level: engine.chaos), DossedartWildcardScorecard(...), Expanded(board Stack — X01/Gotcha pattern verbatim, with DossedartX01Dartboard(onTap:..., isDim: engine.window == null ? engine.dimPredicate : null) and the glow color red when chaos ≥ 9 else magenta), DossedartActionBar(...) ], if (_overlay != null) <overlay widget> ]`.

Overlay state machine (`_WcOverlayKind { announce, bull, joker, event, cut, rewind, winner }` + `_overlay` field):
- Turn start with `engine.activeModifier != null` → show `announce` (purple dialog: modifier icon/name/desc + `<NAME>'S TURN ONLY` yellow) — tap dismisses; announced via `_announcer` TTS (`'${mod.name}. ${mod.desc}. ${player} only.'`).
- `applyDart` result: `needsBullChoice` → `bull` overlay (blocks; `onIgnite/onCalm` → `engine.resolveBullChoice(±m)` + dismiss); `jokerHit` → `joker` dialog (`HIDDEN NUMBER <n> DETONATES`, `METER +2`, `INSTANT EVENT ▶`) → tap → if `instantEvent` show `event` dialog with `engine.lastEventResolution` detail (CUT!/REWIND get their dedicated red/cyan dialogs) → tap dismisses; `gameOver` → `winner` dialog (`WILDCARD WINNER`, `<NAME> · <total> PTS`, `SURVIVED THE CHAOS`) → tap → post-game flow (Task 11).
- Board + MISS + UNDO input guarded while `_overlay != null` (bull overlay also blocks UNDO — the pending choice must resolve first; document).
- Danger frame: chaos ≥ 9 → red pulsing vignette layered in the Stack (Positioned.fill IgnorePointer, AnimationController 1.4s, disableAnimations-aware).
- `throwHistory` DartThrow bookkeeping like Gotcha (points = effective dart points; `scoreBefore` = totals before; `roundNumber = engine.round`), undo pops + restores counters; undo also clears any non-bull overlay.
- TTS: `announceThrow` per dart (meme-gated), `announceGameEvent('WINDOW PRIZE!')` on window bank, CUT!/REWIND/joker announced with their names.
- `@visibleForTesting`: `engineForTest`, `onDartHitForTest`, `onUndoForTest`, `onGameEndForTest`, `removePlayerForTest`, `addPlayerForTest`, `updateStatsForTest`, `overlayKindForTest`, `dismissOverlayForTest()`, `resolveBullForTest(int)`.

- [ ] **Step 1:** Failing tests (harness from Gotcha's tests):
  - smoke: renders `🃏 WILDCARD`, `ROUND 1/10`, `CHAOS` + starting level `5`; `onDartHitForTest(20,1)` ×3 banks 60 and advances.
  - bull flow: `onDartHitForTest(25,2)` → `overlayKindForTest == bull`; `resolveBullForTest(3)` → chaos 8, overlay cleared; single undo reverts dart+meter.
  - forced modifier announce: `engineForTest.debugForceModifier('onlyEvens')`, bank a turn → overlay `announce`, dismiss, board dims (assert via `engineForTest.dimPredicate!(7)`), dimmed dart scores 0.
  - chaos-0 config: no announce overlay across a full seeded game driven by hooks.
- [ ] **Steps 2–4:** implement → PASS + analyze + full suite. Commit `feat(wildcard): game screen — cockpit, overlay state machine, dimmed board, undo`

---

### Task 11: Game-end flow — no-Elo stats + post-game undo

**Files:** modify `lib/screens/wildcard_game_screen.dart`; test `test/screens/wildcard_postgame_undo_test.dart`.

Copy the Gotcha game-end block (its Task 7 commit `b37ba67` is the parity template) with these substitutions:
- **NO Elo**: no `EloService.updateRatings`, no `_prepareRatingPreview`, no `ratingsBefore/After` params anywhere; `PlayerResult(ratingBefore: null, ratingAfter: null)` → post-game hides deltas automatically.
- `_rankPlayers` → `engine.ranking()` (already tiebreak-aware); `_buildPlacements` shares placement on equal totals AND equal highestTurn (mirror engine tiebreak).
- `modeCounters` per non-skipped saved player: `{'jokersHit': e.jokersHitCount[i], 'windowPrizes': e.windowPrizes[i], 'max:chaosPeak': e.chaosPeak, 'pointsStolen': e.pointsStolen[i], 'max:highestTurn': e.highestTurn[i], 'totalDarts': <from throwHistory>, 'totalGames': 1}`.
- PlayerResult stats: `{'score': totals[i], 'jokersHit': ..., 'windowPrizes': ..., 'highestTurn': ..., 'darts': ...}`.
- `GameResult(gameMode: 'wildcard')`; `recordGame(gameMode: 'wildcard', gameConfig: '${config.rounds} rounds · chaos ${config.startingChaos}')`.
- `awardGameEnd(mode: GameMode.wildcard, eventsByIndex: const {})`.
- Post-game `'undo'` → `engine.undo()` + pop throwHistory + counters + clear winner overlay, back to live play (deferred-stats F17 comments preserved).
- Winner celebration: generic `'winner'` video + `announceWinner`.

- [ ] **Step 1:** Failing tests: (a) drive a 2-player 1-round seeded game via hooks to game over → winner overlay → dismiss → PostGameScreen with `↶ Back` → tap → `engine.gameOver == false`, last dart undone, cockpit back; (b) removed-players-never-win (Gotcha pattern); (c) `updateStatsForTest` early-returns after roster change.
- [ ] **Steps 2–4:** implement → PASS. Commit `feat(wildcard): winner flow, no-Elo deferred stats, post-game undo protocol`

---

### Task 12: Setup screen + home tile + mid-game roster

**Files:**
- Create: `lib/screens/dossedart/dossedart_wildcard_setup_screen.dart`
- Modify: `lib/screens/dossedart/dossedart_home_screen.dart` (tile + `_startGame` placeholder), extend screen tests.

Setup (clone `dossedart_gotcha_setup_screen.dart`): title `'WILDCARD'`, minPlayers 2, `ArcadeChipRow<int>` `'ROUNDS'` `[('5',5),('10',10),('15',15)]` default 10 + `ArcadeChipRow<int>` `'STARTING CHAOS'` `[('MILD',2),('SPICY',5),('TOTAL CHAOS',8)]` default 5 + random-order toggle; summary `'$n PLAYERS · $_rounds ROUNDS · CHAOS $_chaos'`; pushReplacement → `WildcardGameScreen`.

Home grid: the generic ✨ cell (position 9) becomes the WILDCARD tile per spec §7.1. **Decision (Bjørn 2026-07-08): BOTH Gotcha and WILDCARD keep the `fresh` NEW-ribbon treatment** — Gotcha's tile is NOT demoted; header hint becomes `'NEW: GOTCHA 💀 · WILDCARD 🃏'` (VT323 14 yellow; if it overflows next to `► OR PICK A LEVEL` on the 3-col width, shorten to `'NEW: GOTCHA · WILDCARD'`). Replace the `_startGame` placeholder → `DossedartWildcardSetupScreen()`. Update the home grid test (9 tiles: 5 live, Gotcha + WILDCARD fresh with TWO 'NEW' ribbons — `find.text('NEW')` now `findsNWidgets(2)` — 1UP/Golf soon; no generic cell remains). NOTE: the fresh-tile Stack already carries `fit: StackFit.passthrough` (QA regression fix on feat/gotcha, commit 1e9f642) — keep it; the width regression test in `dossedart_home_screen_test.dart` guards it.

Mid-game roster: `_addSavedPlayerMidGame` joins at **0** (spec §7.2 — NOT the table average; differs from Gotcha!) at the current round; removal tests: FREEZE flag dissolves when the frozen player is removed (engine test may already cover; screen test asserts sheet path works).

- [ ] TDD steps as usual; full suite green.
- [ ] Commit `feat(wildcard): setup screen, home tile takes cell 9 (NEW), mid-game roster`

---

### Task 13: Stats surfaces

**Files:** `lib/screens/post_game_screen.dart` (`_buildStats`), `lib/screens/stats_screen.dart` (+`_buildWildcardStats`), `lib/screens/dossedart/dossedart_stats_screen.dart` (`_modeExtras` + `_modes` + `_modeAccent`), `lib/screens/dossedart/game_detail_screen.dart` (`progressionForEntry`), `lib/stats/profile_stats.dart` (`careerRecords` — include from day one, the Gotcha final review flagged its omission).

- post_game `case 'wildcard'`: `Jokers: / Prizes: / Best: / Darts:` from stats keys `jokersHit/windowPrizes/highestTurn/darts`.
- stats_screen `_buildWildcardStats`: 🃏 Jokers hit / 🎯 Window prizes / 🌡️ Chaos peak / ⚡ Best turn (`ms.get('jokersHit')` etc., `chaosPeak` via `ms.get('chaosPeak')` — max: prefix strips to that key).
- dossedart `_modeExtras`: `['jokers ${ms.get('jokersHit')}', 'best turn ${ms.get('highestTurn')}']`; `_modes` += `('wildcard', 'WILDCARD')`; `_modeAccent['wildcard'] = DossedartTokens.purple`.
- `progressionForEntry`: `case 'wildcard': return CumulativeScoreProgression(maxValue: 0);` + comment (swap/steal/rewind effects on OTHER players' lines invisible to per-throw data — accepted like Splitscore halving; the thrower's own line is faithful because DartThrow.points is the effective per-dart credit).
- `careerRecords`: WILDCARD entry mirroring the Gotcha entry's shape, reading `highestTurn`.
- [ ] Verify: analyze clean + full suite green (guard test covers the new strings).
- [ ] Commit `feat(wildcard): post-game rows, per-mode stats, career record, match-detail progression`

---

### Task 14: Full verification + review

- [ ] `flutter analyze` → 0 issues; `flutter test test/` → all green.
- [ ] Manual emulator pass (deferred to tablet QA if no emulator in the execution environment): chaos-0 plain race; a forced modifier via dev override; bull dialog; a joker chain; CUT!; REWIND; winner; post-game undo; setup selectors; home tile.
- [ ] superpowers:requesting-code-review whole-branch review against spec + handoff README (spec §-by-§ coverage; cross-task consistency: engine↔screen contract, undo chain across events, no-Elo path, DartThrow.points convention).
- [ ] Hold for Bjørn: push/PR/merge only on his signal (release train).

---

## Self-review notes (applied)

- Spec §2 (race/rounds/floor/tiebreak) → T2; §3 (meter/movement/tables) → T1+T2; §4 (all 12 modifiers + window) → T1+T3; §5 (jokers + 9 events) → T1+T4; §6 (dimming, always-tappable) → T6+T10; §7.1 home → T12; §7.2 setup (join at 0!) → T12; §7.3 cockpit 11 states → T7–T10; §7.4 post-game → T11+T13; §8 (config/engine/seeded RNG/data-driven/dev override) → T1–T5; §9 (TTS backbone, no Elo, H2H, removed-player, generic winner video) → T10+T11; §10 edge cases → locked interpretations + T3/T4 tests; §11 testing → per-task; §12 out-of-scope respected (no 4×5 grid, no ROUND CHAOS, no Elo, no pubspec sounds).
- Deliberate deviations vs artboards, all documented: no backdrop blur (perf), solid instead of dashed empty dart slots, purple token `#7B3FFF` vs JSX `#B15CFF` (tokens-only rule), player accents = token cycle (README's player_colors reference overridden — those are muted Material colors).
- Plan-level assumptions: NEW-ribbon question RESOLVED (Bjørn 2026-07-08: both Gotcha and WILDCARD carry NEW). Remaining: ONLY-EVENS dimmed triple still moves the meter +1 (locked #interp in T3) — flag to Bjørn if playtest disagrees.
