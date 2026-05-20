# DOSSEDART X01 Cockpit — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the DOSSEDART X01 in-game cockpit (default state) + a Player Overview screen, gated behind the existing `use_dossedart_design` preview flag.

**Architecture:** `GameScreen.build()` branches on a new `useDossedartDesign` constructor param. The DOSSEDART branch composes new presentational widgets (CRT frame, topbar, active card, dartboard, action bar) over the unchanged `_GameScreenState` (logic shared with classic). Dartboard hit-test bands match visual ring widths exactly — no surprise misses.

**Tech Stack:** Flutter (existing project), `CustomPainter` for the dartboard, `Stack`/`Positioned` for layout invariants, existing `Player`/`DartThrow` models, existing `_onDartHit`/`_onMiss`/`_undo` methods on `_GameScreenState`.

**Spec:** `docs/superpowers/specs/2026-05-20-dossedart-x01-cockpit-design.md` (commits `431aff7`, `db73a14`, `892152b`).
**Locked mockups:**
- `docs/design/dossedart-handoff/PROPOSAL-cockpit-v5.html`
- `docs/design/dossedart-handoff/PROPOSAL-player-overview-v4.html`

**Working directory:** `.worktrees/dossedart-x01-cockpit` (branch `feat/dossedart-x01-cockpit`, branched from `main`).

---

## File map

**New files:**
```
lib/widgets/dossedart/
  dossedart_crt_frame.dart                 — reusable scanline + vignette + inset-bulge wrapper
  dossedart_player_avatar.dart             — square avatar (photo or silhouette) with player-color border
  x01/
    dart_zone.dart                         — DartZone sum-type (single/double/triple per N + bull/dBull/miss)
    dossedart_x01_topbar.dart              — ◀ EXIT · title · L 1/3 · RND 7
    dossedart_x01_active_card.dart         — avatar, name, dart-dots, remaining, last turn, checkout-tip
    dossedart_x01_dartboard.dart           — CustomPainter board + hit-test via polar coordinates
    dossedart_x01_action_bar.dart          — ↶ UNDO · ✗ MISS · ⋯ MENU

lib/screens/dossedart/x01/
    dossedart_player_overview_screen.dart  — arcade scoreboard with all players

test/widgets/dossedart/x01/
    dossedart_x01_topbar_test.dart
    dossedart_x01_active_card_test.dart
    dossedart_x01_dartboard_test.dart
    dossedart_x01_action_bar_test.dart

integration_test/dossedart/
    x01_cockpit_test.dart                  — smoke: cockpit renders + MENU → Player Overview navigation
```

**Modified files:**
- `lib/screens/game_screen.dart` — adds `useDossedartDesign` constructor param + `_buildDossedartCockpit()` branch; existing build tree extracted unchanged into `_buildClassicScaffold()`. No logic edits.
- `lib/screens/dossedart/dossedart_x01_setup_screen.dart` — passes `useDossedartDesign: true` to GameScreen.

---

## Task 1: Worktree setup

**Files:** none (git operations)

- [ ] **Step 1.1: Create the worktree**

```bash
git worktree add -b feat/dossedart-x01-cockpit .worktrees/dossedart-x01-cockpit main
```
Expected: `Preparing worktree (new branch 'feat/dossedart-x01-cockpit')`.

- [ ] **Step 1.2: Switch to it for all later steps**

```bash
cd .worktrees/dossedart-x01-cockpit
```

- [ ] **Step 1.3: Baseline analyzer + widget tests**

```bash
flutter pub get
flutter analyze
flutter test test/
```
Expected: `No issues found!` and `All tests passed!`. If anything fails, stop and report (the branch should start clean since lint cleanup landed in PR #7).

---

## Task 2: DartZone model

**Files:**
- Create: `lib/widgets/dossedart/x01/dart_zone.dart`
- Test: `test/widgets/dossedart/x01/dart_zone_test.dart`

The dartboard taps need to produce one of these zones:
- `single(int n)` for n in 1..20
- `double(int n)` for n in 1..20
- `triple(int n)` for n in 1..20
- `bull` (outer bull = 25 single)
- `dBull` (inner bull = 50, counts as a double for double-out)
- `miss` (outside or non-tappable label band)

The widget converts a zone to `(segment, multiplier)` for `_onDartHit(segment, multiplier)`.

- [ ] **Step 2.1: Write the test**

Create `test/widgets/dossedart/x01/dart_zone_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/x01/dart_zone.dart';

void main() {
  group('DartZone.toSegmentMultiplier', () {
    test('single 20 → (20, 1)', () {
      expect(const DartZone.single(20).toSegmentMultiplier(), (20, 1));
    });
    test('double 16 → (16, 2)', () {
      expect(const DartZone.double_(16).toSegmentMultiplier(), (16, 2));
    });
    test('triple 19 → (19, 3)', () {
      expect(const DartZone.triple(19).toSegmentMultiplier(), (19, 3));
    });
    test('bull → (25, 1)', () {
      expect(const DartZone.bull().toSegmentMultiplier(), (25, 1));
    });
    test('dBull → (25, 2)', () {
      expect(const DartZone.dBull().toSegmentMultiplier(), (25, 2));
    });
    test('miss → (0, 1)', () {
      expect(const DartZone.miss().toSegmentMultiplier(), (0, 1));
    });
  });
}
```

- [ ] **Step 2.2: Run the test to verify it fails**

```bash
flutter test test/widgets/dossedart/x01/dart_zone_test.dart
```
Expected: FAIL — `Target of URI doesn't exist: 'package:dart_scoring/widgets/dossedart/x01/dart_zone.dart'`.

- [ ] **Step 2.3: Implement DartZone**

Create `lib/widgets/dossedart/x01/dart_zone.dart`:

```dart
/// A region on the DOSSEDART dartboard that a tap can resolve to.
///
/// Use [toSegmentMultiplier] to feed the result into the existing
/// `_GameScreenState._onDartHit(int segment, int multiplier)` API.
sealed class DartZone {
  const DartZone();

  const factory DartZone.single(int n) = _Single;
  const factory DartZone.double_(int n) = _Double;
  const factory DartZone.triple(int n) = _Triple;
  const factory DartZone.bull() = _Bull;
  const factory DartZone.dBull() = _DBull;
  const factory DartZone.miss() = _Miss;

  /// (segment, multiplier) pair for the production scoring engine.
  /// MISS maps to (0, 1) so points = 0 * 1 = 0.
  (int, int) toSegmentMultiplier();
}

class _Single extends DartZone {
  const _Single(this.n);
  final int n;
  @override
  (int, int) toSegmentMultiplier() => (n, 1);
}

class _Double extends DartZone {
  const _Double(this.n);
  final int n;
  @override
  (int, int) toSegmentMultiplier() => (n, 2);
}

class _Triple extends DartZone {
  const _Triple(this.n);
  final int n;
  @override
  (int, int) toSegmentMultiplier() => (n, 3);
}

class _Bull extends DartZone {
  const _Bull();
  @override
  (int, int) toSegmentMultiplier() => (25, 1);
}

class _DBull extends DartZone {
  const _DBull();
  @override
  (int, int) toSegmentMultiplier() => (25, 2);
}

class _Miss extends DartZone {
  const _Miss();
  @override
  (int, int) toSegmentMultiplier() => (0, 1);
}
```

- [ ] **Step 2.4: Run test, expect PASS**

```bash
flutter test test/widgets/dossedart/x01/dart_zone_test.dart
flutter analyze lib/widgets/dossedart/x01/dart_zone.dart
```
Expected: PASS + `No issues found!`.

- [ ] **Step 2.5: Commit**

```bash
git add lib/widgets/dossedart/x01/dart_zone.dart test/widgets/dossedart/x01/dart_zone_test.dart
git commit -m "feat(dossedart): DartZone sum-type for dartboard hit-testing"
```

---

## Task 3: DossedartCrtFrame widget

**Files:**
- Create: `lib/widgets/dossedart/dossedart_crt_frame.dart`

Wraps any child with the shared DOSSEDART CRT effects: scanlines, vignette, inset shadows, optional decorative scan-beam (off by default in tests via the existing `ArcadeFrame.disableBeamForTest` flag).

For this iteration we reuse the existing `ArcadeFrame` (already implements scanlines + vignette + beam). `DossedartCrtFrame` adds the inset-bulge box-shadows + border-radius styling — and is just a thin wrapper that puts a child inside an `ArcadeFrame` plus a `DecoratedBox` with the inset shadows.

- [ ] **Step 3.1: Create the widget**

Create `lib/widgets/dossedart/dossedart_crt_frame.dart`:

```dart
import 'package:flutter/material.dart';
import '../../theme/dossedart_tokens.dart';
import 'arcade_frame.dart';

/// Wraps a screen body with the DOSSEDART CRT treatment:
/// - ArcadeFrame (scanlines, vignette, scan-beam)
/// - Inset shadows simulating CRT-glass corner-darkening
/// - 16px border radius on the inner frame
///
/// The "physical bezel" shown in design mockups (grey plastic surround
/// with power LED) is decorative-only in the mockup; in Flutter we
/// convey the CRT feel via inset shadows alone.
class DossedartCrtFrame extends StatelessWidget {
  const DossedartCrtFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DossedartTokens.bg,
      child: Stack(
        children: [
          Positioned.fill(child: ArcadeFrame(child: child)),
          // Inset shadow overlay (CRT glass-bulge darkening)
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xB3000000), // 70% black
                      blurRadius: 60,
                      spreadRadius: -30,
                      offset: Offset.zero,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3.2: Analyze**

```bash
flutter analyze lib/widgets/dossedart/dossedart_crt_frame.dart
```
Expected: No issues found.

- [ ] **Step 3.3: Commit**

```bash
git add lib/widgets/dossedart/dossedart_crt_frame.dart
git commit -m "feat(dossedart): DossedartCrtFrame wrapper (ArcadeFrame + inset bulge)"
```

---

## Task 4: DossedartPlayerAvatar widget

**Files:**
- Create: `lib/widgets/dossedart/dossedart_player_avatar.dart`
- Test: `test/widgets/dossedart/dossedart_player_avatar_test.dart`

Square avatar (NOT round). Shows the player's photo if `avatarPath` is non-null and the file exists; otherwise falls back to a `Icons.person` silhouette inside a surface-coloured square.

- [ ] **Step 4.1: Write the widget test**

Create `test/widgets/dossedart/dossedart_player_avatar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/dossedart_player_avatar.dart';

void main() {
  testWidgets('shows Icons.person silhouette when avatarPath is null',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: DossedartPlayerAvatar(
          name: 'TEST',
          avatarPath: null,
          size: 56,
          borderColor: Color(0xFFFF00AA),
        ),
      ),
    ));
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('shows Icons.person silhouette when avatarPath does not exist',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: DossedartPlayerAvatar(
          name: 'TEST',
          avatarPath: '/nonexistent/path/to/file.jpg',
          size: 56,
          borderColor: Color(0xFFFF00AA),
        ),
      ),
    ));
    expect(find.byIcon(Icons.person), findsOneWidget);
  });
}
```

- [ ] **Step 4.2: Run the test, verify it fails**

```bash
flutter test test/widgets/dossedart/dossedart_player_avatar_test.dart
```
Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 4.3: Implement the widget**

Create `lib/widgets/dossedart/dossedart_player_avatar.dart`:

```dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Square avatar with a 2-3px player-color border. Shows the photo
/// when available, falls back to an Icons.person silhouette.
///
/// Used by the DOSSEDART cockpit active card and Player Overview rows.
/// Square shape and the per-player border colour are the DOSSEDART
/// look — different from the round CircleAvatar that `PlayerAvatar` uses.
class DossedartPlayerAvatar extends StatelessWidget {
  const DossedartPlayerAvatar({
    super.key,
    required this.name,
    required this.size,
    required this.borderColor,
    this.avatarPath,
    this.borderWidth = 3,
  });

  final String name;
  final double size;
  final Color borderColor;
  final String? avatarPath;
  final double borderWidth;

  bool _hasPhoto() {
    if (avatarPath == null || avatarPath!.isEmpty || kIsWeb) return false;
    return File(avatarPath!).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF2A0050),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.5),
            blurRadius: 8,
          ),
        ],
      ),
      child: _hasPhoto()
          ? Image.file(File(avatarPath!), fit: BoxFit.cover)
          : Center(
              child: Icon(
                Icons.person,
                size: size * 0.6,
                color: Colors.white,
              ),
            ),
    );
  }
}
```

- [ ] **Step 4.4: Run test, expect PASS**

```bash
flutter test test/widgets/dossedart/dossedart_player_avatar_test.dart
flutter analyze lib/widgets/dossedart/dossedart_player_avatar.dart
```
Expected: PASS + no analyzer issues.

- [ ] **Step 4.5: Commit**

```bash
git add lib/widgets/dossedart/dossedart_player_avatar.dart test/widgets/dossedart/dossedart_player_avatar_test.dart
git commit -m "feat(dossedart): DossedartPlayerAvatar (square, photo or silhouette)"
```

---

## Task 5: DossedartX01TopBar widget

**Files:**
- Create: `lib/widgets/dossedart/x01/dossedart_x01_topbar.dart`
- Test: `test/widgets/dossedart/x01/dossedart_x01_topbar_test.dart`

Top bar: `◀ EXIT` (cyan, left), centered title (yellow, ellipsizes), `L {n}/{m} · RND {r}` (right, dim). 2px magenta bottom border, black background. Press Start 2P fonts.

- [ ] **Step 5.1: Write the widget test**

Create `test/widgets/dossedart/x01/dossedart_x01_topbar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/x01/dossedart_x01_topbar.dart';

void main() {
  testWidgets('renders exit + title + leg/round', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DossedartX01TopBar(
          title: 'X01 · 501 · D-OUT',
          legIndex: 1,
          legCount: 3,
          roundNumber: 7,
          onExit: () {},
        ),
      ),
    ));
    expect(find.text('◀ EXIT'), findsOneWidget);
    expect(find.text('X01 · 501 · D-OUT'), findsOneWidget);
    expect(find.text('L 1/3 · RND 7'), findsOneWidget);
  });

  testWidgets('onExit callback fires when EXIT tapped', (tester) async {
    var exited = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DossedartX01TopBar(
          title: 'X01',
          legIndex: 1,
          legCount: 1,
          roundNumber: 1,
          onExit: () => exited = true,
        ),
      ),
    ));
    await tester.tap(find.text('◀ EXIT'));
    expect(exited, isTrue);
  });
}
```

- [ ] **Step 5.2: Run the test to verify it fails**

```bash
flutter test test/widgets/dossedart/x01/dossedart_x01_topbar_test.dart
```
Expected: FAIL.

- [ ] **Step 5.3: Implement the widget**

Create `lib/widgets/dossedart/x01/dossedart_x01_topbar.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';

/// DOSSEDART X01 cockpit top bar: ◀ EXIT · title · L n/m · RND r.
class DossedartX01TopBar extends StatelessWidget {
  const DossedartX01TopBar({
    super.key,
    required this.title,
    required this.legIndex,
    required this.legCount,
    required this.roundNumber,
    required this.onExit,
  });

  final String title;
  final int legIndex;
  final int legCount;
  final int roundNumber;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(color: DossedartTokens.magenta, width: 2),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onExit,
            child: const Text(
              '◀ EXIT',
              style: TextStyle(
                fontFamily: 'VT323',
                fontSize: 18,
                color: DossedartTokens.cyan,
                letterSpacing: 2,
                height: 1,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 11,
                  color: DossedartTokens.yellow,
                  letterSpacing: 2,
                  height: 1.3,
                ),
              ),
            ),
          ),
          Text(
            'L $legIndex/$legCount · RND $roundNumber',
            style: const TextStyle(
              fontFamily: 'VT323',
              fontSize: 14,
              color: Colors.white54,
              letterSpacing: 2,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5.4: Run test, expect PASS**

```bash
flutter test test/widgets/dossedart/x01/dossedart_x01_topbar_test.dart
flutter analyze lib/widgets/dossedart/x01/dossedart_x01_topbar.dart
```

- [ ] **Step 5.5: Commit**

```bash
git add lib/widgets/dossedart/x01/dossedart_x01_topbar.dart test/widgets/dossedart/x01/dossedart_x01_topbar_test.dart
git commit -m "feat(dossedart): DossedartX01TopBar (exit/title/leg+round)"
```

---

## Task 6: DossedartX01ActiveCard widget

**Files:**
- Create: `lib/widgets/dossedart/x01/dossedart_x01_active_card.dart`
- Test: `test/widgets/dossedart/x01/dossedart_x01_active_card_test.dart`

Active player card. Avatar + name (auto-shrinks), dart-dots (3 squares: filled = dart thrown, hollow = not), REMAINING number (big), LAST 3 throws row, optional checkout-tip strip.

- [ ] **Step 6.1: Add a name-tier helper to dart_zone.dart**

Actually a separate place is cleaner. Add it inside the active card file itself as a private function:

(see Step 6.3 — `_nameTier()` is part of the widget file)

- [ ] **Step 6.2: Write the widget test**

Create `test/widgets/dossedart/x01/dossedart_x01_active_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/x01/dossedart_x01_active_card.dart';

void main() {
  Widget harness({
    String name = 'MIA',
    int remaining = 170,
    int currentDartIndex = 2,
    String? lastTurn = 'T20 · S20 · S20',
    int? lastTurnSum = 80,
    String? checkoutTip,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: DossedartX01ActiveCard(
          playerName: name,
          avatarPath: null,
          accentColor: const Color(0xFFFF00AA),
          remaining: remaining,
          currentDartIndex: currentDartIndex,
          lastTurnLabel: lastTurn,
          lastTurnSum: lastTurnSum,
          checkoutTip: checkoutTip,
        ),
      ),
    );
  }

  testWidgets('renders name, remaining, last turn', (tester) async {
    await tester.pumpWidget(harness());
    expect(find.text('MIA'), findsOneWidget);
    expect(find.text('170'), findsOneWidget);
    expect(find.text('T20 · S20 · S20'), findsOneWidget);
    expect(find.text('= 80'), findsOneWidget);
  });

  testWidgets('hides checkout-tip when null', (tester) async {
    await tester.pumpWidget(harness());
    expect(find.textContaining('▶'), findsNothing);
  });

  testWidgets('shows checkout-tip when provided', (tester) async {
    await tester.pumpWidget(harness(checkoutTip: 'T20 › S16 › D-BULL'));
    expect(find.text('▶ T20 › S16 › D-BULL'), findsOneWidget);
  });

  testWidgets('long name does not overflow (no exception)',
      (tester) async {
    await tester.pumpWidget(harness(name: 'CHRISTOPHER ALEXANDER VON LONGNAME'));
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 6.3: Implement the widget**

Create `lib/widgets/dossedart/x01/dossedart_x01_active_card.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';
import '../dossedart_player_avatar.dart';

/// Active player card shown in the DOSSEDART X01 cockpit.
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
  });

  final String playerName;
  final String? avatarPath;
  final Color accentColor;
  final int remaining;
  final int currentDartIndex; // 0..3
  final String? lastTurnLabel; // e.g., 'T20 · S20 · S20' (null = no previous turn)
  final int? lastTurnSum;
  final String? checkoutTip;

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
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        border: Border.all(color: accentColor, width: 3),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accentColor.withValues(alpha: 0.10),
            accentColor.withValues(alpha: 0.02),
          ],
        ),
        boxShadow: [
          BoxShadow(color: accentColor.withValues(alpha: 0.25), blurRadius: 14),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: avatar + name + dart-dots
          Row(
            children: [
              DossedartPlayerAvatar(
                name: playerName,
                avatarPath: avatarPath,
                size: 56,
                borderColor: accentColor,
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
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (int i = 0; i < 3; i++) ...[
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: i < currentDartIndex ? accentColor : Colors.transparent,
                              border: Border.all(color: accentColor, width: 2),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          'DART $currentDartIndex/3',
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
            ],
          ),
          // Row 2: REMAINING label + big number
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'REMAINING',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 9,
                  color: Colors.white70,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                '$remaining',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 60,
                  color: accentColor,
                  letterSpacing: 2,
                  height: 1,
                  shadows: [
                    Shadow(color: accentColor.withValues(alpha: 0.7), blurRadius: 16),
                  ],
                ),
              ),
            ],
          ),
          // Row 3: last turn (above dashed separator)
          if (lastTurnLabel != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: accentColor.withValues(alpha: 0.4),
                    width: 1,
                    style: BorderStyle.solid, // Flutter has no dashed; rendered as solid thin
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'LAST',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 9,
                      color: Colors.white70,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      lastTurnLabel!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'VT323',
                        fontSize: 20,
                        color: DossedartTokens.yellow,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  if (lastTurnSum != null)
                    Text(
                      '= $lastTurnSum',
                      style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 13,
                        color: DossedartTokens.yellow,
                        letterSpacing: 1,
                      ),
                    ),
                ],
              ),
            ),
          ],
          // Row 4: checkout tip
          if (checkoutTip != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: DossedartTokens.green.withValues(alpha: 0.06),
                border: Border.all(color: DossedartTokens.green, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: DossedartTokens.green.withValues(alpha: 0.4),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Text(
                '▶ $checkoutTip',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: DossedartTokens.green,
                  letterSpacing: 1,
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

- [ ] **Step 6.4: Run tests + analyzer**

```bash
flutter test test/widgets/dossedart/x01/dossedart_x01_active_card_test.dart
flutter analyze lib/widgets/dossedart/x01/dossedart_x01_active_card.dart
```
Expected: PASS, no issues.

- [ ] **Step 6.5: Commit**

```bash
git add lib/widgets/dossedart/x01/dossedart_x01_active_card.dart test/widgets/dossedart/x01/dossedart_x01_active_card_test.dart
git commit -m "feat(dossedart): DossedartX01ActiveCard (avatar/name/dots/remaining/last/checkout)"
```

---

## Task 7: DossedartX01ActionBar widget

**Files:**
- Create: `lib/widgets/dossedart/x01/dossedart_x01_action_bar.dart`
- Test: `test/widgets/dossedart/x01/dossedart_x01_action_bar_test.dart`

Three buttons: UNDO (magenta border, flex 1), MISS (filled orange, flex 2 primary), MENU (cyan border, flex 1).

- [ ] **Step 7.1: Write the widget test**

Create `test/widgets/dossedart/x01/dossedart_x01_action_bar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/x01/dossedart_x01_action_bar.dart';

void main() {
  testWidgets('renders all three labels', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DossedartX01ActionBar(
          onUndo: () {},
          onMiss: () {},
          onMenu: () {},
        ),
      ),
    ));
    expect(find.text('↶ UNDO'), findsOneWidget);
    expect(find.text('✗ MISS'), findsOneWidget);
    expect(find.text('⋯ MENU'), findsOneWidget);
  });

  testWidgets('callbacks fire on tap', (tester) async {
    var u = false, m = false, x = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DossedartX01ActionBar(
          onUndo: () => u = true,
          onMiss: () => m = true,
          onMenu: () => x = true,
        ),
      ),
    ));
    await tester.tap(find.text('↶ UNDO'));
    await tester.tap(find.text('✗ MISS'));
    await tester.tap(find.text('⋯ MENU'));
    expect(u, isTrue);
    expect(m, isTrue);
    expect(x, isTrue);
  });
}
```

- [ ] **Step 7.2: Run test to verify it fails**

```bash
flutter test test/widgets/dossedart/x01/dossedart_x01_action_bar_test.dart
```
Expected: FAIL.

- [ ] **Step 7.3: Implement the widget**

Create `lib/widgets/dossedart/x01/dossedart_x01_action_bar.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';

class DossedartX01ActionBar extends StatelessWidget {
  const DossedartX01ActionBar({
    super.key,
    required this.onUndo,
    required this.onMiss,
    required this.onMenu,
  });

  final VoidCallback onUndo;
  final VoidCallback onMiss;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: DossedartTokens.yellow, width: 2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: _Btn(
              label: '↶ UNDO',
              borderColor: DossedartTokens.magenta,
              fg: Colors.white,
              onTap: onUndo,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _Btn(
              label: '✗ MISS',
              borderColor: Colors.white,
              bg: DossedartTokens.orange,
              fg: Colors.black,
              onTap: onMiss,
              glow: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: _Btn(
              label: '⋯ MENU',
              borderColor: DossedartTokens.cyan,
              fg: DossedartTokens.cyan,
              onTap: onMenu,
            ),
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({
    required this.label,
    required this.borderColor,
    required this.fg,
    required this.onTap,
    this.bg,
    this.glow = false,
  });

  final String label;
  final Color borderColor;
  final Color fg;
  final VoidCallback onTap;
  final Color? bg;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: borderColor, width: 2),
          boxShadow: glow
              ? [BoxShadow(color: DossedartTokens.orange.withValues(alpha: 0.55), blurRadius: 16)]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 11,
            color: fg,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 7.4: Run tests + analyzer**

```bash
flutter test test/widgets/dossedart/x01/dossedart_x01_action_bar_test.dart
flutter analyze lib/widgets/dossedart/x01/dossedart_x01_action_bar.dart
```
Expected: PASS.

- [ ] **Step 7.5: Commit**

```bash
git add lib/widgets/dossedart/x01/dossedart_x01_action_bar.dart test/widgets/dossedart/x01/dossedart_x01_action_bar_test.dart
git commit -m "feat(dossedart): DossedartX01ActionBar (undo/miss/menu)"
```

---

## Task 8: DossedartX01Dartboard — geometry + render + hit-test

**Files:**
- Create: `lib/widgets/dossedart/x01/dossedart_x01_dartboard.dart`
- Test: `test/widgets/dossedart/x01/dossedart_x01_dartboard_test.dart`

The big one. CustomPainter draws the segments. `GestureDetector` with `onTapUp` converts the local position to polar coordinates and picks the zone.

**Geometry constants (radii as fractions of board radius):**

| Threshold | Value |
|---|---|
| `kDBullR` | 0.05 |
| `kBullR` | 0.12 |
| `kInnerSingleR` | 0.47 |
| `kTripleR` | 0.58 |
| `kOuterSingleR` | 0.82 |
| `kDoubleR` | 0.95 |
| `kEdgeR` | 1.00 |

**Segment ordering (starting at 20, top; clockwise):**
`[20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]`

- [ ] **Step 8.1: Write the hit-test tests first**

Create `test/widgets/dossedart/x01/dossedart_x01_dartboard_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/x01/dart_zone.dart';
import 'package:dart_scoring/widgets/dossedart/x01/dossedart_x01_dartboard.dart';

void main() {
  group('hit-test', () {
    // Board has radius 100 in unit space; centre at (0,0).
    // Angles: 0° = top (12 o'clock), clockwise positive.

    test('centre tap → dBull', () {
      expect(zoneForPolar(0, 0), const DartZone.dBull());
    });

    test('inside bull ring (r=0.10) → bull', () {
      expect(zoneForPolar(0.10, 0), const DartZone.bull());
    });

    test('inner single at top (r=0.30, angle 0) → single 20', () {
      expect(zoneForPolar(0.30, 0), const DartZone.single(20));
    });

    test('triple ring at top (r=0.52, angle 0) → triple 20', () {
      expect(zoneForPolar(0.52, 0), const DartZone.triple(20));
    });

    test('outer single at top (r=0.70, angle 0) → single 20', () {
      expect(zoneForPolar(0.70, 0), const DartZone.single(20));
    });

    test('double ring at top (r=0.90, angle 0) → double 20', () {
      expect(zoneForPolar(0.90, 0), const DartZone.double_(20));
    });

    test('label band (r=0.98) → miss', () {
      expect(zoneForPolar(0.98, 0), const DartZone.miss());
    });

    test('outside the board (r=1.1) → miss', () {
      expect(zoneForPolar(1.1, 0), const DartZone.miss());
    });

    test('right side (angle 90°) → segment 6', () {
      // Per standard ordering, segment 90° clockwise from top is 6.
      expect(zoneForPolar(0.30, 90), const DartZone.single(6));
    });

    test('bottom (angle 180°) → segment 3', () {
      expect(zoneForPolar(0.30, 180), const DartZone.single(3));
    });
  });

  testWidgets('GestureDetector fires onTap with computed zone',
      (tester) async {
    DartZone? lastZone;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            height: 320,
            child: DossedartX01Dartboard(
              onTap: (z) => lastZone = z,
            ),
          ),
        ),
      ),
    ));
    // Tap dead-centre: dBull.
    await tester.tapAt(tester.getCenter(find.byType(DossedartX01Dartboard)));
    expect(lastZone, const DartZone.dBull());
  });
}
```

- [ ] **Step 8.2: Run tests to verify they fail**

```bash
flutter test test/widgets/dossedart/x01/dossedart_x01_dartboard_test.dart
```
Expected: FAIL — `zoneForPolar` undefined and `DossedartX01Dartboard` doesn't exist.

- [ ] **Step 8.3: Implement the widget + hit-test**

Create `lib/widgets/dossedart/x01/dossedart_x01_dartboard.dart`:

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';
import 'dart_zone.dart';

/// Standard dart segment order starting at 20 (top), going clockwise.
const List<int> kSegmentOrder = [
  20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5,
];

// Radius thresholds as fractions of board radius.
// Visual = hit-test (no surprise misses).
const double kDBullR = 0.05;
const double kBullR = 0.12;
const double kInnerSingleR = 0.47;
const double kTripleR = 0.58;
const double kOuterSingleR = 0.82;
const double kDoubleR = 0.95;

/// Resolve a tap at polar (r, angleDeg) — r as a fraction of board
/// radius, angleDeg measured clockwise from 12 o'clock — to a DartZone.
DartZone zoneForPolar(double r, double angleDeg) {
  if (r <= kDBullR) return const DartZone.dBull();
  if (r <= kBullR) return const DartZone.bull();
  if (r > kDoubleR) return const DartZone.miss();

  // Normalise angle to [0, 360).
  double a = angleDeg % 360;
  if (a < 0) a += 360;
  // Each segment is 18°, centred on its number. Segment 0 (the "20"
  // segment) spans [-9°, 9°). So shift by +9° to make segment 0 start at 0°.
  final segIdx = ((a + 9) % 360 / 18).floor();
  final n = kSegmentOrder[segIdx];

  if (r <= kInnerSingleR) return DartZone.single(n);
  if (r <= kTripleR) return DartZone.triple(n);
  if (r <= kOuterSingleR) return DartZone.single(n);
  return DartZone.double_(n);
}

/// Renders the DOSSEDART arcade dartboard and reports taps as DartZones.
/// The widget fills its available space; wrap in an AspectRatio(1) to
/// keep it square.
class DossedartX01Dartboard extends StatelessWidget {
  const DossedartX01Dartboard({super.key, required this.onTap});

  final ValueChanged<DartZone> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onTapUp: (details) {
            final centre = Offset(size / 2, size / 2);
            final offset = details.localPosition - centre;
            final boardRadius = size / 2;
            final r = offset.distance / boardRadius;
            final angleRad = math.atan2(offset.dx, -offset.dy); // 12 o'clock = 0, CW positive
            final angleDeg = angleRad * 180 / math.pi;
            onTap(zoneForPolar(r, angleDeg));
          },
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(painter: _DartboardPainter()),
          ),
        );
      },
    );
  }
}

class _DartboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);

    // Outer frame (magenta border + glow already comes from surrounding
    // BoxDecoration on the parent; here we just fill background).
    final bg = Paint()..color = DossedartTokens.surface;
    canvas.drawCircle(c, r, bg);

    const slice = math.pi * 2 / 20;
    for (int i = 0; i < 20; i++) {
      final start = -slice / 2 + i * slice - math.pi / 2;
      final end = start + slice;
      final segCol = (i % 2 == 0)
          ? DossedartTokens.magenta.withValues(alpha: 0.35)
          : DossedartTokens.cyan.withValues(alpha: 0.35);

      _wedge(canvas, c, r * kBullR, r * kInnerSingleR, start, end, segCol);
      _wedge(canvas, c, r * kInnerSingleR, r * kTripleR, start, end, DossedartTokens.green);
      _wedge(canvas, c, r * kTripleR, r * kOuterSingleR, start, end, segCol);
      _wedge(canvas, c, r * kOuterSingleR, r * kDoubleR, start, end, DossedartTokens.yellow);
      _wedge(canvas, c, r * kDoubleR, r, start, end, DossedartTokens.bg);

      // Segment number label, placed in the outer band.
      final midAng = (start + end) / 2;
      final lx = c.dx + math.cos(midAng) * r * 0.975;
      final ly = c.dy + math.sin(midAng) * r * 0.975;
      final n = kSegmentOrder[i];
      final tp = TextPainter(
        text: TextSpan(
          text: '$n',
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 11,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
    }

    // Bull / D-Bull
    canvas.drawCircle(c, r * kBullR, Paint()..color = DossedartTokens.orange);
    canvas.drawCircle(c, r * kDBullR, Paint()..color = DossedartTokens.red);

    // White stroke around bulls
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(c, r * kBullR, stroke);
    canvas.drawCircle(c, r * kDBullR, stroke);

    // Magenta border ring
    final border = Paint()
      ..color = DossedartTokens.magenta
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(c, r - 1.5, border);
  }

  void _wedge(Canvas canvas, Offset c, double rInner, double rOuter,
      double startAng, double endAng, Color fill) {
    final path = Path()
      ..moveTo(c.dx + math.cos(startAng) * rInner, c.dy + math.sin(startAng) * rInner)
      ..lineTo(c.dx + math.cos(startAng) * rOuter, c.dy + math.sin(startAng) * rOuter)
      ..arcTo(
        Rect.fromCircle(center: c, radius: rOuter),
        startAng, endAng - startAng, false,
      )
      ..lineTo(c.dx + math.cos(endAng) * rInner, c.dy + math.sin(endAng) * rInner)
      ..arcTo(
        Rect.fromCircle(center: c, radius: rInner),
        endAng, -(endAng - startAng), false,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
  }

  @override
  bool shouldRepaint(_DartboardPainter oldDelegate) => false;
}
```

- [ ] **Step 8.4: Run tests + analyzer**

```bash
flutter test test/widgets/dossedart/x01/dossedart_x01_dartboard_test.dart
flutter analyze lib/widgets/dossedart/x01/dossedart_x01_dartboard.dart
```
Expected: ALL PASS. If a specific angle-segment test fails, the segment-index calculation in `zoneForPolar` may need a +/- 1 adjustment — the "20 segment spans -9°..+9°" interpretation is correct; verify against the test for "right side (90°) → 6".

- [ ] **Step 8.5: Commit**

```bash
git add lib/widgets/dossedart/x01/dossedart_x01_dartboard.dart test/widgets/dossedart/x01/dossedart_x01_dartboard_test.dart
git commit -m "feat(dossedart): DossedartX01Dartboard (geometry + hit-test)"
```

---

## Task 9: DossedartPlayerOverviewScreen

**Files:**
- Create: `lib/screens/dossedart/x01/dossedart_player_overview_screen.dart`

The arcade scoreboard screen pushed from the cockpit's MENU. Inputs: list of player view-models (already includes name, avatarPath, remaining, last turn label, last turn sum, avg, hit%, miss%). The screen does NOT compute stats — that's the cockpit's job; the screen just renders.

- [ ] **Step 9.1: Create the screen**

Create `lib/screens/dossedart/x01/dossedart_player_overview_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';
import '../../../widgets/dossedart/dossedart_crt_frame.dart';
import '../../../widgets/dossedart/dossedart_player_avatar.dart';

/// View-model for one player row in the overview.
class PlayerOverviewRow {
  const PlayerOverviewRow({
    required this.name,
    required this.avatarPath,
    required this.remaining,
    required this.lastTurnLabel,
    required this.lastTurnSum,
    required this.avg,
    required this.hitPct,
    required this.missPct,
  });

  final String name;
  final String? avatarPath;
  final int remaining;
  final String lastTurnLabel; // e.g., 'T20 · S20 · S20' or '— · — · —'
  final int lastTurnSum;
  final double avg;
  final int hitPct;
  final int missPct;
}

class DossedartPlayerOverviewScreen extends StatelessWidget {
  const DossedartPlayerOverviewScreen({
    super.key,
    required this.title,
    required this.roundNumber,
    required this.rows,
  });

  final String title; // e.g., 'CAST · X01 501'
  final int roundNumber;
  final List<PlayerOverviewRow> rows;

  static double _nameFontSize(int len) {
    if (len <= 6) return 14;
    if (len <= 10) return 12;
    return 10;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DossedartTokens.bg,
      body: DossedartCrtFrame(
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(title: title, roundNumber: roundNumber),
              const _Marquee(text: '► SCOREBOARD ◄'),
              const _ColHeader(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                  itemCount: rows.length,
                  itemBuilder: (ctx, i) => _Row(rank: i + 1, data: rows[i]),
                ),
              ),
              const _FooterMarquee(text: '★ ★ ★ INSERT DART TO CONTINUE ★ ★ ★'),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.roundNumber});
  final String title;
  final int roundNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(bottom: BorderSide(color: DossedartTokens.magenta, width: 2)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Text(
              '◀ BACK',
              style: TextStyle(
                fontFamily: 'VT323', fontSize: 18, color: DossedartTokens.cyan,
                letterSpacing: 2, height: 1,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'PressStart2P', fontSize: 11, color: DossedartTokens.yellow,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          Text(
            'RND $roundNumber',
            style: const TextStyle(
              fontFamily: 'VT323', fontSize: 14, color: Colors.white54, letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Marquee extends StatelessWidget {
  const _Marquee({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        border: const Border(bottom: BorderSide(color: Color(0x66FF00AA), width: 1)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 12,
          color: DossedartTokens.magenta,
          letterSpacing: 4,
        ),
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  const _ColHeader();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x4D00E5FF), width: 1)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 32, child: Text('#', style: _hStyle)),
          SizedBox(width: 54),
          Expanded(child: Text('PLAYER', style: _hStyle)),
          Text('REMAIN', style: _hStyle),
        ],
      ),
    );
  }

  static const _hStyle = TextStyle(
    fontFamily: 'PressStart2P', fontSize: 8, color: DossedartTokens.cyan,
    letterSpacing: 1.5,
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.rank, required this.data});
  final int rank;
  final PlayerOverviewRow data;

  @override
  Widget build(BuildContext context) {
    final nameSize = DossedartPlayerOverviewScreen._nameFontSize(data.name.length);
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x2EFFFFFF), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Line 1: rank | avatar | name | remaining
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  rank.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontFamily: 'PressStart2P', fontSize: 16,
                    color: DossedartTokens.yellow, letterSpacing: 1,
                  ),
                ),
              ),
              DossedartPlayerAvatar(
                name: data.name,
                avatarPath: data.avatarPath,
                size: 44,
                borderColor: DossedartTokens.magenta,
                borderWidth: 2,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PressStart2P', fontSize: nameSize, color: Colors.white,
                    letterSpacing: nameSize >= 13 ? 2 : 1.2,
                  ),
                ),
              ),
              Text(
                '${data.remaining}',
                style: const TextStyle(
                  fontFamily: 'PressStart2P', fontSize: 26,
                  color: DossedartTokens.magenta, letterSpacing: 1, height: 1,
                ),
              ),
            ],
          ),
          // Line 2: AVG · HIT%
          Padding(
            padding: const EdgeInsets.only(left: 88, top: 8),
            child: Text(
              'AVG ${data.avg.toStringAsFixed(1)} · HIT ${data.hitPct}%',
              style: const TextStyle(
                fontFamily: 'VT323', fontSize: 16, color: Colors.white60, letterSpacing: 1.5,
              ),
            ),
          ),
          // Line 3: LAST throws (full width)
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: DossedartTokens.yellow.withValues(alpha: 0.08),
              border: Border.all(color: DossedartTokens.yellow.withValues(alpha: 0.35), width: 1),
            ),
            child: Row(
              children: [
                const Text(
                  'LAST',
                  style: TextStyle(
                    fontFamily: 'PressStart2P', fontSize: 8,
                    color: Color(0xA6FFD200), letterSpacing: 1,
                  ),
                ),
                Expanded(
                  child: Text(
                    data.lastTurnLabel,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'VT323', fontSize: 22, letterSpacing: 2,
                      color: DossedartTokens.yellow,
                    ),
                  ),
                ),
                Text(
                  '${data.lastTurnSum}',
                  style: const TextStyle(
                    fontFamily: 'PressStart2P', fontSize: 12,
                    color: DossedartTokens.yellow,
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

class _FooterMarquee extends StatelessWidget {
  const _FooterMarquee({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Color(0x6600E5FF), width: 1)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'PressStart2P', fontSize: 9, color: DossedartTokens.cyan,
          letterSpacing: 3,
        ),
      ),
    );
  }
}
```

- [ ] **Step 9.2: Analyze**

```bash
flutter analyze lib/screens/dossedart/x01/dossedart_player_overview_screen.dart
```
Expected: No issues.

- [ ] **Step 9.3: Commit**

```bash
git add lib/screens/dossedart/x01/dossedart_player_overview_screen.dart
git commit -m "feat(dossedart): DossedartPlayerOverviewScreen (arcade scoreboard)"
```

---

## Task 10: Add useDossedartDesign flag to GameScreen + extract classic build

**Files:**
- Modify: `lib/screens/game_screen.dart`

This task only refactors — no new behaviour. The existing `build()` body becomes `_buildClassicScaffold(context)`. A new `_buildDossedartCockpit(context)` stub returns the same classic scaffold for now (it gets replaced in Task 11). The new constructor param defaults to `false` so nothing changes for existing callers yet.

- [ ] **Step 10.1: Add constructor field**

Modify `lib/screens/game_screen.dart` line 28-46:

```dart
class GameScreen extends StatefulWidget {
  final List<Player> players;
  final String masterOut;
  final int startingScore;
  final bool handicap;
  final bool noBust;
  final bool useDossedartDesign;

  const GameScreen({
    super.key,
    required this.players,
    this.masterOut = 'none',
    required this.startingScore,
    this.handicap = false,
    this.noBust = false,
    this.useDossedartDesign = false,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}
```

- [ ] **Step 10.2: Refactor build() into branch**

Find the existing `Widget build(BuildContext context) { ... }` in `_GameScreenState` (around line 1417). Rename the existing method body's wrapper to a private method, and add a top-level `build` that picks.

The existing build method is large — copy its full body verbatim, then rename. Do not modify the body.

The simplest mechanical change:

```dart
@override
Widget build(BuildContext context) {
  if (widget.useDossedartDesign) return _buildDossedartCockpit(context);
  return _buildClassicScaffold(context);
}

Widget _buildClassicScaffold(BuildContext context) {
  // …the entire existing build() body, untouched…
}

Widget _buildDossedartCockpit(BuildContext context) {
  // Placeholder — Task 11 wires the real cockpit. For now defer to
  // classic so the app still works during the refactor.
  return _buildClassicScaffold(context);
}
```

- [ ] **Step 10.3: Verify the app still works classically**

```bash
flutter analyze lib/screens/game_screen.dart
flutter test test/
```
Expected: analyzer clean, all 161 widget tests pass (no behaviour change yet).

- [ ] **Step 10.4: Commit**

```bash
git add lib/screens/game_screen.dart
git commit -m "refactor(game_screen): extract classic build, add useDossedartDesign flag stub"
```

---

## Task 11: Wire setup screen to pass `useDossedartDesign: true`

**Files:**
- Modify: `lib/screens/dossedart/dossedart_x01_setup_screen.dart`

- [ ] **Step 11.1: Update the GameScreen push**

In `lib/screens/dossedart/dossedart_x01_setup_screen.dart`, find the `Navigator.pushReplacement` block (around line 83) and add the new param:

```dart
Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => GameScreen(
      players: withScore,
      masterOut: _outRule,
      startingScore: widget.startingScore,
      handicap: _handicap,
      noBust: _noBust,
      useDossedartDesign: true,
    ),
  ),
);
```

- [ ] **Step 11.2: Analyze + test**

```bash
flutter analyze lib/screens/dossedart/dossedart_x01_setup_screen.dart
flutter test test/
```
Expected: clean. (The flag is set to `true` but `_buildDossedartCockpit` still defers to classic, so behaviour is unchanged.)

- [ ] **Step 11.3: Commit**

```bash
git add lib/screens/dossedart/dossedart_x01_setup_screen.dart
git commit -m "feat(dossedart): X01 setup passes useDossedartDesign=true to GameScreen"
```

---

## Task 12: Implement `_buildDossedartCockpit` — wire the widgets

**Files:**
- Modify: `lib/screens/game_screen.dart`

Replace the placeholder with the real cockpit: `Stack` with `DossedartCrtFrame`, `DossedartX01TopBar` at top, `DossedartX01ActiveCard` in flow, `DossedartX01Dartboard` Positioned in the middle, `DossedartX01ActionBar` Positioned at bottom.

For checkout-tip text, reuse the existing `_checkoutFor(int score)` method (already exists in `_GameScreenState`).

For last-turn label, reuse `_lastDartsLabel(int playerIndex)`.

- [ ] **Step 12.1: Add imports to game_screen.dart**

Near the top of `lib/screens/game_screen.dart`, after existing imports:

```dart
import '../widgets/dossedart/dossedart_crt_frame.dart';
import '../widgets/dossedart/x01/dart_zone.dart';
import '../widgets/dossedart/x01/dossedart_x01_active_card.dart';
import '../widgets/dossedart/x01/dossedart_x01_action_bar.dart';
import '../widgets/dossedart/x01/dossedart_x01_dartboard.dart';
import '../widgets/dossedart/x01/dossedart_x01_topbar.dart';
import 'dossedart/x01/dossedart_player_overview_screen.dart';
```

- [ ] **Step 12.2: Replace `_buildDossedartCockpit` body**

Find the placeholder added in Task 10 and replace:

```dart
Widget _buildDossedartCockpit(BuildContext context) {
  final player = players[currentPlayerIndex];
  final lastLabel = _lastDartsLabel(currentPlayerIndex);
  final tip = _checkoutFor(player.score);

  // Last-turn sum (sum of the three throws ending the previous turn).
  final lastTurn = throwHistory.where((t) => t.playerIndex == currentPlayerIndex).toList();
  // Take the last 3 darts BEFORE the current turn (skip darts in progress).
  // For this iteration we use lastLabel as-is and a 0 sum when unknown.
  // _lastDartsLabel already produces 'T20 · S20 · S20' style strings.
  final lastSum = _sumOfLastThreeBeforeCurrentTurn(currentPlayerIndex);

  final title = 'X01 · ${widget.startingScore} · ${_outRuleLabel()}';

  return Scaffold(
    backgroundColor: const Color(0xFF0A0014),
    body: DossedartCrtFrame(
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DossedartX01TopBar(
                  title: title,
                  legIndex: 1,
                  legCount: 1,
                  roundNumber: _currentRound(),
                  onExit: _confirmExit,
                ),
                DossedartX01ActiveCard(
                  playerName: player.name,
                  avatarPath: player.avatarPath,
                  accentColor: const Color(0xFFFF00AA),
                  remaining: player.score,
                  currentDartIndex: dartsInTurn,
                  lastTurnLabel: lastLabel,
                  lastTurnSum: lastSum,
                  checkoutTip: tip.isEmpty ? null : tip,
                ),
              ],
            ),
            // Dartboard — fixed position, never shifts with active card height
            Positioned(
              left: 14, right: 14, bottom: 74,
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFFF00AA), width: 3),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFFF00AA).withValues(alpha: 0.4), blurRadius: 14),
                    ],
                  ),
                  child: DossedartX01Dartboard(
                    onTap: (zone) {
                      final (seg, mult) = zone.toSegmentMultiplier();
                      if (seg == 0) {
                        _onMiss();
                      } else {
                        _onDartHit(seg, mult);
                      }
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: DossedartX01ActionBar(
                onUndo: _undo,
                onMiss: _onMiss,
                onMenu: () => _showDossedartMenu(context),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _outRuleLabel() {
  switch (widget.masterOut) {
    case 'double': return 'D-OUT';
    case 'master': return 'MASTER';
    default: return 'FREE';
  }
}

int _currentRound() {
  // Round number = (total darts thrown by the index-0 player) ~/ 3 + 1.
  // For multi-player, all players play roughly the same number of rounds.
  final p0Darts = throwHistory.where((t) => t.playerIndex == 0).length;
  return (p0Darts ~/ 3) + 1;
}

int _sumOfLastThreeBeforeCurrentTurn(int playerIndex) {
  final all = throwHistory.where((t) => t.playerIndex == playerIndex).toList();
  // Exclude darts in the current in-progress turn (those count toward dartsInTurn).
  final completedCount = all.length - dartsInTurn;
  if (completedCount < 3) return 0;
  final lastThree = all.sublist(completedCount - 3, completedCount);
  return lastThree.fold(0, (acc, t) => acc + t.segment * t.multiplier);
}

void _showDossedartMenu(BuildContext outerContext) {
  showModalBottomSheet(
    context: outerContext,
    backgroundColor: const Color(0xFF1A0030),
    builder: (sheetCtx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.scoreboard, color: Color(0xFF00E5FF)),
              title: const Text(
                'PLAYER OVERVIEW',
                style: TextStyle(
                  fontFamily: 'PressStart2P', fontSize: 11, color: Colors.white, letterSpacing: 1.5,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                _openPlayerOverview();
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Color(0xFFFF3050)),
              title: const Text(
                'EXIT MATCH',
                style: TextStyle(
                  fontFamily: 'PressStart2P', fontSize: 11, color: Colors.white, letterSpacing: 1.5,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmExit();
              },
            ),
          ],
        ),
      );
    },
  );
}

void _openPlayerOverview() {
  final rows = <PlayerOverviewRow>[];
  for (int i = 0; i < players.length; i++) {
    final p = players[i];
    final pThrows = throwHistory.where((t) => t.playerIndex == i).toList();
    final hits = pThrows.where((t) => t.segment != 0).length;
    final total = pThrows.length;
    final hitPct = total == 0 ? 0 : (hits * 100 / total).round();
    final missPct = 100 - hitPct;
    final pointsSum = pThrows.fold<int>(0, (acc, t) => acc + t.segment * t.multiplier);
    final avg = total == 0 ? 0.0 : (pointsSum / total) * 3;
    final lastLabel = _lastDartsLabel(i);
    final lastSum = _sumOfLastThreeBeforeCurrentTurn(i);
    rows.add(PlayerOverviewRow(
      name: p.name,
      avatarPath: p.avatarPath,
      remaining: p.score,
      lastTurnLabel: lastLabel.isEmpty ? '— · — · —' : lastLabel,
      lastTurnSum: lastSum,
      avg: avg,
      hitPct: hitPct,
      missPct: missPct,
    ));
  }
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => DossedartPlayerOverviewScreen(
      title: 'CAST · X01 ${widget.startingScore}',
      roundNumber: _currentRound(),
      rows: rows,
    ),
  ));
}
```

Notes:
- `_lastDartsLabel` already exists on `_GameScreenState` — use as-is.
- `_checkoutFor` already exists — use as-is.
- `_confirmExit` already exists.
- `_onDartHit`, `_onMiss`, `_undo` already exist.
- The newly-added helpers are `_outRuleLabel`, `_currentRound`, `_sumOfLastThreeBeforeCurrentTurn`, `_showDossedartMenu`, `_openPlayerOverview`. Add them as private methods on `_GameScreenState` (alongside the existing helpers).

- [ ] **Step 12.3: Analyze + verify classic still works**

```bash
flutter analyze lib/screens/game_screen.dart
flutter test test/
```
Expected: clean + all tests pass.

- [ ] **Step 12.4: Commit**

```bash
git add lib/screens/game_screen.dart
git commit -m "feat(dossedart): wire DossedartX01 cockpit into GameScreen"
```

---

## Task 13: Integration test — cockpit renders + Player Overview navigation

**Files:**
- Create: `integration_test/dossedart/x01_cockpit_test.dart`

Smoke test: start a DOSSEDART X01 match with 2 seeded players, verify cockpit renders, then open Player Overview via MENU and verify it appears.

- [ ] **Step 13.1: Create the test**

Create `integration_test/dossedart/x01_cockpit_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/dossedart/x01/dossedart_player_overview_screen.dart';
import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/widgets/dossedart/x01/dossedart_x01_dartboard.dart';

import '../helpers/test_app.dart';
import '../helpers/player_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'DOSSEDART X01 cockpit renders + MENU opens Player Overview',
      (tester) async {
    await setupTestEnvironment(
      useDossedartDesign: true,
      savedPlayers: ['MIA', 'JON'],
    );
    final players = buildPlayers(names: ['MIA', 'JON'], startingScore: 501);
    await pumpScreen(
      tester,
      GameScreen(
        players: players,
        startingScore: 501,
        useDossedartDesign: true,
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // Cockpit renders: name + remaining + dartboard + menu button visible.
    expect(find.text('MIA'), findsOneWidget);
    expect(find.text('501'), findsWidgets);
    expect(find.byType(DossedartX01Dartboard), findsOneWidget);
    expect(find.text('⋯ MENU'), findsOneWidget);

    // Open MENU → see "PLAYER OVERVIEW" entry.
    await tester.tap(find.text('⋯ MENU'));
    await tester.pumpAndSettle(const Duration(seconds: 10));
    expect(find.text('PLAYER OVERVIEW'), findsOneWidget);

    // Tap PLAYER OVERVIEW → Overview screen appears with both players.
    await tester.tap(find.text('PLAYER OVERVIEW'));
    await tester.pumpAndSettle(const Duration(seconds: 10));
    expect(find.byType(DossedartPlayerOverviewScreen), findsOneWidget);
    expect(find.text('MIA'), findsOneWidget);
    expect(find.text('JON'), findsOneWidget);
  });
}
```

- [ ] **Step 13.2: Analyze**

```bash
flutter analyze integration_test/dossedart/x01_cockpit_test.dart
```
Expected: clean.

- [ ] **Step 13.3: Commit**

```bash
git add integration_test/dossedart/x01_cockpit_test.dart
git commit -m "test(integration): DOSSEDART X01 cockpit + Player Overview smoke test"
```

---

## Task 14: Final verification + push + PR

**Files:** none (verification + git)

- [ ] **Step 14.1: Full analyzer + widget tests**

```bash
flutter analyze
flutter test test/
```
Expected: `No issues found!` + all tests pass.

- [ ] **Step 14.2: Push the branch**

```bash
git push -u origin feat/dossedart-x01-cockpit
```

- [ ] **Step 14.3: Open the PR**

```bash
gh pr create --title "DOSSEDART X01 cockpit + Player Overview (default state)" --body "$(cat <<'EOF'
## Summary

- DOSSEDART X01 in-game cockpit shipping behind the existing \`use_dossedart_design\` preview flag
- New widgets under \`lib/widgets/dossedart/x01/\`: TopBar, ActiveCard, Dartboard, ActionBar + shared CrtFrame + PlayerAvatar
- New \`DossedartPlayerOverviewScreen\` accessible from cockpit MENU
- \`GameScreen\` branches via new \`useDossedartDesign\` flag; classic logic unchanged
- Dartboard visual matches hit-test (rings are tappable at their visible width)

Spec: \`docs/superpowers/specs/2026-05-20-dossedart-x01-cockpit-design.md\`
Plan: \`docs/superpowers/plans/2026-05-20-dossedart-x01-cockpit-plan.md\`

## Out of scope (separate spec)

- BUST, TURN END, MENU (full sheet), SUDDEN DEATH, PLAYER REMOVED, LEG WON, MATCH WON game-states
- DOSSEDART in-game for Cricket / ATC / Killer / Shanghai / Splitscore

## Test plan

- [x] Widget tests for cockpit components
- [x] Integration test: cockpit renders + Player Overview navigation
- [ ] CI green (widget + Android emulator)
- [ ] Manual: enable DOSSEDART preview, start X01 501, verify cockpit + tap-zones + Player Overview

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Return the PR URL.

---

## Self-review notes

**Spec coverage:**
- §Architecture (flag plumbing + branch in build) → Task 10
- §File layout → Tasks 3-9 + 12
- §Component contracts (TopBar / ActiveCard / Dartboard / ActionBar / Player Overview) → Tasks 5, 6, 8, 7, 9 respectively
- §Dartboard geometry — visual matches hit-test → Task 8 (radius constants + zone resolver match spec table)
- §Long-name strategy → Task 6 `_nameFontSize` + Task 9 `_nameFontSize`
- §Profile pictures → Task 4 + used in Tasks 6 and 9
- §CRT visual treatment → Task 3 (DossedartCrtFrame wraps existing ArcadeFrame)
- §Layout invariants (dartboard fixed in Stack) → Task 12 (`Positioned` for board)
- §Testing (widget tests + integration test) → Tasks 5, 6, 7, 8 + Task 13

**Placeholder scan:** No TBD/TODO. The dartboard geometry table in the spec is implemented verbatim as constants in Task 8. `_outRuleLabel`, `_currentRound`, `_sumOfLastThreeBeforeCurrentTurn`, `_showDossedartMenu`, `_openPlayerOverview` are fully implemented in Task 12.

**Type consistency:** `DartZone` API used identically across Tasks 2, 8, 12. `DossedartPlayerAvatar` signature consistent in Tasks 4, 6, 9. `PlayerOverviewRow` view-model defined in Task 9 and constructed in Task 12.

**Scope check:** Single PR, ~14 commits, all changes inside DOSSEDART namespace + `game_screen.dart`. Reverting any single commit independent of later commits.
