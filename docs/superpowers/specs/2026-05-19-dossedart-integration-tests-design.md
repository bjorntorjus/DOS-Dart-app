# DOSSEDART integration test coverage — design

**Date:** 2026-05-19
**Target branch:** `feat/dossedart-integration-tests` (worktree `.worktrees/dossedart-integration-tests`, branched from `main`)

## Problem

DOSSEDART is the arcade-styled UI variant introduced in 2026-05 (`feat/dossedart-arcade-v1`, merged in PR #2; revision 2 QA'd 2026-05-13). It consists of a home screen + 6 setup screens (`lib/screens/dossedart/`). Game screens are shared with classic.

The integration-test foundation landed in PR #5 (2026-05-13) intentionally pinned `use_dossedart_design: false` and pumped game screens directly. As a result:

- 100 % of DOSSEDART code paths are untested at the integration layer.
- The DOSSEDART setup screens are the *most actively changed* part of the codebase (revision 2 just QA'd; "Konsistens på tvers av game modes" memory says drift across modes is a recurring risk).
- The home → setup → game flow has 0 % integration coverage in either variant.

## Goals

- Smoke-test all 6 DOSSEDART setup screens: open the screen, accept defaults, tap Start, assert the correct game screen opens.
- One home-navigation scenario: tap an X01 entry on DOSSEDART home, assert the X01 setup screen appears.
- Extend `setupTestEnvironment` to support a `useDossedartDesign: true` mode.
- Reuse the existing helper's `savedPlayers` seeding so tests don't tap-walk through Add Player.

## Non-goals

- Toggle-permutation coverage (chip-toggles in their defaults only).
- Add Player / picker flow — separate concern; covered later if needed.
- Actual gameplay or post-game assertions — classic scenarios already cover those code paths.
- In-game DOSSEDART rendering — game screens are shared with classic.
- Visual regression / golden images.

## Architecture

### Folder layout

```
integration_test/
  dossedart/
    home_navigation_test.dart
    x01_setup_test.dart
    cricket_setup_test.dart
    atc_setup_test.dart
    killer_setup_test.dart
    shanghai_setup_test.dart
    splitscore_setup_test.dart
```

The `dossedart/` subfolder mirrors `lib/screens/dossedart/` so future maintainers see the symmetry. `flutter test integration_test/` still picks up everything recursively.

### Helper extension

`integration_test/helpers/test_app.dart` — `setupTestEnvironment` gains a `useDossedartDesign` parameter:

```dart
Future<void> setupTestEnvironment({
  List<String> savedPlayers = const [],
  bool useDossedartDesign = false,
}) async {
  final initial = Map<String, Object>.from(_defaultPrefs);
  if (useDossedartDesign) {
    initial['use_dossedart_design'] = true;
  }
  if (savedPlayers.isNotEmpty) { /* unchanged */ }
  SharedPreferences.setMockInitialValues(initial);
  // ... rest unchanged
}
```

No new helper functions — the existing `pumpScreen`, `buildPlayers`, `setupTestEnvironment` cover everything.

### Scenario shape

Each setup-screen test:

1. `setupTestEnvironment(useDossedartDesign: true, savedPlayers: ['P0', 'P1'])`
2. `pumpScreen(tester, const DossedartXxxSetupScreen())`
3. `pumpAndSettle()`
4. Select both players (tap their cards/chips)
5. Tap the Start button
6. `pumpAndSettle()`
7. `expect(find.byType(<game-screen-type>), findsOneWidget)`

Example (`x01_setup_test.dart`):

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
    await pumpScreen(tester, const DossedartX01SetupScreen());
    await tester.pumpAndSettle();

    // Select P0 + P1. Exact finder (Text vs avatar key) confirmed at impl time.
    await tester.tap(find.text('P0'));
    await tester.tap(find.text('P1'));
    await tester.pumpAndSettle();

    // Tap Start. Exact label/widget verified per setup screen at impl time
    // (likely 'START' but may be an icon button — implementer reads the file).
    await tester.tap(find.text('START'));
    await tester.pumpAndSettle();

    expect(find.byType(GameScreen), findsOneWidget);
  });
}
```

### Game-screen → setup-screen mapping

| DOSSEDART setup screen | Resulting game screen |
|---|---|
| `DossedartX01SetupScreen` | `GameScreen` |
| `DossedartCricketSetupScreen` | `CricketGameScreen` |
| `DossedartAtcSetupScreen` | `AroundTheClockGameScreen` |
| `DossedartKillerSetupScreen` | `KillerGameScreen` |
| `DossedartShanghaiSetupScreen` | `ShanghaiGameScreen` |
| `DossedartSplitscoreSetupScreen` | `HalveItGameScreen` (renamed in UI, class still `HalveIt*`) |

Splitscore→HalveIt: per memory `project_halve_it_rename.md`, the UI label is "Splitscore" but the class name is still `HalveIt...`. Confirm at impl time before asserting widget type.

### Home-navigation scenario

`home_navigation_test.dart`:

```dart
testWidgets('DOSSEDART home → tap X01 → X01 setup screen opens', (tester) async {
  await setupTestEnvironment(useDossedartDesign: true);
  await pumpScreen(tester, const DossedartHomeScreen());
  await tester.pumpAndSettle();

  // Tap the X01 entry. Exact finder (key/text/icon) confirmed at impl time.
  await tester.tap(find.text('X01'));
  await tester.pumpAndSettle();

  expect(find.byType(DossedartX01SetupScreen), findsOneWidget);
});
```

This scenario does NOT seed players — it stops at the setup screen.

### Risks / known unknowns the implementer resolves

1. **Setup-screen constructors**: most are `const X(...)`, but Killer/Shanghai may require an `onStart` callback or `config` param. Read each file before writing the test.
2. **Start button label/widget**: chip-toggles in revision 2 use custom widgets. The "START" button may be `find.text('START')`, an icon button, or wrapped in a custom widget. Each test verifies its own finder.
3. **Player selection**: avatar cards may not contain a `Text(name)` widget directly — could be `Text` inside a `Stack` with an avatar image. If `find.text('P0')` fails, fall back to `find.byKey(Key('player-card-test-player-0'))` and add keys to the DOSSEDART player cards in the same PR (smallest possible change).
4. **HalveIt vs Splitscore class name**: confirm `HalveItGameScreen` is still the class name before importing.

These are documented up-front so the implementer doesn't have to ad-lib.

## Verification

Each scenario runs locally via `flutter test integration_test/dossedart/<name>.dart` against a connected emulator (Galaxy Tab per memory).

CI: existing `.github/workflows/integration-tests.yml` picks up the new files automatically (`flutter test integration_test/` is recursive). No workflow changes needed.

## Out of scope

- iOS / desktop platform runs
- Performance / golden-image / visual regression
- Toggle-state permutations
- Add Player / picker / recent-results UI
- DOSSEDART home → all 6 setup screens (only X01 covered; consistency assumed)
- Mid-game player add/remove in DOSSEDART (covered by classic Cricket scenario)

## Commit plan

Single PR `feat/dossedart-integration-tests` with logical commits:

1. `test(integration): extend setupTestEnvironment with useDossedartDesign flag`
2. `test(integration): DOSSEDART home navigation scenario`
3. `test(integration): DOSSEDART X01 setup smoke test`
4. `test(integration): DOSSEDART Cricket setup smoke test`
5. `test(integration): DOSSEDART ATC setup smoke test`
6. `test(integration): DOSSEDART Killer setup smoke test`
7. `test(integration): DOSSEDART Shanghai setup smoke test`
8. `test(integration): DOSSEDART Splitscore setup smoke test`

If any single commit fails analyzer/tests, do not advance to the next.
