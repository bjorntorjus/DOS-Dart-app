# X01 Overview Grammar (rail-B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the X01 DOSSEDART overview to the approved rail-B artboard — shared grammar header + 300px standings rail inside a fixed 272px zone — producing the template components the 1UP/Golf/Cricket rounds will reuse.

**Architecture:** Two new shared widgets (`DossedartOverviewHeader`, `DossedartStandingsRail`) under `lib/widgets/dossedart/overview/`, a full rewrite of `DossedartX01ActiveCard` composing them, and wiring in `game_screen.dart` (per-player accents, HIT%, standings data). The card gets a hard 250px height (272px zone incl. margins 12/10) pinned by a real-font regression test across all four stress states.

**Tech Stack:** Flutter (local StatefulWidget state), flutter_test with `FontLoader` for px-accurate tests.

**Fasit:** `docs/design/dossedart-handoff/x01-overview/design_handoff_x01_overview/` — `x01-overview-round.jsx` `CardB` is the visual truth; `HANDOVER.md` + the brief's "Round outcome" section record the decisions.

## Global Constraints

- Colors: `DossedartTokens` only (`lib/theme/dossedart_tokens.dart`); player accents via `dossedartAccent(index)` from `lib/utils/dossedart_player_accents.dart`. Never `colorScheme`, never raw hex.
- Fonts: `Press Start 2P` (labels/numbers) and `VT323` (values) only.
- No `borderRadius` anywhere.
- All UI strings English (a guard test fails the build on Norwegian).
- Zone budget: card height exactly **250px** (272px with margins `EdgeInsets.fromLTRB(14, 12, 14, 10)`); every state identical height — empty content dims to opacity 0.34, never collapses.
- `DART n/3` = the dart **being thrown**: display `min(dartsThrown + 1, 3)`; pips fill `dartsThrown`.
- HIT% definition (user-approved): share of the active player's darts this leg that hit the board at all — `segment > 0` over all their `throwHistory` entries.
- Branch: `feat/overview-grammar`. Run `flutter analyze` before every commit; it must stay clean.

---

### Task 1: Shared overview header widget

**Files:**
- Create: `lib/widgets/dossedart/overview/dossedart_overview_header.dart`
- Test: `test/widgets/dossedart_overview_header_test.dart`

**Interfaces:**
- Consumes: `DossedartPlayerAvatar` (existing, `lib/widgets/dossedart/dossedart_player_avatar.dart`) with `(avatarPath, size, borderColor)`.
- Produces: `DossedartOverviewHeader({required String playerName, required String? avatarPath, required Color accent, required int dartsThrown, Widget? trailing})` — grammar rule 4 header. `trailing` is the mode's primary-number block (right-aligned).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/overview/dossedart_overview_header.dart';
import 'package:dart_scoring/theme/dossedart_tokens.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
      home: Scaffold(
          backgroundColor: DossedartTokens.bg,
          body: Row(children: [Expanded(child: child)])));

  testWidgets('DART n/3 counts the dart being thrown (grammar rule 4)',
      (tester) async {
    // 0 thrown → you are on dart 1; 2 thrown → on dart 3 (never 4/3).
    for (final (thrown, label) in [(0, 'DART 1/3'), (1, 'DART 2/3'), (2, 'DART 3/3')]) {
      await tester.pumpWidget(host(DossedartOverviewHeader(
        playerName: 'KARI',
        avatarPath: null,
        accent: DossedartTokens.magenta,
        dartsThrown: thrown,
      )));
      expect(find.text(label), findsOneWidget,
          reason: '$thrown thrown should read "$label"');
    }
  });

  testWidgets('name size curve: 18/15/12/10 at thresholds 6/10/16',
      (tester) async {
    for (final (name, size) in [
      ('KARI', 18.0),           // <=6
      ('ALEXANDRA', 15.0),      // <=10
      ('KARI FRANSISKA', 12.0), // <=16
      ('ALEXANDER THE BOSS', 10.0), // >16
    ]) {
      await tester.pumpWidget(host(DossedartOverviewHeader(
        playerName: name,
        avatarPath: null,
        accent: DossedartTokens.cyan,
        dartsThrown: 0,
      )));
      final text = tester.widget<Text>(find.text(name));
      expect(text.style?.fontSize, size, reason: '"$name" should be ${size}px');
    }
  });

  testWidgets('trailing slot renders right of the name block', (tester) async {
    await tester.pumpWidget(host(DossedartOverviewHeader(
      playerName: 'KARI',
      avatarPath: null,
      accent: DossedartTokens.cyan,
      dartsThrown: 0,
      trailing: const Text('501', key: Key('primary')),
    )));
    expect(find.byKey(const Key('primary')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/dossedart_overview_header_test.dart`
Expected: FAIL — compilation error, `dossedart_overview_header.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../dossedart_player_avatar.dart';

/// Grammar rule 4 header, shared by every DOSSEDART overview card:
/// 56px photo avatar (silhouette fallback) · name on the X01 length→size
/// curve · three 9px dart pips + `DART n/3` where n is the dart being
/// thrown (grammar decision 2026-07-22 — 0 thrown reads "DART 1/3").
/// [trailing] is the mode's primary-number block, right-aligned.
class DossedartOverviewHeader extends StatelessWidget {
  const DossedartOverviewHeader({
    super.key,
    required this.playerName,
    required this.avatarPath,
    required this.accent,
    required this.dartsThrown,
    this.trailing,
  });

  final String playerName;
  final String? avatarPath;
  final Color accent;
  final int dartsThrown; // 0..3
  final Widget? trailing;

  double _nameFontSize() {
    final len = playerName.length;
    if (len <= 6) return 18;
    if (len <= 10) return 15;
    if (len <= 16) return 12;
    return 10;
  }

  @override
  Widget build(BuildContext context) {
    final nameSize = _nameFontSize();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DossedartPlayerAvatar(
          avatarPath: avatarPath,
          size: 56,
          borderColor: accent,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                playerName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: nameSize,
                  color: Colors.white,
                  letterSpacing: nameSize >= 15 ? 2 : 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: i < dartsThrown ? accent : Colors.transparent,
                        border: Border.all(color: accent, width: 2),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    'DART ${min(dartsThrown + 1, 3)}/3',
                    style: const TextStyle(
                      fontFamily: 'VT323',
                      fontSize: 13,
                      color: Colors.white54,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/dossedart_overview_header_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/dossedart/overview/dossedart_overview_header.dart test/widgets/dossedart_overview_header_test.dart
git commit -m "feat(dossedart): shared overview header (grammar rule 4, DART n/3 = current dart)"
```

---

### Task 2: Standings rail widget

**Files:**
- Create: `lib/widgets/dossedart/overview/dossedart_standings_rail.dart`
- Test: `test/widgets/dossedart_standings_rail_test.dart`

**Interfaces:**
- Produces:
  - `class DossedartRailEntry { final String name; final Color accent; final String value; final bool isActive; final bool isLeader; }` (const constructor, named params, all required except `isActive`/`isLeader` default false).
  - `DossedartStandingsRail({required List<DossedartRailEntry> entries, required String bottomLabel, required String bottomValue})` — 300px-wide column: hairline left border, one flex row per entry (rank № · accent dot · mid-truncated name · 👑 on leader · value in accent), pinned bottom row.
  - `String midTruncate(String s, int max)` — top-level helper; keeps start `ceil((max-1)*0.6)` + `…` + end `floor((max-1)*0.4)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/overview/dossedart_standings_rail.dart';
import 'package:dart_scoring/theme/dossedart_tokens.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
      home: Scaffold(
          backgroundColor: DossedartTokens.bg,
          body: SizedBox(height: 160, child: Row(children: [child]))));

  List<DossedartRailEntry> entries({bool leader = true}) => [
        DossedartRailEntry(
            name: 'Jonas',
            accent: DossedartTokens.cyan,
            value: '60',
            isLeader: leader),
        DossedartRailEntry(
            name: 'Live',
            accent: DossedartTokens.green,
            value: '141',
            isActive: true),
        DossedartRailEntry(
            name: 'Alexander the boss bitch',
            accent: DossedartTokens.purple,
            value: '264'),
      ];

  test('midTruncate keeps start and end around a single ellipsis', () {
    expect(midTruncate('ALEXANDER THE BOSS BITCH', 16),
        'ALEXANDER…BITCH'.replaceAll('…', '…'));
    expect(midTruncate('ALEXANDER THE BOSS BITCH', 16).length,
        lessThanOrEqualTo(16));
    expect(midTruncate('KARI', 16), 'KARI'); // short names untouched
  });

  testWidgets('crown renders exactly once, on the unique leader',
      (tester) async {
    await tester.pumpWidget(host(DossedartStandingsRail(
        entries: entries(),
        bottomLabel: 'TO WIN',
        bottomValue: '▲ 81')));
    expect(find.text('👑'), findsOneWidget);

    await tester.pumpWidget(host(DossedartStandingsRail(
        entries: entries(leader: false),
        bottomLabel: 'TO WIN',
        bottomValue: 'TIED')));
    expect(find.text('👑'), findsNothing);
  });

  testWidgets('bottom row shows label and value', (tester) async {
    await tester.pumpWidget(host(DossedartStandingsRail(
        entries: entries(),
        bottomLabel: 'TO WIN',
        bottomValue: '▲ 81')));
    expect(find.text('TO WIN'), findsOneWidget);
    expect(find.text('▲ 81'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/dossedart_standings_rail_test.dart`
Expected: FAIL — compilation error, file does not exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:flutter/material.dart';

/// Middle-truncation for rail names (fasit: "ALEXANDER…BITCH") — start and
/// end both kept so long names stay recognizable in the tight rail column.
String midTruncate(String s, int max) {
  if (s.length <= max) return s;
  final head = ((max - 1) * 0.6).ceil();
  final tail = ((max - 1) * 0.4).floor();
  return '${s.substring(0, head)}…${s.substring(s.length - tail)}';
}

class DossedartRailEntry {
  const DossedartRailEntry({
    required this.name,
    required this.accent,
    required this.value,
    this.isActive = false,
    this.isLeader = false,
  });

  final String name;
  final Color accent;
  final String value;
  final bool isActive;
  final bool isLeader;
}

/// The shared standings column (grammar rule: standings are mandatory) —
/// rail-B from the X01 round, the shape every mode feeds its own data into.
/// Caller pre-sorts [entries]; rows flex to fill the available height so the
/// rail never grows the card. [bottomLabel]/[bottomValue] is the pinned
/// mode-specific bottom row (X01: TO WIN delta).
class DossedartStandingsRail extends StatelessWidget {
  const DossedartStandingsRail({
    super.key,
    required this.entries,
    required this.bottomLabel,
    required this.bottomValue,
  });

  final List<DossedartRailEntry> entries;
  final String bottomLabel;
  final String bottomValue;

  static const double width = 300;

  @override
  Widget build(BuildContext context) {
    const ink = Colors.white;
    return Container(
      width: width,
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: ink.withValues(alpha: 0.12), width: 1),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++)
            Expanded(child: _RailRow(index: i, entry: entries[i])),
          Container(
            padding: const EdgeInsets.only(top: 4),
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: ink.withValues(alpha: 0.1), width: 1),
              ),
            ),
            child: Row(
              children: [
                Text(
                  bottomLabel,
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                    color: ink.withValues(alpha: 0.5),
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Text(
                  bottomValue,
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 13,
                    color: Color(0xFFFFD200), // DossedartTokens.yellow
                    shadows: [
                      Shadow(color: Color(0x88FFD200), blurRadius: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailRow extends StatelessWidget {
  const _RailRow({required this.index, required this.entry});

  final int index;
  final DossedartRailEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 1, 5, 1),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: e.isActive ? e.accent : Colors.transparent,
            width: 3,
          ),
        ),
        color: e.isActive
            ? e.accent.withValues(alpha: 0.09)
            : Colors.transparent,
      ),
      child: Opacity(
        opacity: e.isActive ? 1 : 0.75,
        child: Row(
          children: [
            SizedBox(
              width: 10,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 7,
                  color: e.isLeader
                      ? const Color(0xFFFFD200)
                      : Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ),
            const SizedBox(width: 7),
            Container(width: 7, height: 7, color: e.accent),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                midTruncate(e.name.toUpperCase(), 16),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  letterSpacing: 0.5,
                  color: e.isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
            if (e.isLeader) const Text('👑', style: TextStyle(fontSize: 10)),
            const Spacer(),
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
          ],
        ),
      ),
    );
  }
}
```

Note: the two `Color(0xFFFFD200)` literals are `DossedartTokens.yellow` — import `../../../theme/dossedart_tokens.dart` and use the token instead of the literal (shown inline here only for completeness).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/dossedart_standings_rail_test.dart`
Expected: PASS (3 tests). If the crown emoji assertion fails on `findsOneWidget`, match with `find.textContaining('👑')` — the row renders it as its own `Text`.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/dossedart/overview/dossedart_standings_rail.dart test/widgets/dossedart_standings_rail_test.dart
git commit -m "feat(dossedart): shared standings rail (grammar rule: standings mandatory)"
```

---

### Task 3: X01 active card rewrite (rail-B)

**Files:**
- Modify: `lib/widgets/dossedart/x01/dossedart_x01_active_card.dart` (full rewrite)
- Test: `test/widgets/dossedart_x01_active_card_test.dart` (new)

**Interfaces:**
- Consumes: `DossedartOverviewHeader` (Task 1), `DossedartStandingsRail`/`DossedartRailEntry`/`midTruncate` (Task 2), `DossedartTokens`.
- Produces:
  - `class X01Standing { final String name; final Color accent; final int remaining; final bool isActive; }` (const, named required params) — exported from the card file.
  - `DossedartX01ActiveCard({required String playerName, required String? avatarPath, required Color accentColor, required int remaining, required int currentDartIndex, required String? lastTurnLabel, required int? lastTurnSum, required String? checkoutTip, double? avg, int? hitPercent, required List<X01Standing> standings})`.
  - Card is **exactly 250px tall** (`SizedBox(height: 250)` inside margins 14/12/14/10) in every state.
  - Sorting/leader/TO WIN math lives in the card: sort standings ascending by `remaining`; unique minimum → that entry `isLeader`; bottom value = active's `remaining - min` → `▲ n`, or `YOU LEAD` (delta 0, unique min = active), or `TIED` (delta 0, shared min).

- [ ] **Step 1: Write the failing test**

The test loads real fonts so px assertions match the artboard (same pattern as the 2026-07-22 measurement harness):

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/x01/dossedart_x01_active_card.dart';
import 'package:dart_scoring/utils/dossedart_player_accents.dart';

Future<void> _loadRealFonts() async {
  for (final (family, path) in [
    ('PressStart2P', 'assets/fonts/PressStart2P-Regular.ttf'),
    ('VT323', 'assets/fonts/VT323-Regular.ttf'),
  ]) {
    final bytes = File(path).readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadRealFonts);

  List<X01Standing> six({bool tied = false}) => [
        for (final (i, (name, rem)) in [
          ('Jonas', 60),
          ('Tor', 89),
          ('Live', 141),
          ('Mia', 218),
          ('Andreas', 264),
          ('Per', 301),
        ].indexed)
          X01Standing(
              name: name,
              accent: dossedartAccent(i),
              remaining: tied ? 501 : rem,
              isActive: i == 2),
      ];

  Widget host(DossedartX01ActiveCard card) => MaterialApp(
      home: Scaffold(body: Column(children: [card])));

  DossedartX01ActiveCard card({
    String name = 'Live',
    String? last = 'T20 · 20 · —',
    int? lastSum = 80,
    double? avg = 58.4,
    int? hit = 61,
    String? tip = 'T20 T19 D12',
    List<X01Standing>? standings,
  }) =>
      DossedartX01ActiveCard(
        playerName: name,
        avatarPath: null,
        accentColor: dossedartAccent(2),
        remaining: 141,
        currentDartIndex: 2,
        lastTurnLabel: last,
        lastTurnSum: lastSum,
        checkoutTip: tip,
        avg: avg,
        hitPercent: hit,
        standings: standings ?? six(),
      );

  testWidgets('272px zone in every stress state — the regression pin',
      (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final states = <String, DossedartX01ActiveCard>{
      'max (6 players + checkout)': card(),
      'no checkout': card(tip: null),
      'first dart (all placeholders)': card(
          last: null, lastSum: null, avg: null, hit: null, tip: null,
          standings: six(tied: true)),
      'long name': card(name: 'Alexander the boss bitch'),
    };
    for (final entry in states.entries) {
      await tester.pumpWidget(host(entry.value));
      final h = tester.getSize(find.byType(DossedartX01ActiveCard)).height;
      expect(h, 272.0, reason: 'zone height in state "${entry.key}"');
    }
  });

  testWidgets('TO WIN delta vs leader; YOU LEAD when lowest; TIED at start',
      (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(card())); // active Live 141, leader 60
    expect(find.text('▲ 81'), findsOneWidget);
    expect(find.text('👑'), findsOneWidget); // unique leader Jonas

    final leading = [
      X01Standing(name: 'Live', accent: dossedartAccent(0), remaining: 40, isActive: true),
      X01Standing(name: 'Tor', accent: dossedartAccent(1), remaining: 89),
    ];
    await tester.pumpWidget(host(card(standings: leading)));
    expect(find.text('YOU LEAD'), findsOneWidget);

    await tester.pumpWidget(host(card(standings: six(tied: true))));
    expect(find.text('TIED'), findsOneWidget);
    expect(find.text('👑'), findsNothing); // no crown on a shared lead
  });

  testWidgets('empty checkout renders a dimmed placeholder, never collapses',
      (tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(card(tip: null)));
    expect(find.text('— — —'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/dossedart_x01_active_card_test.dart`
Expected: FAIL — `X01Standing`, `hitPercent`, `standings` are not defined on the current card.

- [ ] **Step 3: Rewrite the card**

Full replacement of `dossedart_x01_active_card.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';
import '../overview/dossedart_overview_header.dart';
import '../overview/dossedart_standings_rail.dart';

/// One row of X01 standings data; the card sorts and ranks internally.
class X01Standing {
  const X01Standing({
    required this.name,
    required this.accent,
    required this.remaining,
    this.isActive = false,
  });

  final String name;
  final Color accent;
  final int remaining;
  final bool isActive;
}

/// X01 overview card — rail-B fasit (design_handoff_x01_overview,
/// approved 2026-07-22). Fixed 250px card in a 272px zone (margins 12/10):
/// grammar header + REMAINING 60px · left column LAST / AVG+HIT% / CHECKOUT
/// (always rendered, dim 0.34 when empty) · 300px standings rail with the
/// TO WIN delta. This card is the template the other cockpits restyle onto.
class DossedartX01ActiveCard extends StatelessWidget {
  const DossedartX01ActiveCard({
    super.key,
    required this.playerName,
    required this.avatarPath,
    required this.accentColor,
    required this.remaining,
    required this.currentDartIndex,
    required this.lastTurnLabel,
    required this.lastTurnSum,
    required this.checkoutTip,
    required this.standings,
    this.avg,
    this.hitPercent,
  });

  final String playerName;
  final String? avatarPath;
  final Color accentColor;
  final int remaining;
  final int currentDartIndex; // darts thrown this turn, 0..3
  final String? lastTurnLabel;
  final int? lastTurnSum;
  final String? checkoutTip;
  final double? avg;
  final int? hitPercent; // 0-100; share of this leg's darts on the board
  final List<X01Standing> standings;

  static String _formatAvg(double avg) {
    final s = avg.toStringAsFixed(1);
    return s.length > 4 ? avg.toStringAsFixed(0) : s;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...standings]..sort((a, b) => a.remaining.compareTo(b.remaining));
    final lead = sorted.first.remaining;
    final uniqueLeader =
        sorted.where((s) => s.remaining == lead).length == 1;
    final active = sorted.firstWhere((s) => s.isActive, orElse: () => sorted.first);
    final delta = active.remaining - lead;
    final toWin = delta == 0
        ? (uniqueLeader && active.remaining == lead ? 'YOU LEAD' : 'TIED')
        : '▲ $delta';

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      height: 250,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: DossedartTokens.surface,
        border: Border.all(color: accentColor, width: 3),
        boxShadow: [
          BoxShadow(color: accentColor.withValues(alpha: 0.25), blurRadius: 14),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DossedartOverviewHeader(
            playerName: playerName,
            avatarPath: avatarPath,
            accent: accentColor,
            dartsThrown: currentDartIndex,
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'REMAINING',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                    color: Colors.white.withValues(alpha: 0.55),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$remaining',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 60,
                    color: accentColor,
                    height: 1,
                    letterSpacing: -2,
                    shadows: [
                      Shadow(
                          color: accentColor.withValues(alpha: 0.66),
                          blurRadius: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _helperRow(
                        label: 'LAST',
                        value: lastTurnLabel != null
                            ? '$lastTurnLabel  = ${lastTurnSum ?? 0}'
                            : '— · — · —',
                        color: DossedartTokens.yellow,
                        dim: lastTurnLabel == null,
                      ),
                      _helperRow(
                        label: 'AVG',
                        value: avg != null ? _formatAvg(avg!) : '—',
                        color: Colors.white,
                        dim: avg == null,
                        extraLabel: 'HIT%',
                        extraValue: hitPercent != null ? '$hitPercent%' : '—',
                        extraColor: DossedartTokens.cyan,
                        extraDim: hitPercent == null,
                      ),
                      _helperRow(
                        label: 'CHECKOUT',
                        value: checkoutTip != null ? '▶ $checkoutTip' : '— — —',
                        color: DossedartTokens.green,
                        dim: checkoutTip == null,
                        mono: checkoutTip != null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                DossedartStandingsRail(
                  entries: [
                    for (final s in sorted)
                      DossedartRailEntry(
                        name: s.name,
                        accent: s.accent,
                        value: '${s.remaining}',
                        isActive: s.isActive,
                        isLeader: uniqueLeader && s.remaining == lead,
                      ),
                  ],
                  bottomLabel: 'TO WIN',
                  bottomValue: toWin,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One oche-legible helper row: label PS-9 + value VT-26 (fasit), dimmed
  /// to 0.34 with a placeholder when empty — always rendered (rule 2).
  Widget _helperRow({
    required String label,
    required String value,
    required Color color,
    required bool dim,
    bool mono = false,
    String? extraLabel,
    String? extraValue,
    Color? extraColor,
    bool extraDim = false,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 38),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 9,
                color: Colors.white.withValues(alpha: 0.5),
                letterSpacing: 1,
              ),
            ),
          ),
          Flexible(
            child: Opacity(
              opacity: dim ? 0.34 : 1,
              child: Text(
                value,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: mono && !dim ? 'PressStart2P' : 'VT323',
                  fontSize: mono && !dim ? 14 : 26,
                  height: 1,
                  letterSpacing: 1,
                  color: dim ? Colors.white : color,
                  shadows: dim
                      ? null
                      : [Shadow(color: color.withValues(alpha: 0.4), blurRadius: 8)],
                ),
              ),
            ),
          ),
          if (extraLabel != null) ...[
            const SizedBox(width: 22),
            Text(
              extraLabel,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 9,
                color: Colors.white.withValues(alpha: 0.5),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 8),
            Opacity(
              opacity: extraDim ? 0.34 : 1,
              child: Text(
                extraValue ?? '—',
                style: TextStyle(
                  fontFamily: 'VT323',
                  fontSize: 26,
                  height: 1,
                  letterSpacing: 1,
                  color: extraDim ? Colors.white : (extraColor ?? Colors.white),
                  shadows: extraDim || extraColor == null
                      ? null
                      : [Shadow(color: extraColor.withValues(alpha: 0.4), blurRadius: 8)],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/dossedart_x01_active_card_test.dart`
Expected: PASS (3 tests). The height pin is the one most likely to need a
nudge: if a state exceeds 250px inside, reduce interior spacing (the
`SizedBox(height: 8)` after the header, then the helper rows' `minHeight`),
never the margins or the 250 — the 272 zone is fasit.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/dossedart/x01/dossedart_x01_active_card.dart test/widgets/dossedart_x01_active_card_test.dart
git commit -m "feat(x01): rail-B overview card - fixed 272px zone, standings rail, TO WIN, HIT%"
```

---

### Task 4: game_screen wiring — accents, HIT%, standings

**Files:**
- Modify: `lib/screens/game_screen.dart` (the `_buildDossedartCockpit` method, ~line 1506, and the `DossedartX01ActiveCard(...)` call ~line 1538)
- Test: existing suites (`flutter test`) — integration cockpit test `integration_test/dossedart/x01_cockpit_test.dart` runs on CI.

**Interfaces:**
- Consumes: `X01Standing` and the new card API (Task 3); `dossedartAccent(int)` from `lib/utils/dossedart_player_accents.dart` (existing).
- Produces: nothing new — this task ships the visible feature.

- [ ] **Step 1: Add the import**

In `game_screen.dart`'s import block:

```dart
import '../utils/dossedart_player_accents.dart';
```

- [ ] **Step 2: Compute HIT% and standings in `_buildDossedartCockpit`**

After the existing `avg` computation (~line 1522), add:

```dart
    // HIT% (approved 2026-07-22): share of this leg's darts that hit the
    // board at all — misses (segment 0) drag it down. Same data window as AVG.
    final hitPercent = activeThrows.isEmpty
        ? null
        : (activeThrows.where((t) => t.segment > 0).length /
                activeThrows.length *
                100)
            .round();

    final standings = [
      for (var i = 0; i < players.length; i++)
        X01Standing(
          name: players[i].name,
          accent: dossedartAccent(i),
          remaining: players[i].score,
          isActive: i == currentPlayerIndex,
        ),
    ];
```

- [ ] **Step 3: Update the card call**

Replace the `DossedartX01ActiveCard(...)` construction (and delete the
"One-colour logic (locked design rule)" comment — the rule is superseded by
grammar rule 3, per-player accents):

```dart
              DossedartX01ActiveCard(
                playerName: player.name,
                avatarPath: player.avatarPath,
                // Grammar rule 3 (2026-07-22): the active thrower carries
                // their own accent; locked-cyan is retired.
                accentColor: dossedartAccent(currentPlayerIndex),
                remaining: player.score,
                currentDartIndex: dartsInTurn,
                lastTurnLabel: lastLabel.isEmpty ? null : lastLabel,
                lastTurnSum: lastLabel.isEmpty ? null : lastSum,
                checkoutTip: tip.isEmpty ? null : tip,
                avg: avg,
                hitPercent: hitPercent,
                standings: standings,
              ),
```

- [ ] **Step 4: Fix stale usages**

Run: `flutter analyze`
Then grep for other constructions of the old API and update them the same way:

Run: `grep -rn "DossedartX01ActiveCard(" lib/ test/ integration_test/`
Expected call sites: `game_screen.dart` (done above); any test/integration
fixture found must be updated to pass `standings:` (minimum one active
`X01Standing`) and may pass `hitPercent: null`.

- [ ] **Step 5: Run the full suite**

Run: `flutter analyze && flutter test`
Expected: analyze clean; all tests pass. If `integration_test/dossedart/x01_cockpit_test.dart` asserts the old cyan accent or old card layout, update its expectations to the new grammar (accent = `dossedartAccent(currentPlayerIndex)`, `TO WIN` present).

- [ ] **Step 6: Commit**

```bash
git add lib/screens/game_screen.dart
git commit -m "feat(x01): wire rail-B card - per-player accent, HIT%, standings data"
```

---

### Task 5: Verification pass

**Files:** none new.

- [ ] **Step 1: Full suite + analyze**

Run: `flutter analyze && flutter test`
Expected: clean + all green.

- [ ] **Step 2: Visual sanity on the 820×1180 frame**

Run the app on the Galaxy Tab emulator (memory: tablet emulator, not phone default), start a DOSSEDART X01 game with 4+ players and confirm: card height constant between darts (board edge never moves), per-player accent follows the thrower, rail sorted with 👑 on the leader, `TO WIN ▲n` updates, checkout row dims instead of disappearing, `DART 1/3` before the first dart.

- [ ] **Step 3: Commit any fixups, then hand back**

Fixups commit as `fix(x01): <what>`. Tablet-QA (272px legibility from the oche, 120px vs 130px context for later Golf work) stays with Bjørn.
```
