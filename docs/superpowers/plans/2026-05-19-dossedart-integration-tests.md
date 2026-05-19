# DOSSEDART integration tests — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 6 setup-screen smoke tests + 1 home-navigation test to `integration_test/dossedart/`, exercising the DOSSEDART UI flow that PR #5 intentionally left uncovered.

**Architecture:** Each test pumps a DOSSEDART setup screen directly via `MaterialApp(home: ...)`, with `use_dossedart_design = true` in seeded prefs and 2 saved players in `PlayerStorage`. Tap both player tiles, tap the Start button (label `▶ START MATCH ◀`), assert the correct game-screen widget type appears. The home-nav scenario pumps `DossedartHomeScreen`, taps the X01 `501` card, asserts the X01 setup screen opens.

**Tech Stack:** `integration_test` package, `flutter_test` matchers, existing helpers in `integration_test/helpers/`. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-05-19-dossedart-integration-tests-design.md` (commit `37b684f`).

**Working directory:** `.worktrees/dossedart-integration-tests` (branch `feat/dossedart-integration-tests`, branched from `main`).

---

## File map

**Modified:**
- `integration_test/helpers/test_app.dart` — `setupTestEnvironment` gains `useDossedartDesign` param

**Created:**
- `integration_test/dossedart/x01_setup_test.dart`
- `integration_test/dossedart/cricket_setup_test.dart`
- `integration_test/dossedart/atc_setup_test.dart`
- `integration_test/dossedart/killer_setup_test.dart`
- `integration_test/dossedart/shanghai_setup_test.dart`
- `integration_test/dossedart/splitscore_setup_test.dart`
- `integration_test/dossedart/home_navigation_test.dart`

**No app-code changes.** All required production widgets already exist on `main`.

---

## Reference: confirmed code surface (read during plan-writing)

| Setup screen class | Constructor | Game screen pushed |
|---|---|---|
| `DossedartX01SetupScreen` | `const ({super.key, required int startingScore})` | `GameScreen` |
| `DossedartCricketSetupScreen` | `const ({super.key})` | `CricketGameScreen` |
| `DossedartAtcSetupScreen` | `const ({super.key})` | `AroundTheClockGameScreen` |
| `DossedartKillerSetupScreen` | `const ({super.key})` | `KillerGameScreen` |
| `DossedartShanghaiSetupScreen` | `const ({super.key})` | `ShanghaiGameScreen` |
| `DossedartSplitscoreSetupScreen` | `const ({super.key})` | `HalveItGameScreen` |

- **Start button label:** `'▶ START MATCH ◀'` (in `lib/widgets/dossedart/setup/dossedart_setup_scaffold.dart:431`).
- **Player picker tile** renders `Text(player.name)` — `find.text('P0')` works.
- **`minPlayers: 2`** on all modes — must tap 2 player tiles before Start is enabled.
- **Loading**: scaffold shows `CircularProgressIndicator` while `PlayerStorage.loadPlayers()` runs. `pumpAndSettle()` after the initial pump resolves it (storage is `SharedPreferences`-backed, mocked).
- **Home X01 entry**: 3 cards labeled `301`, `501`, `701` (`lib/screens/dossedart/dossedart_home_screen.dart:343` — `Text('$score')`).

---

## Task 1: Worktree + branch setup

**Files:** none (git operations only)

- [ ] **Step 1.1: Create the worktree**

```bash
git worktree add -b feat/dossedart-integration-tests .worktrees/dossedart-integration-tests main
```
Expected: `Preparing worktree (new branch 'feat/dossedart-integration-tests')`.

- [ ] **Step 1.2: Switch to it**

```bash
cd .worktrees/dossedart-integration-tests
```

All subsequent steps run from this directory.

- [ ] **Step 1.3: Run analyzer baseline**

```bash
flutter pub get
flutter analyze
```
Expected: no errors (matches `main`). If any errors, stop and report.

---

## Task 2: Extend `setupTestEnvironment` with `useDossedartDesign`

**Files:**
- Modify: `integration_test/helpers/test_app.dart`

- [ ] **Step 2.1: Add the parameter**

In `integration_test/helpers/test_app.dart`, find the existing signature:

```dart
Future<void> setupTestEnvironment({
  List<String> savedPlayers = const [],
}) async {
```

Replace with:

```dart
Future<void> setupTestEnvironment({
  List<String> savedPlayers = const [],
  bool useDossedartDesign = false,
}) async {
```

- [ ] **Step 2.2: Wire the flag into prefs**

Immediately after the line:

```dart
  final initial = Map<String, Object>.from(_defaultPrefs);
```

insert:

```dart
  if (useDossedartDesign) {
    initial['use_dossedart_design'] = true;
  }
```

- [ ] **Step 2.3: Update the dartdoc**

Replace the existing docstring (lines 25–29) with:

```dart
/// Initialises platform-channel mocks and SharedPreferences for a test.
///
/// Call once at the start of each test, before `pumpWidget`. Optional
/// [savedPlayers] list seeds `PlayerStorage` (key 'saved_players') so the
/// test can navigate setup → game without driving the "Add Player" dialog.
/// Set [useDossedartDesign] to `true` to exercise DOSSEDART screens; default
/// `false` keeps classic-design coverage stable.
```

- [ ] **Step 2.4: Analyze**

```bash
flutter analyze integration_test/helpers/test_app.dart
```
Expected: no errors.

- [ ] **Step 2.5: Commit**

```bash
git add integration_test/helpers/test_app.dart
git commit -m "test(integration): extend setupTestEnvironment with useDossedartDesign flag"
```

---

## Task 3: X01 setup smoke test

**Files:**
- Create: `integration_test/dossedart/x01_setup_test.dart`

- [ ] **Step 3.1: Create the test file**

Create `integration_test/dossedart/x01_setup_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dart_scoring/screens/dossedart/dossedart_x01_setup_screen.dart';
import 'package:dart_scoring/screens/game_screen.dart';

import '../helpers/test_app.dart';
import '../helpers/player_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DOSSEDART X01 setup: defaults + 2 players → Start opens GameScreen',
      (tester) async {
    await setupTestEnvironment(
      useDossedartDesign: true,
      savedPlayers: ['P0', 'P1'],
    );
    await pumpScreen(
      tester,
      const DossedartX01SetupScreen(startingScore: 501),
    );
    await tester.pumpAndSettle();

    // Select both seeded players.
    await tester.tap(find.text('P0'));
    await tester.tap(find.text('P1'));
    await tester.pumpAndSettle();

    // Tap the Start button (exact label from scaffold).
    await tester.tap(find.text('▶ START MATCH ◀'));
    await tester.pumpAndSettle();

    expect(find.byType(GameScreen), findsOneWidget,
        reason: 'X01 setup Start should push GameScreen via Navigator.pushReplacement');
    expect(find.byType(DossedartX01SetupScreen), findsNothing,
        reason: 'pushReplacement should remove the setup screen');
  });
}
```

`pumpScreen` is the existing helper that wraps the widget in `MaterialApp(home: ...)`.

- [ ] **Step 3.2: Analyze**

```bash
flutter analyze integration_test/dossedart/x01_setup_test.dart
```
Expected: no errors.

- [ ] **Step 3.3: Commit**

```bash
git add integration_test/dossedart/x01_setup_test.dart
git commit -m "test(integration): DOSSEDART X01 setup smoke test"
```

---

## Task 4: Cricket setup smoke test

**Files:**
- Create: `integration_test/dossedart/cricket_setup_test.dart`

- [ ] **Step 4.1: Create the test file**

Create `integration_test/dossedart/cricket_setup_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dart_scoring/screens/cricket_game_screen.dart';
import 'package:dart_scoring/screens/dossedart/dossedart_cricket_setup_screen.dart';

import '../helpers/test_app.dart';
import '../helpers/player_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DOSSEDART Cricket setup: defaults + 2 players → Start opens CricketGameScreen',
      (tester) async {
    await setupTestEnvironment(
      useDossedartDesign: true,
      savedPlayers: ['P0', 'P1'],
    );
    await pumpScreen(tester, const DossedartCricketSetupScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('P0'));
    await tester.tap(find.text('P1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('▶ START MATCH ◀'));
    await tester.pumpAndSettle();

    expect(find.byType(CricketGameScreen), findsOneWidget);
    expect(find.byType(DossedartCricketSetupScreen), findsNothing);
  });
}
```

- [ ] **Step 4.2: Analyze**

```bash
flutter analyze integration_test/dossedart/cricket_setup_test.dart
```
Expected: no errors.

- [ ] **Step 4.3: Commit**

```bash
git add integration_test/dossedart/cricket_setup_test.dart
git commit -m "test(integration): DOSSEDART Cricket setup smoke test"
```

---

## Task 5: ATC setup smoke test

**Files:**
- Create: `integration_test/dossedart/atc_setup_test.dart`

- [ ] **Step 5.1: Create the test file**

Create `integration_test/dossedart/atc_setup_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dart_scoring/screens/around_the_clock_game_screen.dart';
import 'package:dart_scoring/screens/dossedart/dossedart_atc_setup_screen.dart';

import '../helpers/test_app.dart';
import '../helpers/player_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DOSSEDART ATC setup: defaults + 2 players → Start opens AroundTheClockGameScreen',
      (tester) async {
    await setupTestEnvironment(
      useDossedartDesign: true,
      savedPlayers: ['P0', 'P1'],
    );
    await pumpScreen(tester, const DossedartAtcSetupScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('P0'));
    await tester.tap(find.text('P1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('▶ START MATCH ◀'));
    await tester.pumpAndSettle();

    expect(find.byType(AroundTheClockGameScreen), findsOneWidget);
    expect(find.byType(DossedartAtcSetupScreen), findsNothing);
  });
}
```

- [ ] **Step 5.2: Analyze**

```bash
flutter analyze integration_test/dossedart/atc_setup_test.dart
```
Expected: no errors.

- [ ] **Step 5.3: Commit**

```bash
git add integration_test/dossedart/atc_setup_test.dart
git commit -m "test(integration): DOSSEDART ATC setup smoke test"
```

---

## Task 6: Killer setup smoke test

**Files:**
- Create: `integration_test/dossedart/killer_setup_test.dart`

- [ ] **Step 6.1: Create the test file**

Create `integration_test/dossedart/killer_setup_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dart_scoring/screens/dossedart/dossedart_killer_setup_screen.dart';
import 'package:dart_scoring/screens/killer_game_screen.dart';

import '../helpers/test_app.dart';
import '../helpers/player_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DOSSEDART Killer setup: defaults + 2 players → Start opens KillerGameScreen',
      (tester) async {
    await setupTestEnvironment(
      useDossedartDesign: true,
      savedPlayers: ['P0', 'P1'],
    );
    await pumpScreen(tester, const DossedartKillerSetupScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('P0'));
    await tester.tap(find.text('P1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('▶ START MATCH ◀'));
    await tester.pumpAndSettle();

    expect(find.byType(KillerGameScreen), findsOneWidget);
    expect(find.byType(DossedartKillerSetupScreen), findsNothing);
  });
}
```

- [ ] **Step 6.2: Analyze**

```bash
flutter analyze integration_test/dossedart/killer_setup_test.dart
```
Expected: no errors.

- [ ] **Step 6.3: Commit**

```bash
git add integration_test/dossedart/killer_setup_test.dart
git commit -m "test(integration): DOSSEDART Killer setup smoke test"
```

---

## Task 7: Shanghai setup smoke test

**Files:**
- Create: `integration_test/dossedart/shanghai_setup_test.dart`

- [ ] **Step 7.1: Create the test file**

Create `integration_test/dossedart/shanghai_setup_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dart_scoring/screens/dossedart/dossedart_shanghai_setup_screen.dart';
import 'package:dart_scoring/screens/shanghai_game_screen.dart';

import '../helpers/test_app.dart';
import '../helpers/player_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DOSSEDART Shanghai setup: defaults + 2 players → Start opens ShanghaiGameScreen',
      (tester) async {
    await setupTestEnvironment(
      useDossedartDesign: true,
      savedPlayers: ['P0', 'P1'],
    );
    await pumpScreen(tester, const DossedartShanghaiSetupScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('P0'));
    await tester.tap(find.text('P1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('▶ START MATCH ◀'));
    await tester.pumpAndSettle();

    expect(find.byType(ShanghaiGameScreen), findsOneWidget);
    expect(find.byType(DossedartShanghaiSetupScreen), findsNothing);
  });
}
```

- [ ] **Step 7.2: Analyze**

```bash
flutter analyze integration_test/dossedart/shanghai_setup_test.dart
```
Expected: no errors.

- [ ] **Step 7.3: Commit**

```bash
git add integration_test/dossedart/shanghai_setup_test.dart
git commit -m "test(integration): DOSSEDART Shanghai setup smoke test"
```

---

## Task 8: Splitscore setup smoke test

**Files:**
- Create: `integration_test/dossedart/splitscore_setup_test.dart`

Note: setup-screen class is `DossedartSplitscoreSetupScreen`; the pushed game screen is `HalveItGameScreen` (class rename was deferred — see memory `project_halve_it_rename.md`).

- [ ] **Step 8.1: Create the test file**

Create `integration_test/dossedart/splitscore_setup_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dart_scoring/screens/dossedart/dossedart_splitscore_setup_screen.dart';
import 'package:dart_scoring/screens/halve_it_game_screen.dart';

import '../helpers/test_app.dart';
import '../helpers/player_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DOSSEDART Splitscore setup: defaults + 2 players → Start opens HalveItGameScreen',
      (tester) async {
    await setupTestEnvironment(
      useDossedartDesign: true,
      savedPlayers: ['P0', 'P1'],
    );
    await pumpScreen(tester, const DossedartSplitscoreSetupScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('P0'));
    await tester.tap(find.text('P1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('▶ START MATCH ◀'));
    await tester.pumpAndSettle();

    expect(find.byType(HalveItGameScreen), findsOneWidget);
    expect(find.byType(DossedartSplitscoreSetupScreen), findsNothing);
  });
}
```

- [ ] **Step 8.2: Analyze**

```bash
flutter analyze integration_test/dossedart/splitscore_setup_test.dart
```
Expected: no errors.

- [ ] **Step 8.3: Commit**

```bash
git add integration_test/dossedart/splitscore_setup_test.dart
git commit -m "test(integration): DOSSEDART Splitscore setup smoke test"
```

---

## Task 9: Home navigation scenario

**Files:**
- Create: `integration_test/dossedart/home_navigation_test.dart`

The DOSSEDART home shows three X01 cards labeled `301`, `501`, `701` (`_x01Card` builder, `lib/screens/dossedart/dossedart_home_screen.dart:328`). Tapping `501` calls `_startGame(GameMode.x01, startingScore: 501)`, which pushes `DossedartX01SetupScreen(startingScore: 501)`.

- [ ] **Step 9.1: Create the test file**

Create `integration_test/dossedart/home_navigation_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dart_scoring/screens/dossedart/dossedart_home_screen.dart';
import 'package:dart_scoring/screens/dossedart/dossedart_x01_setup_screen.dart';

import '../helpers/test_app.dart';
import '../helpers/player_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DOSSEDART home → tap 501 X01 card → X01 setup screen opens',
      (tester) async {
    await setupTestEnvironment(useDossedartDesign: true);
    await pumpScreen(tester, const DossedartHomeScreen());
    await tester.pumpAndSettle();

    // Tap the 501 X01 card.
    await tester.tap(find.text('501'));
    await tester.pumpAndSettle();

    expect(find.byType(DossedartX01SetupScreen), findsOneWidget);
  });
}
```

This scenario seeds no players — it stops at the setup screen, so no Add Player flow is triggered.

- [ ] **Step 9.2: Analyze**

```bash
flutter analyze integration_test/dossedart/home_navigation_test.dart
```
Expected: no errors.

- [ ] **Step 9.3: Commit**

```bash
git add integration_test/dossedart/home_navigation_test.dart
git commit -m "test(integration): DOSSEDART home navigation scenario"
```

---

## Task 10: Final verification + PR

**Files:** none

- [ ] **Step 10.1: Run analyzer over the whole folder**

```bash
flutter analyze integration_test/
```
Expected: no errors.

- [ ] **Step 10.2: Run existing widget tests (sanity)**

```bash
flutter test test/
```
Expected: all pass. If anything broke, the helper change is the only candidate — inspect `setupTestEnvironment` change.

- [ ] **Step 10.3: Push branch**

```bash
git push -u origin feat/dossedart-integration-tests
```

- [ ] **Step 10.4: Open PR**

```bash
gh pr create --title "DOSSEDART integration test coverage (6 setup smoke + 1 home-nav)" --body "$(cat <<'EOF'
## Summary

- Extends `setupTestEnvironment` with a `useDossedartDesign` flag
- Adds 7 integration tests under `integration_test/dossedart/`:
  - X01, Cricket, ATC, Killer, Shanghai, Splitscore setup smoke tests
  - DOSSEDART home → X01 setup navigation

Spec: `docs/superpowers/specs/2026-05-19-dossedart-integration-tests-design.md`.

## Test plan

- [ ] CI green (widget tests + integration tests on Android emulator)
- [ ] Local emulator run optional

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Return the PR URL.

---

## Self-review notes

**Spec coverage check:**
- §Goals "6 setup-screen smoke + 1 home-nav" → Tasks 3–9 ✓
- §Goals "extend setupTestEnvironment with useDossedartDesign" → Task 2 ✓
- §Architecture "reuse savedPlayers seeding" → all setup tests pass `savedPlayers` ✓
- §Folder layout `integration_test/dossedart/` → Tasks 3–9 create files there ✓
- §Game-screen mapping → Reference table + each Task asserts the correct widget type ✓
- §Home-navigation "tap X01 entry" → Task 9 taps `'501'` card ✓
- §Risks "Start button label" → resolved as `'▶ START MATCH ◀'` in Reference table ✓
- §Risks "player selection finder" → resolved as `find.text('P0')` (verified via picker-tile source) ✓
- §Risks "HalveIt vs Splitscore class name" → Task 8 imports `HalveItGameScreen`, asserts that type ✓
- §Verification "CI picks up new files automatically" → no workflow changes ✓

**Placeholder scan:** No TBD/TODO/"verify at impl time" left in step bodies — all finders and types are concrete. The Reference table documents source-of-truth locations for any future reader.

**Type consistency:** `setupTestEnvironment({savedPlayers, useDossedartDesign})` used identically across all tasks. `pumpScreen(tester, widget)` matches existing helper signature. All game-screen class names match the verified table.

**Scope:** Single focused PR, ~7 commits, no app-code changes, no helper API removal. Safe to revert any single commit independently.
