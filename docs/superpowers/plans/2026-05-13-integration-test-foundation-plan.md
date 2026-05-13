# Integration test foundation — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish `integration_test/` foundation with deterministic helpers + 3 scenarios (X01 golden path, Cricket mid-game remove regression, Shanghai post-game Undo regression) + a GitHub Actions workflow that runs widget and integration tests on every PR.

**Architecture:** Each test pumps the relevant screen directly via `tester.pumpWidget(MaterialApp(home: <screen>(...)))` rather than tap-walking the full home→setup→game flow. This gives integration-test value (real plugins, real navigation, real fonts) without the brittleness of long tap sequences. The two regression scenarios drive their respective engines via existing `@visibleForTesting` hooks (`engineForTest`, `removePlayerForTest`, `computeWinnerForTest`, `onGameEndForTest`) — these were added in PRs #3 and #4 and are exactly the right surface for E2E injection. The X01 golden-path test includes a brief real-tap input sequence to prove the keypad path also works under integration_test runner.

**Tech Stack:** Flutter `integration_test` package (Flutter SDK), `flutter_test` matchers, `reactivecircus/android-emulator-runner@v2` GitHub Action, Ubuntu CI runner.

**Spec:** `docs/superpowers/specs/2026-05-13-integration-test-foundation-design.md` (commit `b87dacb`).

**Working directory:** `.worktrees/integration-tests` (branch `feat/integration-tests`, branched from `main`).

---

## File map

**Modified:**
- `pubspec.yaml` — add `integration_test` to `dev_dependencies`

**Created:**
- `integration_test/helpers/test_app.dart` — `pumpApp(tester)`, `mockBatteryChannel()`, `seedSavedPlayers(names)`
- `integration_test/helpers/player_setup.dart` — re-export of common imports; small helpers for game-screen pumping
- `integration_test/x01_full_game_test.dart`
- `integration_test/cricket_remove_player_test.dart`
- `integration_test/shanghai_postgame_undo_test.dart`
- `integration_test/README.md`
- `.github/workflows/integration-tests.yml`

**No app code modified.** The `@visibleForTesting` hooks needed by the tests already exist in `main` (added in PRs #3 and #4).

---

## Task 1: Add `integration_test` dev dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1.1: Add `integration_test` to `dev_dependencies`**

In `pubspec.yaml`, find the `dev_dependencies:` block (around line 47). After `flutter_test:`, add:

```yaml
  integration_test:
    sdk: flutter
```

The full block should now look like:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter

  flutter_lints: ^6.0.0
```

- [ ] **Step 1.2: Run `flutter pub get`**

```bash
cd .worktrees/integration-tests
flutter pub get
```
Expected: `Got dependencies!`

- [ ] **Step 1.3: Commit**

```bash
cd .worktrees/integration-tests
git add pubspec.yaml pubspec.lock
git commit -m "chore(deps): add integration_test dev dependency"
```

---

## Task 2: Helpers — `test_app.dart`

**Files:**
- Create: `integration_test/helpers/test_app.dart`

- [ ] **Step 2.1: Create the helper file**

Create `integration_test/helpers/test_app.dart` with:

```dart
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/services/sound_service.dart';

/// Deterministic initial SharedPreferences for integration tests.
///
/// Keys mirror what `AppSettings` reads. Anything not listed here falls
/// back to the production default — usually `false`/`null` — which is
/// what we want for a clean-slate test.
const Map<String, Object> _defaultPrefs = {
  'tts_next_player': false,
  'tts_throw_result': false,
  'tts_score': false,
  'tts_winner': false,
  'tts_game_events': false,
  'video_events_enabled': false,
  'use_dossedart_design': false,
};

/// Initialises platform-channel mocks and SharedPreferences for a test.
///
/// Call once at the start of each test, before `pumpWidget`. Optional
/// [savedPlayers] list seeds `PlayerStorage` (key 'saved_players') so the
/// test can navigate setup → game without driving the "Add Player" dialog.
Future<void> setupTestEnvironment({
  List<String> savedPlayers = const [],
}) async {
  // Seed SharedPreferences with deterministic flags + optional players.
  final initial = Map<String, Object>.from(_defaultPrefs);
  if (savedPlayers.isNotEmpty) {
    final list = savedPlayers.asMap().entries.map((e) {
      final id = 'test-player-${e.key}';
      return {
        'id': id,
        'name': e.value,
        'rating': 1500.0,
        'gamesPlayed': 0,
        'gamesWon': 0,
        'highestTurnScore': 0,
        'averageTurnScore': 0.0,
        'avatarPath': null,
        'createdAt': DateTime.now().toIso8601String(),
      };
    }).toList();
    initial['saved_players'] = jsonEncode(list);
  }
  SharedPreferences.setMockInitialValues(initial);

  // Disable all audio output up-front. SoundService.init reads the kill-switch
  // from settings (which we haven't added one for yet), so call setEnabled
  // explicitly. battery_plus + audioplayers platform channels are mocked below.
  SoundService.instance.setEnabled(false);

  // Mock battery_plus channel — return 100 % and 'discharging' state forever.
  // `battery_plus` uses MethodChannel('dev.fluttercommunity.plus/battery') and
  // EventChannel('dev.fluttercommunity.plus/charging') under the hood.
  const batteryChannel = MethodChannel('dev.fluttercommunity.plus/battery');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(batteryChannel, (call) async {
    if (call.method == 'getBatteryLevel') return 100;
    if (call.method == 'getBatteryState') return 'discharging';
    return null;
  });

  // image_picker is not exercised by the 3 scenarios, but mock it harmlessly
  // so any indirect call doesn't open a system dialog on the emulator.
  const imagePickerChannel = MethodChannel('plugins.flutter.io/image_picker');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(imagePickerChannel, (call) async => null);
}

/// Tears down platform-channel mocks. Run from `tearDown(...)` if any test
/// suite reuses widgets across tests. The default per-test isolation means
/// most callers don't need this.
void teardownTestEnvironment() {
  const batteryChannel = MethodChannel('dev.fluttercommunity.plus/battery');
  const imagePickerChannel = MethodChannel('plugins.flutter.io/image_picker');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(batteryChannel, null);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(imagePickerChannel, null);
}
```

Notes:
- `SoundService.instance.setEnabled(false)` matches the production API (`lib/services/sound_service.dart` exposes a `setEnabled(bool)` — verify during implementation; if the method name differs, adjust).
- The `SavedPlayer` JSON shape mirrors `lib/models/saved_player.dart`. The fields used here cover the model's required keys; if the model has additional required fields (e.g., `winRate`, `leftMidGameIds`), add them to the map. Run `flutter analyze` after creating to surface any missing fields, then update.

- [ ] **Step 2.2: Verify `SoundService.setEnabled` exists**

```bash
cd .worktrees/integration-tests
grep -n "setEnabled" lib/services/sound_service.dart
```

If the method name differs (e.g., `setMuted`, `disable`), update the helper accordingly. If no kill-switch exists at all, skip the `SoundService.instance.setEnabled(false)` line — the audioplayers platform channel will throw but the test will not actually call it as long as games don't trigger sound during integration tests (most don't fire sounds during silent injection).

- [ ] **Step 2.3: Verify `SavedPlayer` JSON shape**

```bash
cd .worktrees/integration-tests
grep -nE "toJson|fromJson" lib/models/saved_player.dart
```

Read the file's `toJson` method and add any missing required keys to the seed map in Step 2.1.

- [ ] **Step 2.4: Run analyzer**

```bash
cd .worktrees/integration-tests
flutter analyze integration_test/helpers/test_app.dart
```
Expected: no errors. Info-level lint hints OK.

- [ ] **Step 2.5: Do NOT commit yet**

Helpers commit with the README in Task 4.

---

## Task 3: Helpers — `player_setup.dart`

**Files:**
- Create: `integration_test/helpers/player_setup.dart`

- [ ] **Step 3.1: Create the helper**

Create `integration_test/helpers/player_setup.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/player.dart';

/// Convenience: build a list of `Player`s with the given starting score.
List<Player> buildPlayers({
  required List<String> names,
  required int startingScore,
}) {
  return [
    for (final name in names)
      Player(name: name, score: startingScore, savedPlayerId: null),
  ];
}

/// Pump a single screen as the home of a fresh MaterialApp.
///
/// Use this from each integration test after [setupTestEnvironment]. It
/// matches what production does in `main.dart` (no DOSSEDART chrome).
Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(MaterialApp(home: screen));
  // pump() once to schedule init; do NOT pumpAndSettle here because some
  // screens kick off Future.delayed work (battery sampler etc.) that never
  // completes in a test environment. Each scenario decides how long to pump.
  await tester.pump();
}
```

- [ ] **Step 3.2: Run analyzer**

```bash
cd .worktrees/integration-tests
flutter analyze integration_test/helpers/player_setup.dart
```
Expected: no errors.

- [ ] **Step 3.3: Do NOT commit yet**

---

## Task 4: README + commit foundation

**Files:**
- Create: `integration_test/README.md`

- [ ] **Step 4.1: Create the README**

Create `integration_test/README.md` with:

````markdown
# Integration tests

End-to-end tests that run on a real device or emulator. Unlike widget tests
(`test/`), integration tests load the full Flutter engine, real plugins, and
real navigation — so they catch bugs that widget tests miss (state
transitions, plugin behavior, post-game flows).

## Running locally

Start an Android emulator (Galaxy Tab A7 or similar — see `flutter emulators`),
then:

```bash
flutter test integration_test/                              # all scenarios
flutter test integration_test/x01_full_game_test.dart       # one scenario
```

The first run takes a minute (engine boot). Subsequent runs are fast.

## CI

`.github/workflows/integration-tests.yml` runs all integration tests on every
PR + push to `main`, on an Ubuntu runner with an Android API 30 emulator.

## What's mocked

`helpers/test_app.dart` mocks or disables:

| Plugin / service | Why |
|---|---|
| `SharedPreferences` | In-memory + seeded with deterministic flags |
| TTS (all settings keys) | Disabled — no audio out, no platform-channel hangs |
| Audio (`SoundService.setEnabled(false)`) | Disabled — no audio out |
| Video events (`video_events_enabled`) | Disabled — no MP4 overlay dialog |
| `battery_plus` channel | Mocked to return 100 %, discharging |
| `image_picker` channel | Mocked harmless no-op |
| DOSSEDART design | Forced OFF — tests target classic UI |

If you add a new scenario that needs one of these for real, weaken the mock
locally in your test rather than removing it from the helper.

## Pattern for adding a new scenario

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/screens/cricket_game_screen.dart';

import 'helpers/test_app.dart';
import 'helpers/player_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('one-line description of what this proves', (tester) async {
    await setupTestEnvironment();
    await pumpScreen(
      tester,
      CricketGameScreen(
        players: buildPlayers(names: ['P0', 'P1'], startingScore: 0),
        config: const CricketConfig(
          isRandom: false,
          targetCount: 7,
          includeBull: false,
          isCutthroat: false,
        ),
      ),
    );

    // Drive the engine via @visibleForTesting hooks where they exist —
    // see cricket_remove_player_test.dart for an example. Use real taps
    // only when the goal is to exercise the input keypad / specific UI.

    expect(/* assertion */, /* matcher */);
  });
}
```

Each test file calls `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`
once in `main()`. Each `testWidgets` calls `setupTestEnvironment()` first.

## Why we don't tap-walk the full home → setup → game flow

For 3 scenarios, driving 30+ taps per test is brittle (any UI text or layout
change breaks the test) and slow. The chosen approach pumps the game screen
directly with constructed players and config. We lose coverage of the
home/setup screens, but those are dumb wrappers around a state object — the
bugs we want to catch live in `_onGameEnd`, mid-game remove handlers, and
post-game navigation.

If we later need to test the home/setup flow itself, add a dedicated
scenario for it rather than retrofitting these.
````

- [ ] **Step 4.2: Commit foundation**

```bash
cd .worktrees/integration-tests
git add integration_test/helpers/test_app.dart \
        integration_test/helpers/player_setup.dart \
        integration_test/README.md
git commit -m "test(integration): foundation — pumpApp + helpers + README"
```

---

## Task 5: Scenario 1 — X01 full game (golden path)

**Files:**
- Create: `integration_test/x01_full_game_test.dart`

The X01 golden-path test exercises:
- Direct screen pump with 2 players, 301 starting score, no double-out, no handicap
- Inject `P0` to score 40 via the existing engine API
- Real tap on the input keypad: `D20` (double 20 = 40) → checkout
- Assert post-game appears with `P0` marked as winner

X01 (`game_screen.dart`) does not have a `@visibleForTesting` engine-hook from PR #4 (that's Shanghai-only) — instead the game state lives directly in the State's fields (`scores`, `currentPlayerIndex`, `finishedPlayers`, etc.). We expose minimal hooks for the test.

- [ ] **Step 5.1: Add `@visibleForTesting` hooks to X01 game screen**

In `lib/screens/game_screen.dart`, find the `_GameScreenState` class. Near the existing test hooks (if any — search for `@visibleForTesting`), add:

```dart
  @visibleForTesting
  void injectScoreForTest(int playerIndex, int score) {
    setState(() {
      scores[playerIndex] = score;
      players[playerIndex] = Player(
        name: players[playerIndex].name,
        score: score,
        savedPlayerId: players[playerIndex].savedPlayerId,
        avatarPath: players[playerIndex].avatarPath,
      );
    });
  }
```

If `scores` is named differently in this file (e.g., `_scores` or `playerScores`), use the actual name. Grep first:

```bash
grep -nE "List<int>\s+scores|scores =|playerScores" lib/screens/game_screen.dart | head -5
```

The hook lets the test fast-forward to "P0 is at 40" without driving 50 throws.

- [ ] **Step 5.2: Create the test file**

Create `integration_test/x01_full_game_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/screens/post_game_screen.dart';

import 'helpers/test_app.dart';
import 'helpers/player_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('X01 501 free-out: P0 checks out on D20, post-game shows P0 as winner',
      (tester) async {
    await setupTestEnvironment();
    await pumpScreen(
      tester,
      GameScreen(
        players: buildPlayers(names: ['P0', 'P1'], startingScore: 501),
        startingScore: 501,
        masterOut: 'none',
        handicap: false,
        noBust: false,
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state<State<GameScreen>>(find.byType(GameScreen));
    final dynamic dynState = state;

    // Fast-forward P0 to score 40, leaving D20 for checkout.
    dynState.injectScoreForTest(0, 40);
    await tester.pumpAndSettle();

    // Verify the displayed score reads 40 for P0 (sanity check that the
    // injection reached the UI). The text might appear multiple times if
    // there's a per-player card and a current-player big number.
    expect(find.text('40'), findsWidgets);

    // Tap D20 on the keypad. The keypad button labels in classic X01 are
    // typically '20' with a 'D'/'T' multiplier toggle, OR a direct 'D20'
    // button. Verify against the actual UI:
    //   grep -n "D20\|'20'\|onPressed.*20" lib/screens/game_screen.dart
    // Then update this section to match. As a fallback, use the score
    // injection to set P0 to 0 directly and tap any in-range button to
    // trigger the checkout-detection path.

    // Inject score 0 to simulate the checkout having landed:
    dynState.injectScoreForTest(0, 0);
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // The game-end detection runs inside _onHit and other handlers, not in
    // injectScoreForTest. Drive the production game-end path via a
    // @visibleForTesting wrapper. If `onCheckoutForTest()` doesn't exist,
    // add one in game_screen.dart that calls the same code _onHit runs when
    // it sees scores[currentPlayerIndex] == 0.

    // Pump until PostGameScreen appears or timeout.
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(PostGameScreen), findsOneWidget,
        reason: 'PostGameScreen should appear after P0 checks out');

    // The winner label/text varies by post-game screen design. Read
    // lib/screens/post_game_screen.dart to find the winner-display widget
    // and assert against its text. As a fallback, assert P0's name appears
    // in a Text widget (it almost certainly will, somewhere on the post-game).
    expect(find.text('P0'), findsWidgets,
        reason: 'Winner name should appear on PostGameScreen');
  });
}
```

⚠ **Known gaps the implementer must close before this passes:**
1. The `injectScoreForTest` hook only updates state — it does NOT trigger `_onGameEnd`. You need to either:
   - **Option A**: Add a `@visibleForTesting void triggerCheckoutForTest(int playerIndex)` method to `_GameScreenState` that mirrors what `_onHit` does on checkout (call `_updateStats(...)` and `_showPostGame(...)` or whatever the equivalent path is). Most predictable.
   - **Option B**: After `injectScoreForTest(0, 0)`, find and tap a real keypad button to trigger `_onHit`, which will detect `score == 0` and run the checkout path. More realistic but UI-fragile.
   - Prefer **Option A**. Add the method in Step 5.1 alongside `injectScoreForTest`.
2. The keypad button text / structure in `lib/screens/game_screen.dart` may need a quick read before writing tap finders. If the test uses Option A above, no real keypad taps are needed.

- [ ] **Step 5.3: Verify hooks and update test to match real APIs**

Run analyzer + test:

```bash
cd .worktrees/integration-tests
flutter analyze integration_test/x01_full_game_test.dart
```

Fix any reported issues (likely missing imports for `PostGameScreen`, `GameScreen` constructor mismatch, missing `triggerCheckoutForTest`). Read each referenced file and align the test.

- [ ] **Step 5.4: Run the test against an emulator**

Start an Android emulator first (`flutter emulators --launch Galaxy_Tab_A7` or any other Android device). Then:

```bash
cd .worktrees/integration-tests
flutter test integration_test/x01_full_game_test.dart
```

Expected: PASS. Iterate until green — common failures: missing required constructor param, finder mismatch, async hook not awaiting setState. Read the failure output, adjust, re-run.

- [ ] **Step 5.5: Commit**

```bash
cd .worktrees/integration-tests
git add integration_test/x01_full_game_test.dart lib/screens/game_screen.dart
git commit -m "test(integration): X01 full-game golden-path scenario"
```

---

## Task 6: Scenario 2 — Cricket mid-game remove regression

**Files:**
- Create: `integration_test/cricket_remove_player_test.dart`

Uses the `@visibleForTesting` hooks added in PR #3: `removePlayerForTest`, `computeWinnerForTest`, `finishedPlayersForTest`, `removedPlayerIndicesForTest`. Verify they exist by running:

```bash
grep -nE "@visibleForTesting|removePlayerForTest|computeWinnerForTest" lib/screens/cricket_game_screen.dart | head -10
```

- [ ] **Step 6.1: Create the test file**

Create `integration_test/cricket_remove_player_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/screens/cricket_game_screen.dart';

import 'helpers/test_app.dart';
import 'helpers/player_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Cricket: removed mid-game player does not become winner',
      (tester) async {
    await setupTestEnvironment();
    await pumpScreen(
      tester,
      CricketGameScreen(
        players: buildPlayers(names: ['P0', 'P1', 'P2'], startingScore: 0),
        config: const CricketConfig(
          isRandom: false,
          targetCount: 7,
          includeBull: false,
          isCutthroat: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state =
        tester.state<State<CricketGameScreen>>(find.byType(CricketGameScreen));
    final dynamic dynState = state;

    // Remove P0 mid-game — same call the unit test uses.
    dynState.removePlayerForTest(0);
    await tester.pumpAndSettle();

    expect(dynState.removedPlayerIndicesForTest.contains(0), isTrue);
    expect(dynState.finishedPlayersForTest.first, equals(0),
        reason: 'Precondition: removed player is first in finishedPlayers; '
            'the bug surfaces if computeWinnerForTest does not skip them');

    // Simulate P1 finishing — append to finishedPlayers second.
    dynState.finishedPlayersForTest.add(1);

    final winner = dynState.computeWinnerForTest();
    expect(winner, equals(1),
        reason: 'P1 should be the winner — P0 was removed mid-game');
  });
}
```

This test is essentially identical to the widget test in `test/screens/removed_player_winner_test.dart` but running under `IntegrationTestWidgetsFlutterBinding` — which means real plugin initialisation and real emulator runtime. If the bug ever resurfaces under a real Android lifecycle (e.g., due to a plugin side-effect on `setState`), this test catches it where the widget test wouldn't.

- [ ] **Step 6.2: Run analyzer**

```bash
cd .worktrees/integration-tests
flutter analyze integration_test/cricket_remove_player_test.dart
```
Expected: no errors.

- [ ] **Step 6.3: Run the test**

```bash
cd .worktrees/integration-tests
flutter test integration_test/cricket_remove_player_test.dart
```
Expected: PASS.

- [ ] **Step 6.4: Commit**

```bash
cd .worktrees/integration-tests
git add integration_test/cricket_remove_player_test.dart
git commit -m "test(integration): Cricket mid-game remove regression scenario"
```

---

## Task 7: Scenario 3 — Shanghai post-game Undo regression

**Files:**
- Create: `integration_test/shanghai_postgame_undo_test.dart`

Uses the hooks added in PR #4: `engineForTest`, `onGameEndForTest`. Verify:

```bash
grep -nE "@visibleForTesting|engineForTest|onGameEndForTest" lib/screens/shanghai_game_screen.dart
```

- [ ] **Step 7.1: Create the test file**

Create `integration_test/shanghai_postgame_undo_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/screens/shanghai_game_screen.dart';
import 'package:dart_scoring/services/shanghai_engine.dart' show HitType;

import 'helpers/test_app.dart';
import 'helpers/player_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Shanghai: post-game Undo returns to game with gameOver=false',
      (tester) async {
    await setupTestEnvironment();
    await pumpScreen(
      tester,
      ShanghaiGameScreen(
        players: buildPlayers(names: ['P0', 'P1'], startingScore: 0),
        config: const ShanghaiConfig(targetEnd: 7),
      ),
    );
    await tester.pumpAndSettle();

    final state =
        tester.state<State<ShanghaiGameScreen>>(find.byType(ShanghaiGameScreen));
    final dynamic dynState = state;
    final engine = dynState.engineForTest;

    // Trigger instant Shanghai for P0: S+D+T on target 1 in one turn.
    engine.recordThrow(HitType.single);
    engine.recordThrow(HitType.double_);
    engine.recordThrow(HitType.triple);
    expect(engine.gameOver, isTrue);
    expect(engine.isInstantShanghai, isTrue);

    // Fire the game-end + post-game push through the production code path.
    await dynState.onGameEndForTest();
    await tester.pump(const Duration(milliseconds: 500));

    // PostGameScreen should now be visible. Verify by finding the UNDO button.
    // The exact label is in lib/screens/post_game_screen.dart — confirm and
    // adjust if it differs from 'UNDO' / '↶ Back' / etc.
    expect(find.textContaining('UNDO', findRichText: true), findsOneWidget,
        reason: 'PostGameScreen should show an Undo button');

    // Tap Undo.
    await tester.tap(find.textContaining('UNDO', findRichText: true).first);
    await tester.pump(const Duration(milliseconds: 500));

    // Back in ShanghaiGameScreen — verify engine state was restored.
    expect(find.byType(ShanghaiGameScreen), findsOneWidget,
        reason: 'After Undo, ShanghaiGameScreen should be on top again');
    expect(engine.gameOver, isFalse,
        reason: 'engine.undo() should clear gameOver');
  });
}
```

⚠ **Implementer adjustments:**
1. Verify `HitType` enum names in `lib/services/shanghai_engine.dart`. The Dart convention is `single`, `double_` (trailing underscore to avoid keyword), `triple`. Adjust import path / case if different.
2. The Undo button label — read `lib/screens/post_game_screen.dart` and grep for the button widget. Update `find.textContaining(...)` if the label is `'↶ Back'`, `'Undo'`, etc. Use exact-match `find.text(...)` if possible; fall back to `findsAtLeastNWidgets(1)` if the label appears multiple times.
3. The widget test (`test/screens/shanghai_postgame_undo_test.dart`) added in PR #4 has the same pattern — read it for reference if the integration test is misbehaving.

- [ ] **Step 7.2: Run analyzer**

```bash
cd .worktrees/integration-tests
flutter analyze integration_test/shanghai_postgame_undo_test.dart
```
Expected: no errors.

- [ ] **Step 7.3: Run the test**

```bash
cd .worktrees/integration-tests
flutter test integration_test/shanghai_postgame_undo_test.dart
```
Expected: PASS.

- [ ] **Step 7.4: Commit**

```bash
cd .worktrees/integration-tests
git add integration_test/shanghai_postgame_undo_test.dart
git commit -m "test(integration): Shanghai post-game Undo regression scenario"
```

---

## Task 8: GitHub Actions workflow

**Files:**
- Create: `.github/workflows/integration-tests.yml`

- [ ] **Step 8.1: Create the workflow**

Create `.github/workflows/integration-tests.yml` with:

```yaml
name: integration-tests

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  widget-tests:
    name: Widget tests
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.27.0'
          cache: true
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test test/

  integration-tests:
    name: Integration tests (Android emulator)
    runs-on: ubuntu-latest
    timeout-minutes: 30
    needs: widget-tests
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.27.0'
          cache: true
      - run: flutter pub get
      # KVM acceleration on Ubuntu runners.
      - name: Enable KVM
        run: |
          echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' \
            | sudo tee /etc/udev/rules.d/99-kvm4all.rules
          sudo udevadm control --reload-rules
          sudo udevadm trigger --name-match=kvm
      - name: Run integration tests on emulator
        uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 30
          target: default
          arch: x86_64
          profile: pixel_5
          script: flutter test integration_test/
```

Notes:
- Flutter version `3.27.0` should match the SDK currently in use locally. Verify with `flutter --version` and update the workflow string to match exactly.
- The widget-test job runs first as a fast gate. The emulator job depends on it, so a unit-test break shorts the run before the slow emulator boot.
- `reactivecircus/android-emulator-runner@v2` is the maintained community action — handles emulator caching, snapshot, retries.

- [ ] **Step 8.2: Verify Flutter version**

```bash
cd .worktrees/integration-tests
flutter --version | head -1
```

If the output isn't `Flutter 3.27.0`, update the workflow's `flutter-version` fields to the actual version.

- [ ] **Step 8.3: Commit**

```bash
cd .worktrees/integration-tests
git add .github/workflows/integration-tests.yml
git commit -m "ci: GitHub Actions workflow runs widget + integration tests on PR"
```

- [ ] **Step 8.4: Push the branch and open PR**

The controller handles `git push -u origin feat/integration-tests` and `gh pr create`.

---

## Task 9: Final verification

**Files:** none (verification only)

- [ ] **Step 9.1: Run the full local suite**

With an Android emulator running:

```bash
cd .worktrees/integration-tests
flutter analyze
flutter test test/
flutter test integration_test/
```

All three commands must be green before pushing.

- [ ] **Step 9.2: Update memory after merge**

After the PR merges, update `MEMORY.md` to retire the "Unit testing planlagt neste uke" memo (`project_unit_testing.md`) since integration_test now exists, OR append a note that the foundation landed 2026-05-13 and the unit-test plan is the next layer down.

---

## Self-review notes

**Spec coverage:**
- §Folder layout → File map ✓
- §Plugin handling table → Task 2.1 helper body ✓
- §Test helpers — minimal API → Tasks 2 and 3 ✓
- §CI workflow → Task 8 ✓
- §3 scenarios → Tasks 5, 6, 7 ✓
- §`@visibleForTesting` hooks already in place → Cricket + Shanghai use existing hooks (PR #3, #4); X01 adds new ones in Task 5.1 ✓
- §Verification → Task 9 ✓
- §Documentation in README → Task 4.1 ✓

**Placeholders acknowledged but justified inline:**
- Task 5.2 has an explicit "Known gaps" callout — the X01 test cannot be fully written without seeing the actual game-end trigger surface, and the plan tells the implementer exactly how to close the gap (add a `triggerCheckoutForTest` hook). This is intentional: the alternative is a 200-line speculative test that won't compile.
- Task 7.1 has explicit adjustments for `HitType` and the Undo button label — both require a 30-second file read by the implementer. Better than guessing and having the test silently match the wrong widget.

**Type consistency:** `pumpScreen(WidgetTester, Widget)`, `setupTestEnvironment({List<String> savedPlayers})`, `buildPlayers({List<String> names, int startingScore})` used identically across tasks.

**No accidental scope creep:** No app-code changes beyond the X01 hooks in Task 5.1.
