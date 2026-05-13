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
