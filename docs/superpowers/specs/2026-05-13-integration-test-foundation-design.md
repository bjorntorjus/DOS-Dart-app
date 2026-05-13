# Integration test foundation + 3 scenarios — design

**Date:** 2026-05-13
**Target branch:** `feat/integration-tests` (worktree `.worktrees/integration-tests`, branched from `main`)

## Problem

The Dart Scoring App has widget tests (`test/`) but no end-to-end tests. Recent bugs (Shanghai post-game Undo, removed-mid-game-player declared winner) reached production despite the widget-test suite — they involve state transitions across screens, navigation, and stats persistence that widget tests don't reliably cover. The project also has no CI, so the existing widget tests only run when someone remembers to run them locally.

## Goals

- Establish `integration_test/` foundation with deterministic setup (TTS off, video off, classic design forced, in-memory `SharedPreferences`).
- Ship three scenarios:
  1. **X01 full game (golden path)** — proves the happy-path home → setup → game → post-game flow.
  2. **Cricket with mid-game player removal** — regression for the bug fixed in PR #3.
  3. **Shanghai post-game Undo** — regression for the bug fixed in PR #4.
- Add a GitHub Actions workflow that runs `flutter test integration_test/` on an Android emulator for every PR and push to `main`.
- Document the test layout and how to add new scenarios so the user can extend it without further guidance.

## Non-goals

- Page-object framework or custom assertion DSL — would be over-engineering for 3 tests.
- DOSSEDART-design scenario — flag is preview; classic is what most users see.
- Real plugin behavior (audio, TTS, battery) — all mocked/disabled.
- Real device runs — emulator-only.
- Coverage targets / mutation testing.

## Architecture

### Folder layout

```
integration_test/
  x01_full_game_test.dart
  cricket_remove_player_test.dart
  shanghai_postgame_undo_test.dart
  helpers/
    test_app.dart        — pumpApp(tester) with all mocks + classic design forced
    player_setup.dart    — startGameWithPlayers(tester, mode, names)
  README.md              — how to run, how to add a test, what's mocked
.github/
  workflows/
    integration-tests.yml — Android emulator job, runs on PR + push to main
```

### Plugin handling

All plugins that could hang, make sound, or depend on hardware are disabled or mocked in `pumpApp`:

| Plugin / service | Strategy |
|---|---|
| `SharedPreferences` | `SharedPreferences.setMockInitialValues({...})` with deterministic flags |
| TTS (`TtsService`) | Disabled via `tts_*` settings keys = `false` |
| Audio (`SoundService` / audioplayers) | `SoundService.instance.setEnabled(false)` after `pumpApp` |
| Video events (`VideoService`) | Disabled via `video_events_enabled` = `false` |
| `battery_plus` | Mock platform channel `dev.fluttercommunity.plus/battery` returns `100`/`charging=false` |
| `image_picker` | Not exercised by these 3 scenarios |
| DOSSEDART design | `use_dossedart_design` = `false` (default anyway, but pinned for clarity) |

### Test helpers — minimal API

`integration_test/helpers/test_app.dart`:

```dart
/// Pumps the full app with deterministic settings:
/// - All TTS/sound/video disabled
/// - SharedPreferences is fresh (in-memory)
/// - DOSSEDART design forced OFF
/// - battery_plus mock channel returns 100% / not charging
///
/// Call once at the start of each test.
Future<void> pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'tts_next_player': false,
    'tts_throw_result': false,
    'tts_score': false,
    'tts_winner': false,
    'tts_game_events': false,
    'video_events_enabled': false,
    'use_dossedart_design': false,
  });

  _mockBatteryChannel();

  await tester.pumpWidget(const DartScoringApp(useDossedartDesign: false));
  await tester.pumpAndSettle();

  SoundService.instance.setEnabled(false);
}
```

`integration_test/helpers/player_setup.dart`:

```dart
/// Drives the home screen + setup flow to start a match.
/// Currently supports modes: 'X01-501', 'CRICKET', 'SHANGHAI-1-7'.
/// The mode string maps to the actual home-screen tap target.
Future<void> startGameWithPlayers(
  WidgetTester tester, {
  required String mode,
  required List<String> playerNames,
}) async {
  // Implementation tap-walks the actual UI; see plan task for details.
}
```

Both helpers stay in `integration_test/helpers/` so they're not part of the regular `test/` suite. The plan task spec will include the full helper bodies.

### CI workflow

`.github/workflows/integration-tests.yml`:

```yaml
name: integration-tests
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
jobs:
  android-emulator:
    name: Android emulator
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: '17' }
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.27.0', cache: true }
      - run: flutter pub get
      - run: flutter test test/   # existing widget tests
      - uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 30
          target: default
          arch: x86_64
          profile: pixel_5
          script: flutter test integration_test/
```

`pixel_5` profile keeps the device generic and fast-booting. `api-level: 30` is the sweet spot for stability vs feature coverage. The widget-test run is included as a free win — same workflow now also catches non-integration regressions.

The workflow is non-blocking initially (informational status check, not a required gate). The user flips it to required once it has been observed stable across several PRs.

### Scenarios

**`x01_full_game_test.dart`** (golden path):

```dart
testWidgets('X01 501: P0 finishes with double-out OFF, post-game shows P0 as winner',
    (tester) async {
  await pumpApp(tester);
  await startGameWithPlayers(tester,
      mode: 'X01-501', playerNames: ['P0', 'P1']);

  // Use a @visibleForTesting hook on GameScreen state to inject scores:
  // - P0 at score 40 (one D20 away)
  // - P1 at score 200
  // Then tap the input button for "40" (or scroll the keypad).
  // The plan task includes the full input sequence.

  // After P0 checks out:
  expect(find.text('Match Complete'), findsOneWidget);
  expect(find.text('P0'), findsWidgets);
  // Assert the winner badge / placement on P0's card.
});
```

**`cricket_remove_player_test.dart`** (regression for PR #3):

```dart
testWidgets('Cricket: removed mid-game player does not become winner',
    (tester) async {
  await pumpApp(tester);
  await startGameWithPlayers(tester,
      mode: 'CRICKET', playerNames: ['P0', 'P1', 'P2']);

  // Open mid-game player menu, remove P0.
  // Drive P1 to close all marks (via @visibleForTesting score injection).
  // Trigger the game-over check.

  expect(find.text('Match Complete'), findsOneWidget);
  // Winner card should be P1, not P0.
});
```

**`shanghai_postgame_undo_test.dart`** (regression for PR #4):

```dart
testWidgets('Shanghai: post-game Undo returns to game with gameOver=false',
    (tester) async {
  await pumpApp(tester);
  await startGameWithPlayers(tester,
      mode: 'SHANGHAI-1-7', playerNames: ['P0', 'P1']);

  // Trigger instant Shanghai for P0 via engine hook (S+D+T on 1).
  // Wait for post-game.
  expect(find.text('UNDO'), findsOneWidget);

  await tester.tap(find.text('UNDO'));
  await tester.pumpAndSettle();

  expect(find.byType(ShanghaiGameScreen), findsOneWidget);
  // engineForTest.gameOver should be false.
});
```

### `@visibleForTesting` hooks already in place

Recent PRs added `engineForTest`, `onGameEndForTest`, `removePlayerForTest`, and `computeWinnerForTest` to several game screens for widget tests. The integration tests reuse these where possible to avoid driving 50+ taps per scenario.

Driving full input sequences (e.g., 9 dart-presses per turn × N turns) is brittle and slow. Score injection via the hooks reaches the assertion state in milliseconds and still exercises the real navigation, state, and persistence paths — which is where the bugs are.

## Verification

Each scenario:
1. Runs locally via `flutter test integration_test/<name>.dart` against a connected emulator or device.
2. Runs in CI on every PR via the workflow.

Documentation in `integration_test/README.md` covers:
- How to install/start an Android emulator (`flutter emulators --launch <id>`)
- Running all integration tests vs a single one
- What's mocked and why (so a future test author doesn't fight the helpers)
- Pattern for adding a new scenario (copy helper imports, call `pumpApp`, call `startGameWithPlayers`, drive via `@visibleForTesting` hooks)

## Out of scope

- iOS / macOS / Windows / web platform tests (Android emulator only)
- Performance benchmarks
- Visual regression / golden-image tests
- DOSSEDART-design coverage
- Real-plugin (non-mocked) runs

## Commit plan

Single PR with logical commits on `feat/integration-tests`:

1. `chore(deps): add integration_test dev dependency`
2. `test(integration): foundation — pumpApp + startGameWithPlayers helpers + README`
3. `test(integration): X01 full-game golden-path scenario`
4. `test(integration): Cricket mid-game remove regression scenario`
5. `test(integration): Shanghai post-game Undo regression scenario`
6. `ci: GitHub Actions workflow runs widget + integration tests on PR`

If any single commit fails analyzer/tests, do not advance to the next.
