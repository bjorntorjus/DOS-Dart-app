# Sound Event Hooks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire 17 new mode-specific sound hooks plus the bust-folder cleanup so Bjørn can drop sound files into per-event folders.

**Architecture:** Every hook calls `SoundService.instance.playRandom([...])` (TTS-idle-layered via `GameAnnouncer` where a phrase is spoken) or `playRandomMaybe` for frequent events. Folders without files are NOT declared in pubspec — `playRandom` is then a silent no-op (established convention, see `announceKill`'s doc comment in `lib/services/game_announcer.dart:58-65`). Tests assert via `SoundService.instance.playedForTest` (assert-only seam recording every `playRandom` call's folder list — see `test/screens/x01_meme_gate_test.dart`).

**Tech Stack:** Flutter/Dart, flutter_test, existing SoundService/GameAnnouncer/MemeService.

**Spec:** `docs/superpowers/specs/2026-08-18-sound-event-structure-design.md`

## Global Constraints

- Branch `feat/elo-seasons`, work directly, do NOT push.
- New folders snake_case: exact names from the spec table (`x01/one_eighty`, `around_the_clock/triple_jump`, …). No renames of existing `end of round` folders.
- No ungated `play()` calls (audit 2026-08-10, F1): frequent events use `playRandomMaybe` behind the meme toggle; moment events use `playRandom` layered via `_tts.callWhenIdle` and gated the way that screen's existing announcements are gated.
- Empty folders are NOT declared in `pubspec.yaml` (declaring a missing/empty asset dir breaks the build). Only `assets/sounds/bust/` gains a pubspec entry in this plan (it receives 15 real files); `assets/sounds/x01/negative/out/` loses its entry.
- Tests: drive the real screen via its `@visibleForTesting` hooks, `SoundService.instance.playedForTest.clear()` in setUp, assert the folder string appears (or doesn't). For chance-gated hooks mirror `test/screens/x01_meme_gate_test.dart`'s meme-frequency setup so the chance roll is deterministic; if that file pins frequency via `AppSettings`/`SharedPreferences.setMockInitialValues`, copy that exact mechanism.
- Line numbers below are anchors from 2026-08-18 — locate by the quoted code, not the number.
- `flutter analyze` clean before every commit.

---

### Task 1: Bust cleanup — global `bust/` folder, no double-play, explicit checkout hook

**Files:**
- Move: the 15 files `assets/sounds/x01/negative/out/*` → `assets/sounds/bust/` (git mv)
- Modify: `pubspec.yaml` (swap the `assets/sounds/x01/negative/out/` entry for `assets/sounds/bust/`)
- Modify: `lib/services/game_announcer.dart:86-90`
- Modify: `lib/screens/game_screen.dart:505-513` (bust branch), checkout branch ~line 526
- Modify: `lib/screens/gotcha_game_screen.dart:196`
- Test: `test/screens/bust_sound_routing_test.dart` (new)

**Interfaces:**
- Produces: `GameAnnouncer.announceGameEvent(String event)` keeps its signature but loses the `'Bust'`/`'Out'` sound side effects (TTS only). All bust/checkout sounds are explicit at the call sites.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/screens/gotcha_game_screen.dart';
import 'package:dart_scoring/services/sound_service.dart';
import 'package:dart_scoring/services/video_service.dart';

/// Bust cleanup (2026-08-18 sound spec): X01 busts pull from the GLOBAL
/// bust/ folder (the old x01/negative/out), Gotcha busts play the same
/// folder explicitly, and no path double-plays via announceGameEvent.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      // Pin meme frequency so chance-gated rolls always fire — copy the
      // exact key/value test/screens/x01_meme_gate_test.dart uses.
    });
    VideoService.instance.setEnabled(false);
    SoundService.instance.playedForTest.clear();
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('X01 bust plays the global bust folder, never x01/negative/out',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        players: [Player(name: 'A', score: 501), Player(name: 'B', score: 501)],
        startingScore: 501,
        masterOut: 'double',
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s = tester.state<State<GameScreen>>(find.byType(GameScreen));

    s.injectScoreForTest(0, 20);
    await s.onDartHitForTest(20, 3); // T20 over 20 remaining → BUST
    await settle(tester);

    final played = SoundService.instance.playedForTest.join(',');
    expect(played, isNot(contains('x01/negative/out')));
    // Video-vs-sound is a 50/50 roll, so bust sound MAY be absent — the
    // hard requirements are: old folder gone, and at most ONE bust entry.
    final bustHits = SoundService.instance.playedForTest
        .where((f) => f.contains('bust'))
        .length;
    expect(bustHits, lessThanOrEqualTo(1),
        reason: 'announcer + screen must not both fire a bust sound');
  });

  testWidgets('Gotcha bust plays the global bust folder exactly once',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: GotchaGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const GotchaConfig(targetScore: 301),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    final dynamic s =
        tester.state<State<GotchaGameScreen>>(find.byType(GotchaGameScreen));

    // Drive A close to target, then overshoot → bust. Use the screen's
    // dart hook (see test/screens/gotcha_game_screen_test.dart for the
    // exact name — onDartHitForTest(segment, multiplier)).
    for (var i = 0; i < 4; i++) {
      await s.onDartHitForTest(20, 3); // 4×T20 = 240
      await settle(tester);
    }
    // A at 240 after turn rotation — get A back on turn if needed; simplest:
    // read the engine and throw until the CURRENT player would bust with T20
    // when their total > 241. Adapt with engineForTest.totals as the
    // existing gotcha tests do; the assertion below is what matters.
    // ... drive to a bust ...
    final bustHits = SoundService.instance.playedForTest
        .where((f) => f == 'bust')
        .length;
    expect(bustHits, 1);
  });
}
```

(The gotcha drive-to-bust sequence must be adapted to the engine's turn
rotation — mirror `test/screens/gotcha_game_screen_test.dart`'s dart-driving
style. The X01 test is the load-bearing one; keep the gotcha test but
simplify the drive as needed, e.g. 2 players where A throws T20 until
`engineForTest.totals[0] == 300`, then T20 busts.)

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/screens/bust_sound_routing_test.dart`
Expected: FAIL — X01 still plays `x01/negative/out`.

- [ ] **Step 3: Implement**

1. `git mv assets/sounds/x01/negative/out/<each file> assets/sounds/bust/` (create the folder). Update `pubspec.yaml`: remove the `- assets/sounds/x01/negative/out/` line, add `- assets/sounds/bust/` (keep alphabetical-ish placement with the other sound entries).
2. `game_announcer.dart`: delete lines 88-89 (`if (event == 'Bust') ...play('bust')` and `if (event == 'Out') ...play('checkout')`). Update the method's doc/comment if any mentions the side effects.
3. `game_screen.dart` bust branch (~509): change `'x01/negative/out'` to `'bust'` in the `playRandomMaybe` list (offensive entry unchanged).
4. `game_screen.dart` checkout branch (after `_log.logCheckout`, ~line 526): add the explicit checkout hook — this replaces the dead `'Out'` side effect (nothing ever called `announceGameEvent('Out')`):

```dart
          // checkout/ ships no recordings yet — silent no-op until files
          // are added + declared (sound spec 2026-08-18).
          _tts // via _announcer? No: screens don't hold _tts — use the announcer:
```
   Correction — screens reach sounds via `SoundService.instance` or announcer helpers. Add to `GameAnnouncer`:

```dart
  /// X01 checkout: layer the checkout sound once TTS finishes the
  /// "<name> checks out!" line. checkout/ ships no recordings yet —
  /// playRandom is a silent no-op until files are added + declared.
  void announceCheckout(String phrase) {
    if (_gameEvents) _tts.speak(phrase);
    _tts.callWhenIdle(() => _sound.playRandom(['checkout']));
  }
```
   and in `game_screen.dart`'s checkout branch replace `_announcer.announceGameEvent('${player.name} checks out!');` with `_announcer.announceCheckout('${player.name} checks out!');`.
5. `gotcha_game_screen.dart:196`: after `_announcer.announceGameEvent('Bust');` add an explicit gated bust sound identical in spirit to X01's:

```dart
      // Explicit bust sound — announceGameEvent no longer carries it
      // (double-play fix, sound spec 2026-08-18).
      SoundService.instance.playRandomMaybe(const ['bust']);
```
   (import `../services/sound_service.dart` if missing; check whether gotcha has a meme/chance gate at this site — if the file already computes a chance value for other sounds, reuse it, otherwise the default `chance: 3` matches the F1 gating rule.)

- [ ] **Step 4: Run tests**

Run: `flutter test test/screens/bust_sound_routing_test.dart test/screens/x01_meme_gate_test.dart test/screens/gotcha_game_screen_test.dart && flutter analyze`
Expected: PASS, analyze clean. Also `flutter build apk --debug 2>&1 | tail -2` if unsure the pubspec asset swap is valid (missing-dir errors surface at build).

- [ ] **Step 5: Commit**

```powershell
git add -A -- assets/sounds pubspec.yaml lib/services/game_announcer.dart lib/screens/game_screen.dart lib/screens/gotcha_game_screen.dart test/screens/bust_sound_routing_test.dart
git commit -m "feat(sound): global bust folder, explicit checkout hook, no double-play"
```

---

### Task 2: X01 hooks — `x01/one_eighty`, `x01/sudden_death`

**Files:**
- Modify: `lib/screens/game_screen.dart` (turn-total block ~579-585, `_startSuddenDeath` ~1029-1053)
- Test: `test/screens/x01_sound_hooks_test.dart` (new)

**Interfaces:**
- Consumes: `SoundService.instance.playRandom/playRandomMaybe`, `playedForTest`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/services/sound_service.dart';
import 'package:dart_scoring/services/video_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoService.instance.setEnabled(false);
    SoundService.instance.playedForTest.clear();
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<dynamic> pumpGame(WidgetTester tester, {int players = 2}) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        players: [
          for (var i = 0; i < players; i++)
            Player(name: String.fromCharCode(65 + i), score: 501),
        ],
        startingScore: 501,
        masterOut: 'double',
      ),
    ));
    await tester.pumpAndSettle();
    return tester.state<State<GameScreen>>(find.byType(GameScreen));
  }

  testWidgets('a 180 turn plays x01/one_eighty', (tester) async {
    final s = await pumpGame(tester);
    await s.onDartHitForTest(20, 3);
    await s.onDartHitForTest(20, 3);
    await s.onDartHitForTest(20, 3); // 180!
    await settle(tester);
    expect(SoundService.instance.playedForTest.join(','),
        contains('x01/one_eighty'));
  });

  testWidgets('a 174 turn does NOT play x01/one_eighty', (tester) async {
    final s = await pumpGame(tester);
    await s.onDartHitForTest(20, 3);
    await s.onDartHitForTest(20, 3);
    await s.onDartHitForTest(18, 3); // 174
    await settle(tester);
    expect(SoundService.instance.playedForTest.join(','),
        isNot(contains('x01/one_eighty')));
  });

  testWidgets('sudden death start plays x01/sudden_death', (tester) async {
    final s = await pumpGame(tester);
    // Force the tie → sudden-death path the way
    // test/screens/x01_sudden_death_stats_test.dart does: both players
    // checkout on equal darts in the same round. Copy that file's drive
    // sequence verbatim, then:
    await settle(tester);
    expect(SoundService.instance.playedForTest.join(','),
        contains('x01/sudden_death'));
  });
}
```

(For the sudden-death drive, copy the exact throw sequence from
`test/screens/x01_sudden_death_stats_test.dart` — it already produces a
sudden death deterministically.)

- [ ] **Step 2: Run to verify failure** — `flutter test test/screens/x01_sound_hooks_test.dart` → FAIL (folder strings absent).

- [ ] **Step 3: Implement**

1. In the turn-end block where `turnTotal` is computed (~582, `final turnTotal = scoreAtStartOfTurn - player.score;`):

```dart
            if (turnTotal == 180) {
              // ONE HUNDRED AND EIGHTY — dedicated folder trumps the
              // generic triple sting. Ships no recordings yet.
              _meme.markSoundPlayed();
              SoundService.instance.playRandom(const ['x01/one_eighty']);
            }
```
   Place it so it wins over/coexists with the existing high-round video logic without double-marking; if `_memeEnabled` gates the surrounding block, keep the hook inside the same gate.
2. In `_startSuddenDeath` (right after `_announcer.announceGameEvent('Sudden death!');` at the end of the method):

```dart
    // sudden_death/ ships no recordings yet — silent until files land.
    SoundService.instance.playRandom(const ['x01/sudden_death']);
```

- [ ] **Step 4: Run** — `flutter test test/screens/x01_sound_hooks_test.dart test/screens/x01_meme_gate_test.dart test/screens/x01_sudden_death_stats_test.dart && flutter analyze` → PASS.

- [ ] **Step 5: Commit** — `git add lib/screens/game_screen.dart test/screens/x01_sound_hooks_test.dart` + `git commit -m "feat(sound): x01 one-eighty and sudden-death hooks"`

---

### Task 3: Cricket hooks — `cricket/closed`, `cricket/closed_all`

**Files:**
- Modify: `lib/screens/cricket_game_screen.dart` (hit-registration result handling, ~`_registerHit`/`_onHit` around lines 250-330)
- Test: `test/screens/cricket_sound_hooks_test.dart` (new)

**Interfaces:**
- Consumes: `CricketEngine.allClosedByPlayer(int)` (`lib/models/cricket_engine.dart:83`), the engine's per-dart result (check its result type for a "just closed a number" signal — the engine tracks marks; the 3rd own-mark on a target is the close. If the result exposes no flag, detect it in the screen: marks before vs after the dart).

- [ ] **Step 1: Write the failing test**

Harness: pump `CricketGameScreen` (2 players, `CricketConfig(isRandom: false, targetCount: 7, includeBull: true, isCutthroat: false)`), same mock setup as Task 2's test (prefs, VideoService off, `playedForTest.clear()`), drive via `registerHitForTest(segment, multiplier)`.

```dart
  testWidgets('closing a number plays cricket/closed', (tester) async {
    final s = await pumpGame(tester);
    await s.registerHitForTest(20, 3); // T20 = 3 marks = closed
    await settle(tester);
    expect(SoundService.instance.playedForTest.join(','),
        contains('cricket/closed'));
  });

  testWidgets('two marks do NOT play cricket/closed', (tester) async {
    final s = await pumpGame(tester);
    await s.registerHitForTest(20, 2); // D20 = 2 marks — not closed
    await settle(tester);
    expect(SoundService.instance.playedForTest.join(','),
        isNot(contains('cricket/closed')));
  });

  testWidgets('closing the last target plays cricket/closed_all (not just closed)',
      (tester) async {
    final s = await pumpGame(tester);
    // Close 15-20 with triples + bull with 3 singles over A's turns, with
    // B throwing misses between (mirror the drive in
    // test/screens/cricket_continue_prompt_test.dart's finishPlayerA).
    // After the LAST close (the 3rd bull single):
    expect(SoundService.instance.playedForTest.join(','),
        contains('cricket/closed_all'));
  });
```

The chance-gated `cricket/closed` needs a deterministic roll: give the hook `playRandomMaybe(const ['cricket/closed'], chance: X)` where X comes from the same meme-frequency mechanism X01 uses (`vc` in game_screen); in the test pin the frequency the way `x01_meme_gate_test.dart` does so chance == 1. If cricket has no meme-frequency plumbing, use `playRandomMaybe` with the default and make the test assertion tolerant is NOT acceptable — instead pin `chance: 1` is wrong too (always plays). Correct approach: cricket screen already computes a video/meme chance somewhere (`videoRoll`/`vc` pattern) — reuse it; if truly absent, import the same AppSettings frequency lookup game_screen uses.

- [ ] **Step 2: Run to verify failure** → folder strings absent.

- [ ] **Step 3: Implement**

In the screen's hit-result handling, where a dart's marks are applied (locate the code that updates `marks`/plays existing sounds after `engine` applies the hit):

```dart
    // Own-close detection: this dart brought the target from <3 to >=3 marks.
    final closedNow = /* marks-after >= 3 && marks-before < 3, own board */;
    if (closedNow) {
      if (engine.allClosedByPlayer(currentPlayerIndex)) {
        // Big moment: every target closed — full-volume, no chance gate.
        SoundService.instance.playRandom(const ['cricket/closed_all']);
      } else {
        SoundService.instance.playRandomMaybe(const ['cricket/closed'],
            chance: /* the screen's existing frequency-derived chance */);
      }
    }
```

Marks-before must be captured before the engine applies the dart (the screen already reads `engine`/`marks` state around the hit — anchor: the `_registerHit` body). `closed_all` fires INSTEAD of `closed`, never both.

- [ ] **Step 4: Run** — new test + all existing cricket tests → PASS, analyze clean.

- [ ] **Step 5: Commit** — `git commit -m "feat(sound): cricket closed and closed-all hooks"`

---

### Task 4: ATC hooks — `around_the_clock/triple_jump`, `around_the_clock/final_target`

**Files:**
- Modify: `lib/screens/around_the_clock_game_screen.dart` (~318-345: the `steps`/`_advanceTarget` hit block)
- Test: `test/screens/atc_sound_hooks_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Harness like `test/screens/atc_continue_prompt_test.dart` (3-player pump, `AroundTheClockConfig(includeBull: false, countMultiples: true, reverse: false)`, `onDartHitForTest`).

```dart
  testWidgets('a triple advance (3 steps) plays triple_jump', (tester) async {
    final s = await pumpGame(tester);
    await s.onDartHitForTest(1, 3); // T1 at target 1 → 3 steps
    await settle(tester);
    expect(SoundService.instance.playedForTest.join(','),
        contains('around_the_clock/triple_jump'));
  });

  testWidgets('a single advance does NOT play triple_jump', (tester) async {
    final s = await pumpGame(tester);
    await s.onDartHitForTest(1, 1);
    await settle(tester);
    expect(SoundService.instance.playedForTest.join(','),
        isNot(contains('around_the_clock/triple_jump')));
  });

  testWidgets('arriving at the final target plays final_target', (tester) async {
    final s = await pumpGame(tester);
    // Advance A to target 19 (reads currentTargetsForTest, throws triples
    // like atc_continue_prompt_test's finishPlayerA loop), then hit 19
    // single → arrives at 20 (the last target with includeBull: false).
    expect(SoundService.instance.playedForTest.join(','),
        contains('around_the_clock/final_target'));
  });
```

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement** — in the hit block after `currentTargets[currentPlayerIndex] = nextTarget;` (~331):

```dart
        if (steps >= 3) {
          SoundService.instance
              .playRandomMaybe(const ['around_the_clock/triple_jump']);
        }
        // Final target = the last number of the play sequence (20, or bull
        // when includeBull; reversed sequences end on 1/25 — derive from
        // the same sequence _advanceTarget walks, do NOT hardcode 20).
        if (/* nextTarget is the sequence's last element && player not finished */) {
          SoundService.instance
              .playRandom(const ['around_the_clock/final_target']);
        }
```

The sequence's last element: reuse the existing `_atcSequence()` helper (`around_the_clock_game_screen.dart:1163-1171` builds the exact ordered list incl. reverse/bull) — `_atcSequence().last`. `final_target` fires only on ARRIVAL (nextTarget == last && target != last before the dart).

- [ ] **Step 4: Run** — new test + existing ATC tests → PASS, analyze clean.

- [ ] **Step 5: Commit** — `git commit -m "feat(sound): atc triple-jump and final-target hooks"`

---

### Task 5: Killer hooks — `killer/became_killer`, `killer/self_hit`

**Files:**
- Modify: `lib/screens/killer_game_screen.dart` (the hit-resolution block that already plays `killer/hit` / `killer/death` at ~514-525 — the became-killer and self-hit branches live in the same result handling; locate via the engine result flags / the `'Suicide'` label logic referenced at ~1377)
- Test: `test/screens/killer_sound_hooks_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Harness: pump `KillerGameScreen` with 3 players and `KillerConfig(throwToPick: false, lives: 3, multiplyHits: false, shields: false, suicide: true)` (throwToPick false skips the pick phase if the config supports preassigned numbers — check how `test/screens/killer_kills_undo_test.dart` sets up numbers and copy its harness verbatim; it already drives hits/deaths).

```dart
  testWidgets('hitting own double plays killer/became_killer', (tester) async {
    // A hits their own number's double → becomes killer.
    expect(SoundService.instance.playedForTest.join(','),
        contains('killer/became_killer'));
  });

  testWidgets('a killer hitting their own number plays killer/self_hit',
      (tester) async {
    // A (killer) hits own number again with suicide: true → loses life.
    expect(SoundService.instance.playedForTest.join(','),
        contains('killer/self_hit'));
  });
```

(Fill the drive sequences from `killer_kills_undo_test.dart`'s helpers — it knows each seat's assigned number and how to hit doubles.)

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement** — in the same result-handling that plays `killer/hit`/`killer/death`:

```dart
      // Became killer this dart (was not killer before it):
      SoundService.instance.playRandom(const ['killer/became_killer']);
      // Self-hit (suicide rule cost a life on own number):
      SoundService.instance.playRandom(const ['killer/self_hit']);
```

Wire each into the branch the screen already distinguishes (it labels `'Suicide'` in `lastThrowLabel` and fires `AchievementEvent.becameKiller` — those two branch points are the anchors). Moment events → plain `playRandom`, no chance gate. If TTS speaks a phrase in the same branch, layer via `_announcer`-style `callWhenIdle` only if the file already does so for `killer/hit`; otherwise match the existing direct `SoundService.instance.playRandom([...])` style at 514-525.

- [ ] **Step 4: Run** — new test + `killer_kills_undo_test.dart` → PASS, analyze clean.

- [ ] **Step 5: Commit** — `git commit -m "feat(sound): killer became-killer and self-hit hooks"`

---

### Task 6: Splitscore hooks — `halve_it/halved`, `halve_it/clutch`

**Files:**
- Modify: `lib/screens/halve_it_game_screen.dart` (~312-321: the halving block with `_announcer.announceGameEvent('Halved')`; the clutch site is the turn-end path where the LAST dart of the turn scores on the round target after the first two missed — the file already tracks CLUTCH SAVE, see the comment at line 71)
- Test: `test/screens/halve_it_sound_hooks_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Harness: mirror `test/screens/halve_it_halving_test.dart` (it drives a halving deterministically) and `halve_it_clutch_undo_test.dart` (it drives a clutch save).

```dart
  testWidgets('halving plays halve_it/halved', (tester) async {
    // Drive a full miss-turn on the round target (copy halve_it_halving_test).
    expect(SoundService.instance.playedForTest.join(','),
        contains('halve_it/halved'));
  });

  testWidgets('a clutch save plays halve_it/clutch and NOT halved',
      (tester) async {
    // Two misses then a hit on the round target with the 3rd dart
    // (copy halve_it_clutch_undo_test's drive).
    final played = SoundService.instance.playedForTest.join(',');
    expect(played, contains('halve_it/clutch'));
    expect(played, isNot(contains('halve_it/halved')));
  });
```

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement**

1. Halving block (~316-321), next to `_announcer.announceGameEvent('Halved');`:

```dart
      SoundService.instance.playRandom(const ['halve_it/halved']);
```
2. Clutch: at the site where the screen detects the third-dart save (the CLUTCH SAVE tracking referenced at line 71 — find where that flag/achievement is set):

```dart
      SoundService.instance.playRandom(const ['halve_it/clutch']);
```

- [ ] **Step 4: Run** — new test + `halve_it_halving_test.dart` + `halve_it_clutch_undo_test.dart` + `halve_it_keypad_test.dart` → PASS, analyze clean.

- [ ] **Step 5: Commit** — `git commit -m "feat(sound): splitscore halved and clutch hooks"`

---

### Task 7: Shanghai hooks — `shanghai/shanghai`, `shanghai/hole_cleared`

**Files:**
- Modify: `lib/screens/shanghai_game_screen.dart` (instant-Shanghai branch ~344; the turn-end path for hole_cleared — all 3 darts of the turn hit the round's number without being an instant Shanghai; the screen tracks `_turnHits`, see `_rebuildTurnHits`)
- Test: `test/screens/shanghai_sound_hooks_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Harness: pump `ShanghaiGameScreen` (2 players, `ShanghaiConfig(targetEnd: 7)`), drive via its dart hook (check the exact `@visibleForTesting` name in the file — the shanghai tests in `test/screens/` use it).

```dart
  testWidgets('instant shanghai plays shanghai/shanghai', (tester) async {
    // Round 1 target = 1: throw S1, D1, T1 in one turn.
    expect(SoundService.instance.playedForTest.join(','),
        contains('shanghai/shanghai'));
  });

  testWidgets('three singles on the target play hole_cleared, not shanghai',
      (tester) async {
    // S1, S1, S1.
    final played = SoundService.instance.playedForTest.join(',');
    expect(played, contains('shanghai/hole_cleared'));
    expect(played, isNot(contains('shanghai/shanghai')));
  });

  testWidgets('two hits and a miss play neither', (tester) async {
    final played = SoundService.instance.playedForTest.join(',');
    expect(played, isNot(contains('shanghai/')));
  });
```

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement**

1. Instant-Shanghai branch (~344, `if (engine.isInstantShanghai)`):

```dart
      SoundService.instance.playRandom(const ['shanghai/shanghai']);
```
   (before the winner flow so it layers under the win announcement).
2. Turn-end: when the completed turn's three darts all hit the round number and it was NOT an instant Shanghai:

```dart
      SoundService.instance.playRandomMaybe(const ['shanghai/hole_cleared']);
```
   Detect from the same turn data the screen already keeps (`_turnHits` has the per-dart hit types; three non-miss entries on turn end = cleared). Place in the turn-end handling after the engine banks the turn.

- [ ] **Step 4: Run** — new test + existing shanghai tests → PASS, analyze clean.

- [ ] **Step 5: Commit** — `git commit -m "feat(sound): shanghai instant and hole-cleared hooks"`

---

### Task 8: Wildcard hooks — `wildcard/rewind`, `wildcard/cut`, `wildcard/event`

**Files:**
- Modify: `lib/screens/wildcard_game_screen.dart` (`_routeDartResult`'s direct-to-event branch — the joker path that calls `_logJokerEvent`/`_overlayKindForEvent`, ~338-360)
- Test: extend `test/screens/wildcard_game_screen_test.dart`

- [ ] **Step 1: Write the failing test** (add to the existing file, reusing its harness and forced-event helpers):

```dart
  testWidgets('a joker-fired REWIND plays wildcard/rewind', (tester) async {
    // Copy the rewind-forcing drive from the existing REWIND reveal test,
    // with SoundService.instance.playedForTest.clear() before the joker dart.
    expect(SoundService.instance.playedForTest.join(','),
        contains('wildcard/rewind'));
  });

  testWidgets('a joker-fired SCORE SWAP plays wildcard/event (not rewind/cut)',
      (tester) async {
    final played = SoundService.instance.playedForTest.join(',');
    expect(played, contains('wildcard/event'));
    expect(played, isNot(contains('wildcard/rewind')));
    expect(played, isNot(contains('wildcard/cut')));
  });
```

(CUT! variant analogous via `debugForceEvent('cutEvent')` — three tests total.)

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement** — in `_routeDartResult`'s evented-joker branch, right after `_announceEvent(event);`:

```dart
        // Event sting layered after the 'Joker!' + event TTS.
        final folder = switch (event.id) {
          'rewindEvent' => 'wildcard/rewind',
          'cutEvent' => 'wildcard/cut',
          _ => 'wildcard/event',
        };
        SoundService.instance.playRandom([folder]);
```

(If the announcer exposes a `callWhenIdle` layering path the screen uses elsewhere, prefer it; otherwise the direct call matches the game-events gating because it only ever fires on a joker event.)

- [ ] **Step 4: Run** — `flutter test test/screens/wildcard_game_screen_test.dart` → PASS, analyze clean.

- [ ] **Step 5: Commit** — `git commit -m "feat(sound): wildcard rewind, cut and event hooks"`

---

### Task 9: 1UP hooks + sound-folder docs + full verification

**Files:**
- Modify: `lib/screens/one_up_game_screen.dart` (~287-299: the announceOneUp block)
- Create: `docs/sound-folders.md`
- Test: `test/screens/one_up_sound_hooks_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Harness: mirror `test/screens/one_up_game_screen_test.dart`.

```dart
  testWidgets('dropping to the last life plays one_up/last_life', (tester) async {
    // Drive a player from 2 lives to 1 (copy the life-loss drive from
    // one_up_game_screen_test.dart).
    expect(SoundService.instance.playedForTest.join(','),
        contains('one_up/last_life'));
  });

  testWidgets('a high target moment plays one_up/target_set', (tester) async {
    // Drive the "Beat that!" branch (result.targetSet / big target — the
    // branch at one_up_game_screen.dart:298).
    expect(SoundService.instance.playedForTest.join(','),
        contains('one_up/target_set'));
  });
```

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement**

1. Life-lost branch (~291-296): when the player's remaining lives == 1 after the loss, pass BOTH folders:

```dart
      _announcer.announceOneUp('$name loses a life!',
          soundFolders: engine.livesLeft[seat] == 1
              ? const ['one_up/last_life']
              : const ['one_up/life_lost']);
```
   (`seat` = the player who lost the life — use the same index the branch already uses for `$name`. last_life REPLACES life_lost for that moment, no double sound.)
2. "Beat that!" branch (~298):

```dart
      _announcer.announceOneUp('${engine.target}! Beat that!',
          soundFolders: const ['one_up/target_set']);
```
3. `docs/sound-folders.md`: one table with EVERY folder from the spec (global + per mode), columns: Folder | Event | Status (`har filer` / `venter på filer — udeklarert i pubspec`). Include the pubspec reminder line: "Når du legger filer i en 'venter'-mappe: legg også mappen til under flutter/assets i pubspec.yaml."

- [ ] **Step 4: Full verification**

Run: `flutter test` (full suite) and `flutter analyze`.
Expected: analyze clean; all tests pass (baseline 1126 + the new hook tests). Known flake: `dossedart_setup_scaffold_test.dart` — rerun standalone if it is the only failure.

- [ ] **Step 5: Commit**

```powershell
git add lib/screens/one_up_game_screen.dart test/screens/one_up_sound_hooks_test.dart docs/sound-folders.md
git commit -m "feat(sound): one-up last-life and target-set hooks + sound folder docs"
```
