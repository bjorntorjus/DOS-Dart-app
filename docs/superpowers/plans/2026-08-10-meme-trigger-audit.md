# Meme Trigger Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every meme sound obeys the meme switch, the meme slider stops secretly driving the video rate, Golf and 1UP stop being meme dead zones, and the default frequency drops so the net result is fewer memes than today.

**Architecture:** Four independent fixes against existing seams. F1 moves two X01 sound calls behind the meme gate. F2 deletes a stale pre-roll in four screens so `VideoService.shouldPlay` is the only video gate. F3 wires `MemeService.onThrow`/`onTurnEnd` into Golf and 1UP, which today call only `tryMissSound`. F4 changes one default constant.

**Tech Stack:** Flutter / Dart, `flutter_test`. No new dependencies, no new assets.

## Global Constraints

- Code and comments in **English**. UI strings in **English**.
- No new meme sounds or assets; no settings-screen redesign.
- The existing meme-damping behaviour — one miss roll per turn, `markSoundPlayed` suppression, frequency 10 bypassing both gates — must keep passing untouched.
- Run `flutter test` before each commit.

---

### Task 1: F1 — X01 triple and bull sounds obey the meme switch

**Files:**
- Modify: `lib/screens/game_screen.dart:551-557`
- Test: `test/screens/x01_meme_gate_test.dart` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

**Context:** A triple on 18/19/20 calls `SoundService.instance.playRandomMaybe(['triple'], chance: vc)` and a bull calls `SoundService.instance.play('bull')` — neither checks `_memeEnabled`. The bull path uses `play()`, so it has no chance gate at all: it is the only sound in the app with no gate whatsoever. Both were decided to be memes (2026-08-10), so both go behind the switch and the frequency dice.

`_memeEnabled` is the screen's mirror of the setting, kept in sync at `game_screen.dart:224` and by the in-game toggle at `:1808-1810`. `vc` is `_meme.frequencyChance`, computed at `:363`.

- [ ] **Step 1: Write the failing test**

```dart
// test/screens/x01_meme_gate_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/services/sound_service.dart';
import 'package:dart_scoring/services/video_service.dart';

/// The meme switch must mean OFF. Two X01 sounds used to fire regardless
/// (audit 2026-08-10, F1).
void main() {
  setUp(() {
    VideoService.instance.setEnabled(false);
    SoundService.instance.playedForTest.clear();
  });

  Future<dynamic> boot(WidgetTester tester, {required bool memes}) async {
    SharedPreferences.setMockInitialValues({'meme_enabled': memes});
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        players: [Player(name: 'P0', score: 501)],
        startingScore: 501,
      ),
    ));
    await tester.pumpAndSettle();
    return tester.state<State<GameScreen>>(find.byType(GameScreen));
  }

  testWidgets('memes off: a bull plays no sound', (tester) async {
    final dynamic s = await boot(tester, memes: false);
    await s.onDartHitForTest(25, 1);
    await tester.pump();

    expect(SoundService.instance.playedForTest, isEmpty,
        reason: 'bull used to call play() unconditionally');
  });

  testWidgets('memes off: a T20 plays no sound', (tester) async {
    final dynamic s = await boot(tester, memes: false);
    await s.onDartHitForTest(20, 3);
    await tester.pump();

    expect(SoundService.instance.playedForTest, isEmpty);
  });

  testWidgets('memes on at max frequency: a bull still plays', (tester) async {
    SharedPreferences.setMockInitialValues(
        {'meme_enabled': true, 'meme_frequency': 10});
    final dynamic s = await boot(tester, memes: true);
    await s.onDartHitForTest(25, 1);
    await tester.pump();

    expect(SoundService.instance.playedForTest, isNotEmpty,
        reason: 'gating must not silence the sound when memes are ON');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/x01_meme_gate_test.dart`
Expected: FAIL — the first test finds a `bull` entry. If `SoundService.playedForTest` does not exist, a compile error instead; add it in Step 3.

- [ ] **Step 3: Write minimal implementation**

If `lib/services/sound_service.dart` has no test spy, add one next to the existing `disableForTest`-style hooks:

```dart
  /// Names passed to [play] / [playRandom] during tests, for assertions.
  /// Never populated in release paths beyond a list append.
  @visibleForTesting
  final List<String> playedForTest = [];
```

and append to it at the top of `play` and `playRandom`.

Then gate both call sites in `lib/screens/game_screen.dart:551-557`:

```dart
          // Both are memes (audit 2026-08-10, F1): they used to fire even with
          // the meme switch off, and the bull sound had no chance gate at all.
          if (_memeEnabled) {
            if (multiplier == 3 && segment >= 18 && segment <= 20) {
              if (_meme.frequency < 10) _meme.markSoundPlayed();
              SoundService.instance.playRandomMaybe(['triple'], chance: vc);
            } else if (segment == 25) {
              if (_meme.frequency < 10) _meme.markSoundPlayed();
              SoundService.instance.playRandomMaybe(['bull'], chance: vc);
            }
          }
```

Note the bull switches from `play('bull')` to `playRandomMaybe(['bull'], chance: vc)` so it obeys the frequency dice like every other meme.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/x01_meme_gate_test.dart test/screens/classic_menu_audio_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/game_screen.dart lib/services/sound_service.dart test/screens/x01_meme_gate_test.dart
git commit -m "fix(memes): X01 triple and bull sounds obey the meme switch"
```

---

### Task 2: F2 — the meme slider stops driving the video rate

**Files:**
- Modify: `lib/screens/game_screen.dart:363`, `lib/screens/cricket_game_screen.dart:166-167`, `lib/screens/around_the_clock_game_screen.dart:286`, `lib/screens/halve_it_game_screen.dart:218`
- Test: `test/services/video_gate_test.dart` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

**Context:** Four screens pre-roll their video events off the meme slider:

```dart
final vc = _meme.frequencyChance;                       // meme slider
final videoRoll = vc <= 1 || Random().nextInt(vc) == 0;
```

`VideoService.shouldPlay` then rolls the real video slider on top, so videos are double-gated with the meme slider as one gate. This is a leftover: the 2026-07-22 video-damping introduced `shouldPlay` as "the decision seam for every video" and the screen pre-roll was never removed.

**`vc` has two jobs in these files** — the video pre-roll *and*, in X01, the `chance:` argument for the meme sounds from Task 1. Only the video use goes away; keep `vc` where a meme sound reads it.

Deleting a gate makes videos slightly **more** frequent at the same slider positions. That is intended — the video slider now means what it says. The video default stays at 5.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/video_gate_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/services/app_settings.dart';
import 'package:dart_scoring/services/video_service.dart';

/// The video slider is the only thing that decides how often videos play
/// (audit 2026-08-10, F2).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('shouldPlay is driven by the video frequency, not the meme one', () async {
    await AppSettings.setVideoFrequency(10);
    await AppSettings.setMemeFrequency(1);
    await VideoService.instance.init();

    // Video frequency 10 = "always"; the meme slider must not veto it.
    expect(VideoService.instance.shouldPlay(), isTrue);
  });

  test('a low video frequency suppresses regardless of the meme slider',
      () async {
    await AppSettings.setVideoFrequency(1); // 1-in-8
    await AppSettings.setMemeFrequency(10);
    await VideoService.instance.init();

    var plays = 0;
    for (var i = 0; i < 400; i++) {
      if (VideoService.instance.shouldPlay()) plays++;
    }
    expect(plays, lessThan(120),
        reason: '1-in-8 should land far below a quarter of 400');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/video_gate_test.dart`
Expected: PASS already — `VideoService` is correct in isolation; the bug lives in the screens. Treat this file as the contract that pins F2's intent, then verify the screen change by inspection in Step 3 and by the full suite in Step 4.

- [ ] **Step 3: Write the implementation**

In each of the four screens, delete the video pre-roll and use `VideoService`'s own decision. Concretely, in `lib/screens/cricket_game_screen.dart:166-167`:

```dart
    // Video gating lives entirely in VideoService.shouldPlay (video-damping
    // 2026-07-22). The old meme-frequency pre-roll here meant the meme slider
    // silently changed how often videos played (audit 2026-08-10, F2).
    final videoRoll = VideoService.instance.shouldPlay();
```

Apply the same replacement in `around_the_clock_game_screen.dart:286` and `halve_it_game_screen.dart:218`. In `game_screen.dart:363`, keep `final vc = _meme.frequencyChance;` — Task 1's meme sounds still read it — and change only the `videoRoll` line beneath it.

Then remove any now-unused `import 'dart:math';` only if nothing else in the file uses `Random`; check with `grep -n "Random(" <file>` before deleting an import.

- [ ] **Step 4: Run the full suite**

Run: `flutter test`
Expected: PASS. Video-related screen tests that asserted a suppressed video may now see one — read each failure before touching it, and prefer `VideoService.instance.setEnabled(false)` in the test's `setUp` (the pattern already used across `test/screens/`).

- [ ] **Step 5: Commit**

```bash
git add lib/screens test/services/video_gate_test.dart
git commit -m "fix(video): meme frequency no longer drives the video rate"
```

---

### Task 3: F3 — Golf and 1UP reach the full meme path

**Files:**
- Modify: `lib/screens/golf_game_screen.dart` (around the throw handler that calls `_meme.tryMissSound()` at line 289)
- Modify: `lib/screens/one_up_game_screen.dart` (around `_meme.tryMissSound()` at line 243)
- Test: `test/screens/golf_one_up_meme_parity_test.dart` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

**Context:** Both modes call only `tryMissSound()`. Eight modes call `onThrow` per dart and `onTurnEnd` at turn end. Follow the shape already used in `gotcha_game_screen.dart:182,198` — the closest structural sibling.

**Golf needs care.** `DartThrow.points` is a placeholder in Golf (documented in `docs/superpowers/specs/2026-07-23-post-game-v2-design.md` §1), so meme paths that sum points must not be fed Golf's throws as scores:
- `onThrow(dart)` reads `segment` and `multiplier` for the 6-7 check — **safe**. Call it **without** `remainingScore`, so the "nice at 69" branch cannot fire on a meaningless number.
- `onTurnEnd()` sums `DartThrow.points` for the ≥100 / <10 round sounds — **not safe in Golf**. Call `_meme.resetTurn()` instead of `onTurnEnd()` at Golf's turn boundaries: it clears the same per-turn state without reading points. Record the reason in a comment.
- 1UP's `points` are real, so 1UP calls `onTurnEnd()` normally.

- [ ] **Step 1: Write the failing test**

```dart
// test/screens/golf_one_up_meme_parity_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/golf_game_screen.dart';
import 'package:dart_scoring/screens/one_up_game_screen.dart';
import 'package:dart_scoring/services/sound_service.dart';
import 'package:dart_scoring/services/video_service.dart';

/// Golf and 1UP used to reach only the miss meme (audit 2026-08-10, F3).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(
        {'meme_enabled': true, 'meme_frequency': 10, 'meme_67': true});
    VideoService.instance.setEnabled(false);
    SoundService.instance.playedForTest.clear();
  });

  Future<void> sized(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Golf: a 6 then a 7 triggers the six-seven meme',
      (tester) async {
    await sized(tester);
    await tester.pumpWidget(MaterialApp(
      home: GolfGameScreen(
        players: [Player(name: 'P0', score: 0), Player(name: 'P1', score: 0)],
        config: const GolfConfig(holes: 9),
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s =
        tester.state<State<GolfGameScreen>>(find.byType(GolfGameScreen));

    await s.onDartHitForTest(6, 1);
    await s.onDartHitForTest(7, 1);
    await tester.pumpAndSettle();

    expect(SoundService.instance.playedForTest.join(','), contains('six_seven'));
  });

  testWidgets('1UP: a 6 then a 7 triggers the six-seven meme', (tester) async {
    await sized(tester);
    await tester.pumpWidget(MaterialApp(
      home: OneUpGameScreen(
        players: [Player(name: 'P0', score: 0), Player(name: 'P1', score: 0)],
        config: const OneUpConfig(),
      ),
    ));
    await tester.pumpAndSettle();
    final dynamic s =
        tester.state<State<OneUpGameScreen>>(find.byType(OneUpGameScreen));

    await s.onDartHitForTest(6, 1);
    await s.onDartHitForTest(7, 1);
    await tester.pumpAndSettle();

    expect(SoundService.instance.playedForTest.join(','), contains('six_seven'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/golf_one_up_meme_parity_test.dart`
Expected: FAIL — `playedForTest` contains no `six_seven` entry, because neither screen calls `onThrow`. Adjust the test's screen constructor arguments and the `onDartHitForTest` accessor name to whatever each screen actually exposes; both already have a test-visible dart entry point used by `golf_game_screen_test.dart` and `one_up_game_screen_test.dart`.

- [ ] **Step 3: Write the implementation**

In `lib/screens/one_up_game_screen.dart`, after the throw is recorded into `throwHistory` and before TTS:

```dart
    final memeTriggered = _meme.onThrow(throwHistory.last);
```

and at the turn boundary, mirroring `gotcha_game_screen.dart:198`:

```dart
    if (result.turnEnded) _meme.onTurnEnd();
```

Skip the announcer's throw TTS when `memeTriggered` is true, the same way Gotcha does.

In `lib/screens/golf_game_screen.dart`, the same `onThrow` call **without** `remainingScore`:

```dart
    // No remainingScore: DartThrow.points is a placeholder in Golf (post-game
    // v2 spec §1), so the score-based meme branches must not see it. The 6-7
    // check reads segment/multiplier only and is safe.
    final memeTriggered = _meme.onThrow(throwHistory.last);
```

and at Golf's turn boundary, `resetTurn` rather than `onTurnEnd`:

```dart
    // resetTurn, not onTurnEnd: the end-of-round meme sums DartThrow.points,
    // which is a placeholder in Golf and would fire on a meaningless total.
    _meme.resetTurn();
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/golf_one_up_meme_parity_test.dart test/screens/golf_game_screen_test.dart test/screens/one_up_game_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/golf_game_screen.dart lib/screens/one_up_game_screen.dart test/screens/golf_one_up_meme_parity_test.dart
git commit -m "feat(memes): Golf and 1UP reach the full meme path"
```

---

### Task 4: F4 — default meme frequency 5 → 3

**Files:**
- Modify: `lib/services/app_settings.dart:226-229` (`getMemeFrequency`)
- Test: `test/services/meme_frequency_default_test.dart` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

**Context:** Task 3 adds meme paths, which works against the original "too many memes" complaint. The compensating lever is the default: 5 (1-in-3 throws) becomes 3 (1-in-5). Only clean installs are affected — a stored value always wins. `frequencyChance`'s 1..10 → chance mapping is **not** retuned.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/meme_frequency_default_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/services/app_settings.dart';
import 'package:dart_scoring/services/meme_service.dart';

void main() {
  test('a clean install defaults to 3 (1-in-5)', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await AppSettings.getMemeFrequency(), 3);

    final meme = MemeService();
    await meme.init();
    expect(meme.frequencyChance, 5);
  });

  test('a stored value always wins over the default', () async {
    SharedPreferences.setMockInitialValues({'meme_frequency': 8});
    expect(await AppSettings.getMemeFrequency(), 8);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/meme_frequency_default_test.dart`
Expected: FAIL — `Expected: 3, Actual: 5`.

- [ ] **Step 3: Write minimal implementation**

```dart
  /// Meme frequency: 1 (rare) to 10 (always). Default 3 = 1-in-5 throws
  /// (meme-damping 2026-08-10: lowered from 5 = 1-in-3 to offset Golf and 1UP
  /// gaining the full meme path). Only clean installs move — a stored value
  /// always wins.
  static Future<int> getMemeFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_memeFrequencyKey) ?? 3;
  }
```

Also update `MemeService._frequency`'s initialiser comment at `lib/services/meme_service.dart:17` if it names 5 as the default; the field itself is overwritten by `init()` and needs no value change.

- [ ] **Step 4: Run the full suite**

Run: `flutter test`
Expected: PASS. A meme test that assumed a 1-in-3 default may now roll differently — set `meme_frequency` explicitly in that test's `setMockInitialValues` rather than reverting the default.

- [ ] **Step 5: Commit**

```bash
git add lib/services/app_settings.dart lib/services/meme_service.dart test/services/meme_frequency_default_test.dart
git commit -m "fix(memes): lower the default frequency to 1-in-5"
```

---

## Self-Review

**Spec coverage.** §1 audit result (trigger is sound) → no task needed, it is a finding not a defect. §2 F1 → Task 1. §2 F2 → Task 2. §2 F3 → Task 3, including the Golf `points`-placeholder decision the spec deferred to implementation. §2 F4 → Task 4. §3 net effect → the three rows are asserted by Tasks 1, 3 and 4 respectively. §4 testing → all five bullets have a test; the "existing meme-damping behaviour must keep passing" bullet is the full-suite run in Tasks 2 and 4. §5 out of scope → no task adds assets, redesigns settings, or consolidates the six legacy in-game menus.

**Type consistency.** `SoundService.playedForTest` is introduced in Task 1 and reused in Task 3 with the same type. `VideoService.instance.shouldPlay()` keeps its existing signature.

**Known soft spots, both flagged inline rather than hidden.** Task 2 Step 2 expects its new test to pass immediately — the test pins intent, and the screen fix is verified by inspection plus the full suite. Task 3's test uses `onDartHitForTest` and constructor arguments that the implementer must match to what each screen actually exposes; both screens have an established test entry point in their existing test files.
