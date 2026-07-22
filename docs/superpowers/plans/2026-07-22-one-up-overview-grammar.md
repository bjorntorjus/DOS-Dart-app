# 1UP Overview Grammar (status-plate A+) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the 1UP DOSSEDART overview to the approved A+ artboard — the shared grammar skeleton (header + 300px rail) with a status plate carrying SAFE/CAN'T-BEAT/NEED state — inside the same fixed 272px zone as X01.

**Architecture:** Extend the two shared overview widgets with the slots 1UP needs (a `besideName` slot in the header; widget-trailing + dim on rail entries), add a `OneUpStatusPlate` widget and a pure hit-suggestion function, rewrite `DossedartOneUpActiveCard` to compose them, and rewire `one_up_game_screen.dart`.

**Tech Stack:** Flutter, flutter_test with `FontLoader` (px-accurate height pin).

**Fasit:** `docs/design/dossedart-handoff/one-up-overview/design_handoff_1up_overview/` — `one-up-overview-round.jsx` (`OneUpCard` with `helper` = the chosen A+: `Header` w/ hearts beside name, `Primary`, `RuleLine`, `LeftColH` = THIS TURN + `Plate`, `Rail`). `HANDOVER.md` + the brief's "Round outcome" record decisions: HIT-suggestion APPROVED; `#ff8fa6` implemented as red at reduced opacity.

## Global Constraints

- Colors: `DossedartTokens` only + white-with-alpha foregrounds (established convention); player accents via `dossedartAccent(index)`. Lime (`DossedartTokens.lime`) is 1UP mode brand only — SET THE TARGET, SURVIVOR label — never a player accent.
- Fonts 'PressStart2P'/'VT323' only; no borderRadius; English UI strings.
- Zone: card `height: 250` inside margins `EdgeInsets.fromLTRB(14, 12, 14, 10)` (= 272px) — identical in every state; empty content dims to 0.34, never collapses.
- Card border AND glow are the player accent — they NEVER flip with state (identity/state separation; the plate carries state).
- `DART n/3` = dart being thrown (the shared header already does this).
- Last-life rule: all live hearts render red when `lives == 1` (with one life left there is exactly one live heart — pass `DossedartTokens.red` as the pips color at the call site).
- Branch: `feat/overview-grammar`. `flutter analyze` clean before every commit.

---

### Task 1: Shared-component extensions (header besideName + rail widget rows)

**Files:**
- Modify: `lib/widgets/dossedart/overview/dossedart_overview_header.dart`
- Modify: `lib/widgets/dossedart/overview/dossedart_standings_rail.dart`
- Test: `test/widgets/dossedart/overview/dossedart_overview_header_test.dart` (extend)
- Test: `test/widgets/dossedart/overview/dossedart_standings_rail_test.dart` (extend)

**Interfaces:**
- Consumes: the existing widgets from the X01 round.
- Produces (backward compatible — X01 call sites unchanged):
  - `DossedartOverviewHeader` gains `Widget? besideName` — rendered right of the name in the same row, `flexShrink`-stable (name keeps ellipsizing, the slot never shrinks).
  - `DossedartRailEntry` gains `Widget? trailing` (when non-null, rendered instead of the `value` text) and `bool dimmed = false` (rank/dot/name dim like the fasit's ROUND OUT/eliminated rows); `value` becomes optional with default `''`.
  - `DossedartStandingsRail` gains `bool bottomDim = false` (bottom value renders white-0.3 instead of yellow — the fasit's free-throw `—`).

- [ ] **Step 1: Write the failing tests** (append to the two existing test files)

In `dossedart_overview_header_test.dart`:

```dart
  testWidgets('besideName slot renders next to the name', (tester) async {
    await tester.pumpWidget(host(DossedartOverviewHeader(
      playerName: 'KARI',
      avatarPath: null,
      accent: DossedartTokens.magenta,
      dartsThrown: 1,
      besideName: const Text('♥♥', key: Key('hearts')),
    )));
    expect(find.byKey(const Key('hearts')), findsOneWidget);
    // Name and slot share a row: the slot's left edge is right of the name's.
    final nameRight = tester.getTopRight(find.text('KARI')).dx;
    final slotLeft = tester.getTopLeft(find.byKey(const Key('hearts'))).dx;
    expect(slotLeft, greaterThan(nameRight));
  });
```

In `dossedart_standings_rail_test.dart`:

```dart
  testWidgets('trailing widget replaces the value text', (tester) async {
    await tester.pumpWidget(host(DossedartStandingsRail(
      entries: [
        DossedartRailEntry(
            name: 'Mia',
            accent: DossedartTokens.orange,
            trailing: const Text('ROUND OUT', key: Key('tag'))),
      ],
      bottomLabel: 'TARGET',
      bottomValue: '—',
      bottomDim: true,
    )));
    expect(find.byKey(const Key('tag')), findsOneWidget);
    expect(find.text(''), findsNothing); // no empty value Text rendered
  });

  testWidgets('dimmed entry lowers rank/dot/name opacity', (tester) async {
    await tester.pumpWidget(host(DossedartStandingsRail(
      entries: [
        DossedartRailEntry(
            name: 'Per', accent: DossedartTokens.green, value: '3', dimmed: true),
      ],
      bottomLabel: 'TARGET',
      bottomValue: 'BY TOR',
    )));
    final nameText = tester.widget<Text>(find.text('PER'));
    expect((nameText.style?.color?.a ?? 1.0), lessThan(0.5),
        reason: 'dimmed row renders the name at low alpha');
  });
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `flutter test test/widgets/dossedart/overview/`
Expected: the 3 new tests FAIL (unknown named parameters); the old ones still pass.

- [ ] **Step 3: Implement the extensions**

In `dossedart_overview_header.dart` — replace the name `Text` inside the `Column` with:

```dart
              Row(
                children: [
                  Flexible(
                    child: Text(
                      playerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: nameSize,
                        color: Colors.white,
                        letterSpacing: nameSize >= 15 ? 2 : 1.5,
                      ),
                    ),
                  ),
                  if (besideName != null) ...[
                    const SizedBox(width: 12),
                    besideName!,
                  ],
                ],
              ),
```

and add the field/param:

```dart
  final Widget? besideName;
```
(constructor: `this.besideName,`)

In `dossedart_standings_rail.dart`:
- `DossedartRailEntry`: change `required this.value` → `this.value = ''`, add `this.trailing,` and `this.dimmed = false,` with fields `final Widget? trailing;` / `final bool dimmed;`.
- `DossedartStandingsRail`: add `this.bottomDim = false,` / `final bool bottomDim;`; bottom value Text color becomes `bottomDim ? Colors.white.withValues(alpha: 0.3) : DossedartTokens.yellow` and shadows `bottomDim ? null : [existing yellow shadow]`.
- `_RailRow`: rank/dot/name pick dim variants when `entry.dimmed` — rank color `Colors.white.withValues(alpha: entry.dimmed ? 0.18 : 0.35)` (leader-yellow branch unchanged), dot wrapped in `Opacity(opacity: entry.dimmed ? 0.3 : 1, ...)` with no glow shadow when dimmed, name color `entry.dimmed ? Colors.white.withValues(alpha: 0.3) : (existing active/inactive colors)`. Trailing block at the end of the Row becomes:

```dart
            if (e.trailing != null)
              e.trailing!
            else if (e.value.isNotEmpty)
              Text(
                e.value,
                style: TextStyle(
                  fontFamily: 'VT323',
                  fontSize: 18,
                  height: 1,
                  color: e.accent,
                  shadows: [Shadow(color: e.accent.withValues(alpha: 0.33), blurRadius: 6)],
                ),
              ),
```

(keep the `Spacer()` before it so trailing stays right-aligned; also keep the row's outer `Opacity(e.isActive ? 1 : 0.75)` — the fasit's dim rows land at ~0.75×row-dim which matches the artboard's 0.9 outer × inner part-dims closely enough; the per-part dims above are the visible signal.)

- [ ] **Step 4: Run tests to verify all pass**

Run: `flutter test test/widgets/dossedart/overview/ test/widgets/dossedart/x01/`
Expected: ALL pass — including X01's card tests (backward compatibility proof).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/dossedart/overview/ test/widgets/dossedart/overview/
git commit -m "feat(dossedart): header besideName slot + rail widget-trailing/dim (1UP needs)"
```

---

### Task 2: OneUpStatusPlate widget

**Files:**
- Create: `lib/widgets/dossedart/one_up/one_up_status_plate.dart`
- Test: `test/widgets/dossedart/one_up/one_up_status_plate_test.dart`

**Interfaces:**
- Consumes: `OneUpCardMode` — move/keep the existing enum (currently in `dossedart_one_up_active_card.dart`): `enum OneUpCardMode { free, safe, cantBeat, normal }` — do NOT rename its values; the game screen already maps to them.
- Produces: `OneUpStatusPlate({required OneUpCardMode mode, required int target(nullable int? target), required int turnTotal, required int dartsThrown, required bool survivor, String? hitSuggestion})` — exact signature:

```dart
OneUpStatusPlate({
  required OneUpCardMode mode,
  required int? target,
  required int turnTotal,
  required int dartsThrown, // 0..3
  required bool survivor,
  this.hitSuggestion,
})
```

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/one_up/one_up_status_plate.dart';
import 'package:dart_scoring/widgets/dossedart/one_up/dossedart_one_up_active_card.dart'
    show OneUpCardMode;
import 'package:dart_scoring/theme/dossedart_tokens.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
      home: Scaffold(
          backgroundColor: DossedartTokens.bg,
          body: Column(children: [child])));

  OneUpStatusPlate plate(OneUpCardMode mode,
          {int? target = 118,
          int turnTotal = 71,
          int darts = 2,
          bool survivor = false,
          String? hit}) =>
      OneUpStatusPlate(
          mode: mode,
          target: target,
          turnTotal: turnTotal,
          dartsThrown: darts,
          survivor: survivor,
          hitSuggestion: hit);

  testWidgets('need mode: NEED n MORE + hit suggestion', (tester) async {
    await tester.pumpWidget(host(plate(OneUpCardMode.normal, hit: 'T16 +')));
    expect(find.text('NEED 47 MORE'), findsOneWidget);
    expect(find.text('T16 +'), findsOneWidget);
  });

  testWidgets('need mode without suggestion: darts-left fallback',
      (tester) async {
    await tester.pumpWidget(host(plate(OneUpCardMode.normal, darts: 2)));
    expect(find.text('· 1 DART LEFT'), findsOneWidget);
    await tester.pumpWidget(host(plate(OneUpCardMode.normal, darts: 1)));
    expect(find.text('· 2 DARTS LEFT'), findsOneWidget);
  });

  testWidgets('safe mode: SAFE ✓ with NEW TARGET / ROUND SURVIVED',
      (tester) async {
    await tester.pumpWidget(host(plate(OneUpCardMode.safe, turnTotal: 92)));
    expect(find.text('SAFE ✓'), findsOneWidget);
    expect(find.text('NEW TARGET 92'), findsOneWidget);
    await tester
        .pumpWidget(host(plate(OneUpCardMode.safe, survivor: true)));
    expect(find.text('ROUND SURVIVED'), findsOneWidget);
  });

  testWidgets('cantBeat mode: MAX n LEFT from remaining darts',
      (tester) async {
    await tester.pumpWidget(host(plate(OneUpCardMode.cantBeat, darts: 2)));
    expect(find.text("CAN'T BEAT"), findsOneWidget);
    expect(find.text('· MAX 60 LEFT'), findsOneWidget);
  });

  testWidgets('free mode: variant-specific hint line', (tester) async {
    await tester.pumpWidget(host(plate(OneUpCardMode.free, target: null)));
    expect(find.text('▸ YOUR 3-DART TOTAL SETS THE BAR'), findsOneWidget);
    await tester.pumpWidget(
        host(plate(OneUpCardMode.free, target: null, survivor: true)));
    expect(
        find.text('▸ YOUR 3-DART TOTAL IS THE ROUND TARGET'), findsOneWidget);
  });

  testWidgets('all modes share the same minimum height (rule 2)',
      (tester) async {
    final heights = <double>[];
    for (final m in [
      OneUpCardMode.free,
      OneUpCardMode.normal,
      OneUpCardMode.safe,
      OneUpCardMode.cantBeat,
    ]) {
      await tester
          .pumpWidget(host(plate(m, target: m == OneUpCardMode.free ? null : 118)));
      heights.add(tester.getSize(find.byType(OneUpStatusPlate)).height);
    }
    expect(heights.toSet().length, 1,
        reason: 'plate height must not vary by state: $heights');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/dossedart/one_up/one_up_status_plate_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';
import 'dossedart_one_up_active_card.dart' show OneUpCardMode;

/// The A+ status plate — 1UP's dedicated state channel (fasit 2026-07-22).
/// ALWAYS rendered at the same height (rule 2); the card frame stays player
/// accent, so identity and state never share a channel.
class OneUpStatusPlate extends StatelessWidget {
  const OneUpStatusPlate({
    super.key,
    required this.mode,
    required this.target,
    required this.turnTotal,
    required this.dartsThrown,
    required this.survivor,
    this.hitSuggestion,
  });

  final OneUpCardMode mode;
  final int? target;
  final int turnTotal;
  final int dartsThrown; // 0..3
  final bool survivor;
  final String? hitSuggestion;

  @override
  Widget build(BuildContext context) {
    final left = 3 - dartsThrown;
    Color border = Colors.white.withValues(alpha: 0.14);
    Color bg = Colors.white.withValues(alpha: 0.04);
    List<Widget> inner;

    switch (mode) {
      case OneUpCardMode.free:
        border = DossedartTokens.lime.withValues(alpha: 0.53);
        bg = DossedartTokens.lime.withValues(alpha: 0.05);
        inner = [
          Text(
            survivor
                ? '▸ YOUR 3-DART TOTAL IS THE ROUND TARGET'
                : '▸ YOUR 3-DART TOTAL SETS THE BAR',
            style: const TextStyle(
              fontFamily: 'VT323',
              fontSize: 18,
              color: DossedartTokens.cyan,
              letterSpacing: 1,
            ),
          ),
        ];
      case OneUpCardMode.safe:
        border = DossedartTokens.green;
        bg = DossedartTokens.green.withValues(alpha: 0.11);
        inner = [
          Text(
            'SAFE ✓',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 13,
              color: DossedartTokens.green,
              letterSpacing: 1,
              shadows: [
                Shadow(color: DossedartTokens.green, blurRadius: 10),
              ],
            ),
          ),
          Text(
            survivor ? 'ROUND SURVIVED' : 'NEW TARGET $turnTotal',
            style: TextStyle(
              fontFamily: 'VT323',
              fontSize: 17,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ];
      case OneUpCardMode.cantBeat:
        border = DossedartTokens.red;
        bg = DossedartTokens.red.withValues(alpha: 0.10);
        inner = [
          Text(
            "CAN'T BEAT",
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 12,
              color: DossedartTokens.red,
              letterSpacing: 1,
              shadows: [
                Shadow(color: DossedartTokens.red, blurRadius: 8),
              ],
            ),
          ),
          Text(
            '· MAX ${60 * left} LEFT',
            // Fasit used off-token #ff8fa6; round outcome: red at reduced
            // opacity instead.
            style: TextStyle(
              fontFamily: 'VT323',
              fontSize: 16,
              color: DossedartTokens.red.withValues(alpha: 0.6),
            ),
          ),
        ];
      case OneUpCardMode.normal:
        final need = target != null ? (target! - turnTotal).clamp(0, 999) : 0;
        inner = [
          Text(
            'NEED $need MORE',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 12,
              color: DossedartTokens.yellow,
              letterSpacing: 1,
              shadows: [
                Shadow(
                    color: DossedartTokens.yellow.withValues(alpha: 0.53),
                    blurRadius: 6),
              ],
            ),
          ),
          if (hitSuggestion != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '▶',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 9,
                    color: DossedartTokens.green,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  hitSuggestion!,
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 12,
                    color: DossedartTokens.green,
                    letterSpacing: 1,
                    height: 1,
                    shadows: [
                      Shadow(
                          color:
                              DossedartTokens.green.withValues(alpha: 0.4),
                          blurRadius: 8),
                    ],
                  ),
                ),
              ],
            )
          else
            Text(
              '· $left DART${left != 1 ? 'S' : ''} LEFT',
              style: TextStyle(
                fontFamily: 'VT323',
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
        ];
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(color: bg, border: Border.all(color: border, width: 2)),
      child: Row(
        children: [
          for (var i = 0; i < inner.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            inner[i],
          ],
        ],
      ),
    );
  }
}
```

Note: the enum import will initially fail if `OneUpCardMode` still lives in the old card file with other exports — that is fine; Task 4 rewrites that file and keeps the enum. If the analyzer complains about unused imports in the OLD card file, leave the old file untouched — Task 4 owns it.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/dossedart/one_up/one_up_status_plate_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/dossedart/one_up/one_up_status_plate.dart test/widgets/dossedart/one_up/one_up_status_plate_test.dart
git commit -m "feat(one-up): status plate widget (A+ state channel, always rendered)"
```

---

### Task 3: Hit-suggestion function

**Files:**
- Create: `lib/utils/one_up_hit_suggestion.dart`
- Test: `test/utils/one_up_hit_suggestion_test.dart`

**Interfaces:**
- Produces: `String? oneUpHitSuggestion(int need)` — the lowest single-dart score `>= need`, labelled; `+` suffix when that score overshoots (no exact single-dart hit equals `need`); null when `need <= 0` or `need > 60` (no single dart can do it — the plate falls back to darts-left).
- Labels: singles 1–20 → `'20'`; 25 → `'25'`; doubles → `'D16'`; triples → `'T16'`; 50 → `'BULL'`. Preference at equal score value: single > 25 > double > triple > BULL (simplest to hit first).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/utils/one_up_hit_suggestion.dart';

void main() {
  group('oneUpHitSuggestion', () {
    test('exact single-dart hits, simplest label wins', () {
      expect(oneUpHitSuggestion(20), '20'); // S20 exact
      expect(oneUpHitSuggestion(25), '25'); // 25 beats D? (no D=25); exact
      expect(oneUpHitSuggestion(40), 'D20'); // no single 40; D20 exact
      expect(oneUpHitSuggestion(48), 'T16'); // T16 exact
      expect(oneUpHitSuggestion(60), 'T20'); // max
      expect(oneUpHitSuggestion(50), 'BULL'); // 50: no S/D25×2=D25? BULL label
    });

    test('overshoot gets the + suffix', () {
      expect(oneUpHitSuggestion(47), 'T16 +'); // lowest >= 47 is 48 = T16
      expect(oneUpHitSuggestion(41), 'T14 +'); // 42 = T14 (D21 does not exist)
      expect(oneUpHitSuggestion(59), 'T20 +'); // 60
    });

    test('bounds: nothing needed or impossible', () {
      expect(oneUpHitSuggestion(0), isNull);
      expect(oneUpHitSuggestion(-5), isNull);
      expect(oneUpHitSuggestion(61), isNull);
    });

    test('every need 1..60 returns a suggestion', () {
      for (var need = 1; need <= 60; need++) {
        expect(oneUpHitSuggestion(need), isNotNull, reason: 'need=$need');
      }
    });
  });
}
```

Note on `oneUpHitSuggestion(50)`: score 50 is reachable as D25 (bull double) or the 50-ring itself; the label preference row for value 50 is `'BULL'` (the app's existing checkout vocabulary uses D-BULL/BULL — grep `assets`/X01 checkout table if unsure; `'BULL'` is the decided label here).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/utils/one_up_hit_suggestion_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement**

```dart
/// 1UP hit suggestion (approved PROPOSAL, fasit 2026-07-22): the lowest
/// single-dart score that reaches [need] (tie = success, so >= is enough),
/// with a trailing ' +' when it overshoots. Null when nothing is needed or
/// no single dart can do it (need > 60) — the status plate then falls back
/// to its darts-left line. Label preference at equal score: single, 25,
/// double, triple, BULL — simplest throw first.
String? oneUpHitSuggestion(int need) {
  if (need <= 0 || need > 60) return null;

  String? labelFor(int score) {
    if (score >= 1 && score <= 20) return '$score';
    if (score == 25) return '25';
    if (score % 2 == 0 && score ~/ 2 >= 1 && score ~/ 2 <= 20) {
      return 'D${score ~/ 2}';
    }
    if (score % 3 == 0 && score ~/ 3 >= 1 && score ~/ 3 <= 20) {
      return 'T${score ~/ 3}';
    }
    if (score == 50) return 'BULL';
    return null;
  }

  for (var score = need; score <= 60; score++) {
    final label = labelFor(score);
    if (label != null) {
      return score == need ? label : '$label +';
    }
  }
  return null;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/utils/one_up_hit_suggestion_test.dart`
Expected: PASS (4 tests). If `oneUpHitSuggestion(50)` fails because 50 % 2 == 0 hits the `D25`… branch: note `score ~/ 2 = 25 > 20`, so the double branch correctly rejects it and falls through to `'BULL'` — trace before changing anything.

- [ ] **Step 5: Commit**

```bash
git add lib/utils/one_up_hit_suggestion.dart test/utils/one_up_hit_suggestion_test.dart
git commit -m "feat(one-up): hit-suggestion function (lowest single dart that reaches the target)"
```

---

### Task 4: 1UP active card rewrite (A+)

**Files:**
- Modify: `lib/widgets/dossedart/one_up/dossedart_one_up_active_card.dart` (full rewrite; KEEP `enum OneUpCardMode { free, safe, cantBeat, normal }` exported unchanged)
- Test: `test/widgets/dossedart/one_up/dossedart_one_up_active_card_test.dart` (rewrite/replace whatever exists for the old card — grep `test/` for `DossedartOneUpActiveCard` and `OneUpOpponentEntry` first; delete stale files whose assertions target the old layout, after confirming their intent is covered here)

**Interfaces:**
- Consumes: `DossedartOverviewHeader` (+`besideName`), `DossedartStandingsRail` (+`trailing`/`dimmed`/`bottomDim`), `OneUpLifePips` (existing, `lib/widgets/dossedart/one_up/one_up_life_pips.dart`), `OneUpStatusPlate` (Task 2).
- Produces:

```dart
class OneUpStanding {
  const OneUpStanding({
    required this.name,
    required this.accent,
    required this.lives,
    required this.maxLives,
    this.eliminated = false,
    this.outOfRound = false,
    this.isActive = false,
  });
  final String name;
  final Color accent;
  final int lives;
  final int maxLives;
  final bool eliminated;
  final bool outOfRound;
  final bool isActive;
}

DossedartOneUpActiveCard({
  required String playerName,
  required String? avatarPath,
  required Color accentColor,
  required int lives,
  required int maxLives,
  required int? target,          // null in free-throw
  required int turnTotal,
  required int currentDartIndex, // darts thrown 0..3
  required OneUpCardMode cardMode,
  required bool survivor,
  required int roundNumber,
  required String? targetBy,     // name, null in free-throw
  required List<OneUpStanding> standings, // THROW ORDER, incl. active
  String? hitSuggestion,
})
```

Layout (fasit `OneUpCard helper` + `LeftColH`): fixed 250px card, margins 14/12/14/10, surface fill, 3px accent border, 14px accent glow (NEVER flips) →
1. `DossedartOverviewHeader` with `besideName` = `OneUpLifePips(lives, max, color: lives == 1 ? DossedartTokens.red : accentColor, size: 17)` plus (when `lives == 1`) a `LAST LIFE` tag (PS-7 red, 1px red border, padding 2/4) — and `trailing` = the primary block:
   - free-throw (`target == null`): label `FREE THROW` PS-8 white-0.55 + `SET THE\nTARGET` PS-22 lime, 2 lines, lime glow
   - else: label `BEAT` PS-8 white-0.55 + `$target` PS-60 in accent, glow, letterSpacing −2
2. Rule line: full-width row — when `survivor`: `SURVIVOR · RND $roundNumber` PS-6 lime w/ glow, then a 1px white-0.1 hairline `Expanded`; when not survivor: just the hairline (no label — KISS).
3. Body `Expanded(Row)`: left column (`Expanded`) = `THIS TURN` row (label PS-9 white-0.5 width 88 + `$turnTotal` VT-38 accent w/ glow + `/ ${target ?? '—'}` VT-28 white-0.35; whole row `Opacity 0.34` when `currentDartIndex == 0`) top-aligned, `OneUpStatusPlate` bottom-aligned (Column `mainAxisAlignment: spaceBetween`) · 14px gap · `DossedartStandingsRail`:
   - entries in the given order (NO sorting), `dimmed: e.eliminated || e.outOfRound`, `isActive: e.isActive`
   - `trailing:` eliminated → `Text('💀 OUT', PS-7 white-0.3, letterSpacing 0.5)`; outOfRound → bordered tag `ROUND OUT` (PS-6 red at 0.8 opacity, 1px red-0.4 border, padding 2/4); otherwise `OneUpLifePips(lives, max, color: e.lives == 1 ? DossedartTokens.red : e.accent, size: 13)`
   - `bottomLabel: 'TARGET'`, `bottomValue: targetBy != null ? 'BY ${targetBy!.toUpperCase()}' : '—'`, `bottomDim: targetBy == null`

- [ ] **Step 1: Write the failing test** (real-font FontLoader pattern — copy the `_loadRealFonts` helper verbatim from `test/widgets/dossedart/x01/dossedart_x01_active_card_test.dart`)

```dart
// imports: material, services, flutter_test, dart:io, dart:typed_data (if
// needed by the copied font helper), the card file, dossedart_player_accents,
// tokens.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadRealFonts);

  List<OneUpStanding> four({bool lastLife = false, bool survivorOut = false}) => [
        OneUpStanding(name: 'Jonas', accent: dossedartAccent(0), lives: 3, maxLives: 3),
        OneUpStanding(
            name: 'Kari',
            accent: dossedartAccent(1),
            lives: lastLife ? 1 : 2,
            maxLives: 3,
            isActive: true),
        OneUpStanding(
            name: 'Per',
            accent: dossedartAccent(2),
            lives: 3,
            maxLives: 3,
            outOfRound: survivorOut),
        OneUpStanding(
            name: 'Mia', accent: dossedartAccent(3), lives: 0, maxLives: 3, eliminated: true),
      ];

  Widget host(Widget card) => MaterialApp(home: Scaffold(body: Column(children: [card])));

  DossedartOneUpActiveCard card({
    int? target = 118,
    int turnTotal = 71,
    int darts = 2,
    OneUpCardMode mode = OneUpCardMode.normal,
    bool survivor = false,
    String? targetBy = 'Per',
    String? hit = 'T16 +',
    List<OneUpStanding>? standings,
    String name = 'Kari',
    int lives = 2,
  }) =>
      DossedartOneUpActiveCard(
        playerName: name,
        avatarPath: null,
        accentColor: dossedartAccent(1),
        lives: lives,
        maxLives: 3,
        target: target,
        turnTotal: turnTotal,
        currentDartIndex: darts,
        cardMode: mode,
        survivor: survivor,
        roundNumber: 4,
        targetBy: targetBy,
        standings: standings ?? four(),
        hitSuggestion: hit,
      );

  testWidgets('272px zone in every stress state', (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final states = <String, DossedartOneUpActiveCard>{
      'need + hit': card(),
      'free throw': card(
          target: null, mode: OneUpCardMode.free, targetBy: null, hit: null, darts: 0, turnTotal: 0),
      'safe survivor': card(mode: OneUpCardMode.safe, survivor: true),
      "can't beat": card(mode: OneUpCardMode.cantBeat, hit: null),
      'last life + long name': card(
          name: 'Alexander the boss bitch', lives: 1, standings: four(lastLife: true)),
      'six players': card(standings: [
        ...four(survivorOut: true),
        OneUpStanding(name: 'Tor', accent: dossedartAccent(4), lives: 3, maxLives: 3),
        OneUpStanding(name: 'Andreas', accent: dossedartAccent(5), lives: 2, maxLives: 3),
      ]),
    };
    for (final e in states.entries) {
      await tester.pumpWidget(host(e.value));
      expect(tester.getSize(find.byType(DossedartOneUpActiveCard)).height, 272.0,
          reason: 'zone height in "${e.key}"');
    }
  });

  testWidgets('primary block: BEAT target vs SET THE TARGET', (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(card()));
    expect(find.text('BEAT'), findsOneWidget);
    expect(find.text('118'), findsOneWidget);
    await tester.pumpWidget(host(card(
        target: null, mode: OneUpCardMode.free, targetBy: null, hit: null)));
    expect(find.text('SET THE\nTARGET'), findsOneWidget);
    expect(find.text('—'), findsWidgets); // TARGET BY dimmed + THIS TURN "/ —"
  });

  testWidgets('rail rows: hearts, ROUND OUT, OUT; TARGET BY bottom',
      (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(card(standings: four(survivorOut: true))));
    expect(find.text('💀 OUT'), findsOneWidget);
    expect(find.text('ROUND OUT'), findsOneWidget);
    expect(find.text('BY PER'), findsOneWidget);
    // No sorting: throw order preserved (Jonas row 1, i.e. rank text '1'
    // appears left of JONAS — sufficient to assert both exist unsorted).
    expect(find.text('JONAS'), findsOneWidget);
  });

  testWidgets('survivor rule line label', (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(card(survivor: true)));
    expect(find.text('SURVIVOR · RND 4'), findsOneWidget);
    await tester.pumpWidget(host(card()));
    expect(find.text('SURVIVOR · RND 4'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/dossedart/one_up/dossedart_one_up_active_card_test.dart`
Expected: FAIL — new constructor/`OneUpStanding` don't exist yet.

- [ ] **Step 3: Rewrite the card** to the layout in the Interfaces block above. Keep the file's only other export the unchanged `enum OneUpCardMode`. Delete `OneUpOpponentEntry` and all old layout code. Follow the X01 card (`lib/widgets/dossedart/x01/dossedart_x01_active_card.dart`) for the frame/margins/height pattern — same `Container(margin: …fromLTRB(14,12,14,10), height: 250, padding: …fromLTRB(14,12,14,12), decoration: surface + 3px accent border + 14px glow)`.

- [ ] **Step 4: Run tests; fix stale usages in test/ only**

Run: `flutter test test/widgets/dossedart/one_up/ && flutter analyze`
Expected: card tests PASS. Project analyze will flag `one_up_game_screen.dart` (old constructor) — acceptable for THIS task only (Task 5 wires it); everything else must be clean. Grep `OneUpOpponentEntry` across `test/` and update/delete stale fixtures (document intent-coverage for anything deleted in your report).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/dossedart/one_up/ test/widgets/dossedart/one_up/ test/
git commit -m "feat(one-up): A+ overview card - status plate, standings rail, fixed 272px zone"
```

---

### Task 5: one_up_game_screen wiring

**Files:**
- Modify: `lib/screens/one_up_game_screen.dart` (the `DossedartOneUpActiveCard(...)` call, ~line 719)
- Test: existing suites + `flutter analyze`

**Interfaces:**
- Consumes: the new card API (Task 4), `oneUpHitSuggestion` (Task 3), `engine` fields already used in the file: `engine.livesLeft`, `engine.target`, `engine.turnPoints`, `engine.dartsInTurn`, `engine.isFreeThrow`, `engine.isEliminated(i)`, `engine.isOutOfRound(i)`, `engine.isSkipped(i)`, `engine.targetSetBy`, `_cardMode` getter, plus the survivor flag `widget.config.variant == OneUpVariant.survivor` and `engine.roundNumber` (public int, 1-based).

- [ ] **Step 1: Replace the card construction**

```dart
                  DossedartOneUpActiveCard(
                    playerName: players[cur].name,
                    avatarPath: players[cur].avatarPath,
                    accentColor: dossedartAccent(cur),
                    lives: engine.livesLeft[cur],
                    maxLives: widget.config.lives,
                    target: engine.isFreeThrow ? null : engine.target,
                    turnTotal: engine.turnPoints,
                    currentDartIndex: engine.dartsInTurn,
                    cardMode: _cardMode,
                    survivor:
                        widget.config.variant == OneUpVariant.survivor,
                    roundNumber: engine.roundNumber,
                    targetBy: engine.isFreeThrow || engine.targetSetBy < 0
                        ? null
                        : players[engine.targetSetBy].name,
                    hitSuggestion: _cardMode == OneUpCardMode.normal &&
                            engine.target != null
                        ? oneUpHitSuggestion(engine.target! - engine.turnPoints)
                        : null,
                    standings: [
                      for (int i = 0; i < players.length; i++)
                        if (!engine.isSkipped(i)) // removed players stay out (X01 parity)
                          OneUpStanding(
                            name: players[i].name,
                            accent: dossedartAccent(i),
                            lives: engine.livesLeft[i],
                            maxLives: widget.config.lives,
                            eliminated: engine.isEliminated(i),
                            outOfRound: engine.isOutOfRound(i),
                            isActive: i == cur,
                          ),
                    ],
                  ),
```

Notes: the OLD call filtered `i != cur` out of opponents — the new rail INCLUDES the active player (fasit). `engine.isSkipped(i)` is the removed-player guard this screen already uses — keep it (this is the standings-leak fix X01 needed, already idiomatic here). If `engine.target` is non-nullable in this engine, adapt the null-handling to the free-throw flag only — check the engine before writing.

- [ ] **Step 2: Full verification**

Run: `flutter analyze && flutter test`
Expected: analyze fully clean; full suite green. Update any screen-level 1UP tests asserting the old card layout (opponents-strip texts etc.) to the new grammar — same rules as before: preserve intent, don't weaken.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/one_up_game_screen.dart test/
git commit -m "feat(one-up): wire A+ card - rail incl. active, hit suggestion, TARGET BY"
```
