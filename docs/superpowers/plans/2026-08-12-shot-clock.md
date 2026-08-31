# Shot Clock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nudge a player who has not thrown 60 seconds after their turn began, and count how often that happens.

**Architecture:** One service, `ShotClock`, owns a single timer and a per-name tally for the current game — the same singleton-with-`disableForTest` shape as `BatterySampler`. Three hooks connect it: turn start goes through `GameAnnouncer.announceNextPlayer`, which every mode already calls on every turn change; the dart side is wired at each screen's `throwHistory.add`; and `StatsRecorder.recordGame` merges the tally into `modeStats` at game end. No new storage and no new `SavedPlayer` field.

**Tech Stack:** Flutter / Dart, `flutter_test`. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-08-12-shot-clock-design.md`.

## Global Constraints

- Code and comments in **English**. UI strings **English** (a guard test fails the build on Norwegian strings).
- **Nudge threshold: 60 s, adjustable in Settings, OFF by default.** **Counter threshold: fixed 60 s, never adjustable** — a comparable number requires a fixed bar.
- **The counter runs even when the nudge is off.** Turning off the noise must not turn off the scoreboard.
- The game's **first turn never counts**.
- **No timer may outlive the screen.** `test/flutter_test_config.dart` fails any test leaving one pending; `ShotClock` gets a `disableForTest` like `BatterySampler`, `SoundService` and `VideoService`.
- Run `flutter analyze lib test` and `flutter test` before each commit.

---

### Task 1: The ShotClock service

**Files:**
- Create: `lib/services/shot_clock.dart`
- Modify: `lib/services/app_settings.dart`
- Test: `test/services/shot_clock_test.dart` (create)

**Interfaces:**
- Produces:
  - `ShotClock.instance` with `startTurn(String playerName)`, `registerDart()`, `stop()`, `resetGame()`
  - `int ShotClock.slowTurnsFor(String playerName)`
  - `Map<String, int> get slowTurnsByName`
  - `@visibleForTesting static bool disableForTest`
  - `@visibleForTesting static Duration Function()? elapsedOverride`
  - `AppSettings.getShotClockEnabled/setShotClockEnabled` (bool, default **false**)
  - `AppSettings.getShotClockSeconds/setShotClockSeconds` (int, default **60**)
  - `const int kSlowTurnSeconds = 60;`

**Context the implementer needs:**

Two clocks that must not be confused. `kSlowTurnSeconds` is a **fixed 60** and decides whether a turn is counted. The Settings value decides only when the *nudge* fires and defaults to the same 60 — but a player who sets it to 90 still gets counted at 60.

**The failure direction is chosen deliberately.** `startTurn` closes any open turn as *unmeasured*: a turn only counts if `registerDart` explicitly ends it. So a mode whose dart hook is missed records **nothing** rather than flagging every turn as slow. Silent under-count beats accusing everyone.

Time is measured with a `Stopwatch`, and the nudge fires from a `Timer`. Tests need to control both, so the elapsed reading goes through one overridable seam:

```dart
  /// Elapsed since the current turn began. Overridable so tests can place a
  /// dart at 59 s or 61 s without waiting.
  @visibleForTesting
  static Duration Function()? elapsedOverride;
```

- [ ] **Step 1: Write the failing test**

```dart
// test/services/shot_clock_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/services/shot_clock.dart';

void main() {
  setUp(() {
    ShotClock.instance.resetGame();
    ShotClock.disableForTest = true; // no real Timer in unit tests
  });

  tearDown(() {
    ShotClock.elapsedOverride = null;
    ShotClock.disableForTest = false;
  });

  void turnTaking(String name, int seconds) {
    ShotClock.instance.startTurn(name);
    ShotClock.elapsedOverride = () => Duration(seconds: seconds);
    ShotClock.instance.registerDart();
  }

  test('the first turn of a game never counts, however long it takes', () {
    turnTaking('Ada', 600);
    expect(ShotClock.instance.slowTurnsFor('Ada'), 0);
  });

  test('the 60 second bar is exclusive on one side and inclusive on the other',
      () {
    turnTaking('Ada', 1); // first turn — ignored
    turnTaking('Ada', 59);
    expect(ShotClock.instance.slowTurnsFor('Ada'), 0);
    turnTaking('Ada', 61);
    expect(ShotClock.instance.slowTurnsFor('Ada'), 1);
  });

  test('slow turns accumulate per player', () {
    turnTaking('Ada', 1); // first turn
    turnTaking('Ada', 90);
    turnTaking('Bo', 90);
    turnTaking('Ada', 90);
    expect(ShotClock.instance.slowTurnsFor('Ada'), 2);
    expect(ShotClock.instance.slowTurnsFor('Bo'), 1);
  });

  test('a turn with no dart records nothing, even a very long one', () {
    ShotClock.instance.startTurn('Ada'); // first turn
    ShotClock.instance.startTurn('Bo');
    ShotClock.elapsedOverride = () => const Duration(hours: 8);
    ShotClock.instance.startTurn('Ada'); // Bo never threw

    expect(ShotClock.instance.slowTurnsFor('Bo'), 0,
        reason: 'an abandoned turn is not a slow turn — nobody was there');
  });

  test('only the first dart of a turn measures it', () {
    turnTaking('Ada', 1); // first turn
    ShotClock.instance.startTurn('Ada');
    ShotClock.elapsedOverride = () => const Duration(seconds: 90);
    ShotClock.instance.registerDart();
    ShotClock.instance.registerDart();
    ShotClock.instance.registerDart();

    expect(ShotClock.instance.slowTurnsFor('Ada'), 1,
        reason: 'three darts in one turn is still one slow turn');
  });

  test('stop ends the turn without measuring it', () {
    turnTaking('Ada', 1); // first turn
    ShotClock.instance.startTurn('Ada');
    ShotClock.elapsedOverride = () => const Duration(seconds: 90);
    ShotClock.instance.stop();
    ShotClock.instance.registerDart();

    expect(ShotClock.instance.slowTurnsFor('Ada'), 0);
  });

  test('resetGame clears the tally and the first-turn grace returns', () {
    turnTaking('Ada', 1);
    turnTaking('Ada', 90);
    expect(ShotClock.instance.slowTurnsFor('Ada'), 1);

    ShotClock.instance.resetGame();

    expect(ShotClock.instance.slowTurnsFor('Ada'), 0);
    turnTaking('Ada', 600);
    expect(ShotClock.instance.slowTurnsFor('Ada'), 0,
        reason: 'a new game gets its first-turn grace back');
  });

  test('an unknown name has no slow turns', () {
    expect(ShotClock.instance.slowTurnsFor('Nobody'), 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/shot_clock_test.dart`
Expected: FAIL — `lib/services/shot_clock.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Add to `AppSettings`, following the existing getter/setter pairs:

```dart
  // Shot clock
  static const String _shotClockEnabledKey = 'shot_clock_enabled';
  static const String _shotClockSecondsKey = 'shot_clock_seconds';

  /// Off by default: an app that nags uninvited is worse than the problem.
  /// The COUNTER is unaffected by this — see kSlowTurnSeconds.
  static Future<bool> getShotClockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_shotClockEnabledKey) ?? false;
  }

  static Future<void> setShotClockEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shotClockEnabledKey, value);
  }

  /// When the nudge fires, in seconds. Default 60.
  static Future<int> getShotClockSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_shotClockSecondsKey) ?? 60;
  }

  static Future<void> setShotClockSeconds(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_shotClockSecondsKey, value);
  }
```

Create `lib/services/shot_clock.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_settings.dart';
import 'game_announcer.dart';
import 'sound_service.dart';

/// The bar a turn must cross to be COUNTED as slow. Fixed on purpose: the
/// Settings value moves only when the nudge sounds, so two players' counts
/// always mean the same thing.
const int kSlowTurnSeconds = 60;

/// Measures the gap between a turn starting and that player's first dart,
/// nudges when it runs long, and tallies how often it happens.
class ShotClock {
  ShotClock._();
  static final ShotClock instance = ShotClock._();

  /// Prevents a real Timer from outliving a widget test — the same guard
  /// BatterySampler, SoundService and VideoService carry.
  @visibleForTesting
  static bool disableForTest = false;

  /// Elapsed since the current turn began. Overridable so tests can place a
  /// dart at 59 s or 61 s without waiting.
  @visibleForTesting
  static Duration Function()? elapsedOverride;

  final Map<String, int> _slowTurns = {};
  final Stopwatch _watch = Stopwatch();
  Timer? _nudge;
  Timer? _sting;
  String? _currentPlayer;

  /// True until the first turn of a game has been started. People are finding
  /// darts and agreeing who goes first — nagging then is unfair, and counting
  /// it would pollute every game with setup time.
  bool _isFirstTurn = true;

  Map<String, int> get slowTurnsByName => Map.unmodifiable(_slowTurns);
  int slowTurnsFor(String playerName) => _slowTurns[playerName] ?? 0;

  Duration get _elapsed => elapsedOverride?.call() ?? _watch.elapsed;

  /// A new turn began. Any turn still open is closed UNMEASURED: a turn only
  /// counts when a dart explicitly ends it, so a mode missing its dart hook
  /// under-counts silently rather than flagging every turn as slow.
  void startTurn(String playerName) {
    _cancelTimers();
    final wasFirst = _isFirstTurn;
    _isFirstTurn = false;
    if (wasFirst) {
      _currentPlayer = null;
      return;
    }
    _currentPlayer = playerName;
    _watch
      ..reset()
      ..start();
    _scheduleNudges(playerName);
  }

  /// The current player threw. Only the first dart of a turn measures it.
  void registerDart() {
    final player = _currentPlayer;
    if (player == null) return;
    if (_elapsed.inSeconds > kSlowTurnSeconds) {
      _slowTurns[player] = (_slowTurns[player] ?? 0) + 1;
    }
    stop();
  }

  /// Ends the turn without measuring it — game end, undo, dispose.
  void stop() {
    _cancelTimers();
    _watch.stop();
    _currentPlayer = null;
  }

  /// A new game. Clears the tally and restores the first-turn grace.
  void resetGame() {
    stop();
    _slowTurns.clear();
    _isFirstTurn = true;
  }

  void _cancelTimers() {
    _nudge?.cancel();
    _nudge = null;
    _sting?.cancel();
    _sting = null;
  }

  void _scheduleNudges(String playerName) {
    if (disableForTest) return;
    AppSettings.getShotClockEnabled().then((enabled) {
      if (!enabled || _currentPlayer != playerName) return;
      AppSettings.getShotClockSeconds().then((seconds) {
        if (_currentPlayer != playerName) return;
        _nudge = Timer(Duration(seconds: seconds), () {
          if (_currentPlayer != playerName) return;
          GameAnnouncer().announceNextPlayer(playerName);
        });
        _sting = Timer(Duration(seconds: seconds + 30), () {
          if (_currentPlayer != playerName) return;
          // An empty assets/sounds/slow/ folder degrades to silence.
          SoundService.instance.playRandom(['slow']);
        });
      });
    });
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/shot_clock_test.dart`
Expected: PASS — 8 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/services/shot_clock.dart lib/services/app_settings.dart test/services/shot_clock_test.dart
git commit -m "feat(shot-clock): the service, with a fixed counting bar"
```

---

### Task 2: Wire the two hooks

**Files:**
- Modify: `lib/services/game_announcer.dart`
- Modify: the `throwHistory.add(` / `_statThrows.add(` site in each of the ten game screens (11 sites — `game_screen.dart` has two)
- Test: `test/services/shot_clock_wiring_test.dart` (create)

**Interfaces:**
- Consumes: `ShotClock.instance.startTurn/registerDart` from Task 1.

**Context:** Turn start needs no per-screen work. Every mode calls
`GameAnnouncer.announceNextPlayer` on every turn change, and the TTS setting is gated *inside* the
method rather than at the call sites — so hooking the top of it covers all ten modes whether or not
the player has TTS on.

The dart side has no such chokepoint, so it is wired where each screen appends the throw. Find them
with:

```bash
grep -rn "throwHistory.add(\|_statThrows.add(" lib/screens/*.dart
```

Expect exactly 11: one per screen, two in `game_screen.dart`.

The tally is keyed by **player name**, which is all `announceNextPlayer` carries. Two players with
the same name in one game share a count. That is rare, harmless, and cheaper than threading a seat
index through ten call sites.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/shot_clock_wiring_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/services/game_announcer.dart';
import 'package:dart_scoring/services/shot_clock.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ShotClock.instance.resetGame();
    ShotClock.disableForTest = true;
  });

  tearDown(() {
    ShotClock.elapsedOverride = null;
    ShotClock.disableForTest = false;
  });

  test('announcing the next player starts the clock', () {
    final announcer = GameAnnouncer();

    announcer.announceNextPlayer('Ada'); // first turn — grace
    announcer.announceNextPlayer('Bo');
    ShotClock.elapsedOverride = () => const Duration(seconds: 90);
    ShotClock.instance.registerDart();

    expect(ShotClock.instance.slowTurnsFor('Bo'), 1,
        reason: 'the announcer is the universal turn-change hook');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/shot_clock_wiring_test.dart`
Expected: FAIL — `Expected: 1, Actual: 0`; the announcer does not start the clock yet.

- [ ] **Step 3: Write the implementation**

In `lib/services/game_announcer.dart`, add the import and hook the top of the method — **before**
the TTS gate, so the clock runs regardless of whether the player has announcements on:

```dart
  void announceNextPlayer(String name) {
    // The universal turn-change hook. Placed above the TTS gate on purpose:
    // the shot clock must run whether or not this player has announcements on.
    ShotClock.instance.startTurn(name);
    if (_nextPlayer) _tts.speak(name);
  }
```

Then add `ShotClock.instance.registerDart();` immediately after each of the 11 throw-append sites.
For example, in `lib/screens/cricket_game_screen.dart`:

```dart
      throwHistory.add(dartThrow);
      ShotClock.instance.registerDart();
```

Add `import '../services/shot_clock.dart';` to each screen touched.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/shot_clock_wiring_test.dart && flutter analyze lib && flutter test`
Expected: PASS. Verify the count first — `grep -c "ShotClock.instance.registerDart" lib/screens/*.dart | grep -v ":0"` must total 11.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(shot-clock): hook turn start in the announcer and darts in each cockpit"
```

---

### Task 3: Record the tally and show it

**Files:**
- Modify: `lib/services/stats_recorder.dart`
- Modify: `lib/stats/profile_stats.dart`
- Test: `test/services/shot_clock_stats_test.dart` (create)

**Interfaces:**
- Consumes: `ShotClock.instance.slowTurnsFor`, `ShotClock.instance.resetGame` from Task 1.
- Produces: a `slowTurns` counter inside each mode's `ModeStats.counters`, and a `SLOW TURNS`
  `RecordTile` from `careerRecords`.

**Context:** `StatsRecorder.recordGame` already receives `playerNames` alongside `playerIds` and
already merges a `modeCounters` map into `SavedPlayer.modeStats`. Merging the tally there covers
all ten modes in one place instead of ten screens each remembering to pass it.

`recordGame` also calls `ShotClock.instance.resetGame()` after merging, so the next game starts
with an empty tally and its first-turn grace restored. That is the only reset the feature needs.

The profile tile goes through `careerRecords`, whose grid resolves an unknown mode key to
`DossedartTokens.phosphor` (`_modeAccent[r.mode] ?? ...`) — so a cross-cutting tile passes
`mode: ''` and needs no change to the grid.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/shot_clock_stats_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/shot_clock.dart';
import 'package:dart_scoring/services/stats_recorder.dart';
import 'package:dart_scoring/stats/profile_stats.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ShotClock.instance.resetGame();
    ShotClock.disableForTest = true;
  });

  tearDown(() {
    ShotClock.elapsedOverride = null;
    ShotClock.disableForTest = false;
  });

  void slowTurn(String name) {
    ShotClock.instance.startTurn(name);
    ShotClock.elapsedOverride = () => const Duration(seconds: 90);
    ShotClock.instance.registerDart();
  }

  test('the tally lands in modeStats and the clock resets for the next game',
      () {
    ShotClock.instance.startTurn('Ada'); // first turn — grace
    slowTurn('Ada');
    slowTurn('Ada');

    final ada = SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026));
    StatsRecorder.recordGame(
      gameMode: 'x01',
      playerIds: const ['a'],
      playerNames: const ['Ada'],
      placements: const [1],
      savedPlayers: [ada],
    );

    expect(ada.modeStats['x01']!.get('slowTurns'), 2);
    expect(ShotClock.instance.slowTurnsFor('Ada'), 0,
        reason: 'the tally is per game and resets once recorded');
  });

  test('a clean game records no counter at all', () {
    final ada = SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026));
    StatsRecorder.recordGame(
      gameMode: 'x01',
      playerIds: const ['a'],
      playerNames: const ['Ada'],
      placements: const [1],
      savedPlayers: [ada],
    );
    expect(ada.modeStats['x01']?.get('slowTurns') ?? 0, 0);
  });

  test('the profile sums slow turns across modes', () {
    final ada = SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026));
    ada.modeStats['x01'] = ModeStats(played: 5, counters: {'slowTurns': 4});
    ada.modeStats['cricket'] = ModeStats(played: 3, counters: {'slowTurns': 3});

    final tile =
        careerRecords(ada).firstWhere((r) => r.label == 'slow turns');

    expect(tile.value, '7');
  });

  test('a player who has never dawdled gets no tile', () {
    final ada = SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026));
    ada.modeStats['x01'] = ModeStats(played: 5);

    expect(careerRecords(ada).where((r) => r.label == 'slow turns'), isEmpty,
        reason: 'an empty shame counter is not worth a tile');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/shot_clock_stats_test.dart`
Expected: FAIL — `slowTurns` is 0 in the first test; no `slow turns` tile in the third.

- [ ] **Step 3: Write the implementation**

In `stats_recorder.dart`, inside the per-player loop where `modeCounters` is merged, add the
tally, then reset once after the loop:

```dart
      // Slow turns are collected by ShotClock during the game rather than
      // passed in by each screen — one merge point instead of ten.
      final slow = ShotClock.instance.slowTurnsFor(playerNames[i]);
      if (slow > 0) modeStat.inc('slowTurns', slow);
```

and after the loop finishes:

```dart
    // The tally is per game. Clearing it here also restores the first-turn
    // grace for the next game.
    ShotClock.instance.resetGame();
```

Add `import 'shot_clock.dart';`. Use whatever local name the existing loop already has for the
player's `ModeStats` rather than introducing `modeStat` if it differs.

In `profile_stats.dart`, inside `careerRecords`:

```dart
  // Cross-cutting, so no mode key — the grid falls back to phosphor.
  final slow = p.modeStats.values
      .fold<int>(0, (sum, m) => sum + m.get('slowTurns'));
  if (slow > 0) {
    out.add(RecordTile(mode: '', value: '$slow', label: 'slow turns'));
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/shot_clock_stats_test.dart && flutter test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(shot-clock): record the tally and show it in the profile"
```

---

### Task 4: The Settings toggle and FILIBUSTER

**Files:**
- Modify: `lib/screens/settings_screen.dart`
- Modify: `lib/data/achievement_catalog.dart`
- Test: `test/services/filibuster_test.dart` (create)

**Interfaces:**
- Consumes: `AppSettings.getShotClockEnabled/setShotClockEnabled/getShotClockSeconds/setShotClockSeconds` from Task 1.

**Context:** The Settings entry goes in the existing `SOUND EFFECTS` section — the nudge is a
sound, and a section of its own for two controls would be noise. Copy, exact:

- Switch title: `Shot clock`
- Switch subtitle: `Reminds a player who has not thrown yet. Slow turns are counted either way.`
- Slider label: `Nudge after`, value rendered as `${seconds}s`, range 30–120 in steps of 15.

The subtitle is doing real work: it is the one place the app admits that turning the switch off
does not stop the counting.

`FILIBUSTER` fires at 10 lifetime slow turns, summed across modes, and follows the catalogue's
conventions — an `x_` id for a cross-cutting badge, a globally unique name, and the quirky
category, where the self-deprecating badges live.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/filibuster_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/data/achievement_catalog.dart';
import 'package:dart_scoring/models/achievement.dart';
import 'package:dart_scoring/models/saved_player.dart';

void main() {
  bool fires(int slowTurns) {
    final p = SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026));
    p.modeStats['x01'] = ModeStats(played: 20, counters: {'slowTurns': slowTurns});
    final a = achievementCatalog.firstWhere((a) => a.id == 'x_filibuster');
    return a.milestoneTest!(AchievementContext(player: p));
  }

  test('FILIBUSTER fires at ten slow turns, not nine', () {
    expect(fires(9), isFalse);
    expect(fires(10), isTrue);
  });

  test('it counts across modes, not per mode', () {
    final p = SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026));
    p.modeStats['x01'] = ModeStats(played: 9, counters: {'slowTurns': 6});
    p.modeStats['cricket'] = ModeStats(played: 9, counters: {'slowTurns': 5});
    final a = achievementCatalog.firstWhere((a) => a.id == 'x_filibuster');

    expect(a.milestoneTest!(AchievementContext(player: p)), isTrue,
        reason: '6 + 5 crosses the bar even though neither mode does');
  });

  test('its name is unique in the catalogue', () {
    final names = achievementCatalog.map((a) => a.name).toList();
    expect(names.where((n) => n == 'FILIBUSTER').length, 1);
    expect(names.toSet().length, names.length);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/filibuster_test.dart`
Expected: FAIL — no achievement with id `x_filibuster`.

- [ ] **Step 3: Write the implementation**

Add to `achievement_catalog.dart`, beside the other `x_` cross-cutting quirky badges:

```dart
      Achievement(
        id: 'x_filibuster',
        name: 'FILIBUSTER',
        description: 'Take over a minute to throw, 10 times',
        tier: AchievementTier.bronze,
        category: AchievementCategory.quirky,
        glyph: _g(Icons.record_voice_over),
        milestoneTest: (ctx) =>
            ctx.player.modeStats.values
                .fold<int>(0, (sum, m) => sum + m.get('slowTurns')) >=
            10,
      ),
```

In `settings_screen.dart`, add two state fields loaded in `_load()` alongside the others
(`bool _shotClockEnabled = false; int _shotClockSeconds = 60;`), and add to the `SOUND EFFECTS`
card:

```dart
                      SwitchListTile(
                        title: const Text('Shot clock'),
                        subtitle: const Text(
                            'Reminds a player who has not thrown yet. '
                            'Slow turns are counted either way.'),
                        value: _shotClockEnabled,
                        onChanged: (v) {
                          setState(() => _shotClockEnabled = v);
                          AppSettings.setShotClockEnabled(v);
                        },
                      ),
                      if (_shotClockEnabled)
                        ListTile(
                          title: const Text('Nudge after'),
                          subtitle: Slider(
                            value: _shotClockSeconds.toDouble(),
                            min: 30,
                            max: 120,
                            divisions: 6,
                            label: '${_shotClockSeconds}s',
                            onChanged: (v) {
                              setState(() => _shotClockSeconds = v.round());
                              AppSettings.setShotClockSeconds(v.round());
                            },
                          ),
                          trailing: Text('${_shotClockSeconds}s'),
                        ),
```

- [ ] **Step 4: Run the full suite**

Run: `flutter analyze lib test && flutter test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(shot-clock): Settings toggle and the FILIBUSTER badge"
```

---

## Self-Review

**Spec coverage.** §1 measurement window → Task 1 (`startTurn`/`registerDart`) and Task 2 (the two
hooks). §2 two thresholds → Task 1 (`kSlowTurnSeconds` fixed, Settings adjustable) with the
counter-runs-regardless behaviour asserted in Task 1's tests and stated in Task 4's subtitle copy.
§3 escalation → Task 1's `_scheduleNudges`. §4 edge cases → Task 1 covers first turn, no-dart
turns, abandonment and cancellation; `disableForTest` covers the no-timer-outlives-the-screen rule.
§5 storage → Task 3. §6 profile tile and FILIBUSTER → Tasks 3 and 4. §7 testing → every bullet has
a test. §8 out of scope → nothing here adds a penalty, a countdown or a leaderboard.

**One spec bullet is covered by construction rather than a test:** "the clock stops on game end and
on undo". `startTurn` closes any open turn unmeasured, and a game end or undo is always followed by
either a new turn or the screen going away — so no explicit `stop()` call is needed at those sites,
and adding ten of them would be code with no behaviour. Flagged rather than silently skipped; if a
mode is ever found where an undo leaves a turn open *and* a later dart lands in the same turn, that
is the case to add.

**Placeholder scan.** No TBDs. The one judgement call left to the implementer is the local variable
name for `ModeStats` in `recordGame`'s loop, and the instruction says to match what is there.

**Type consistency.** `slowTurnsFor(String)`, `startTurn(String)`, `registerDart()`, `stop()` and
`resetGame()` keep the same signatures from Task 1 through Task 3. `kSlowTurnSeconds` is used only
inside `ShotClock`. The `slowTurns` counter key is spelled identically in Tasks 3 and 4.

**Removed from the interface block:** an early draft listed a `nowOverride` seam that the
implementation does not use — `elapsedOverride` is the only time seam.
