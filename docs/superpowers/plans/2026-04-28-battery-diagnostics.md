# Battery Diagnostics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `BatterySampler` service and a `LogMode` toggle to `GameLogger` so battery drop per minute can be measured during a game and correlated with in-game events. The existing log share button delivers the file. Enables A/B test of whether the logger itself contributes to drain.

**Architecture:** New singleton `BatterySampler` runs a `Timer.periodic(30s)` only while a game is active. It writes battery samples through `GameLogger.logBattery(...)`. `GameLogger` reads a `LogMode` setting (`full`/`minimal`/`off`) — in `minimal`, only battery events pass through. Game screens wire `start()` at `logGameStart` and `stop()` at `logGameEnd` + `dispose`.

**Tech Stack:** Flutter, Dart, `battery_plus` (new), `shared_preferences` (existing).

---

## File Structure

**New files:**
- `lib/services/battery_sampler.dart` — singleton, sampling timer, calls `GameLogger.logBattery`

**Modified files:**
- `pubspec.yaml` — add `battery_plus` dependency
- `lib/services/app_settings.dart` — add `LogMode` enum + getter/setter
- `lib/services/game_logger.dart` — add `LogMode` gating + `logBattery` method
- `lib/screens/settings_screen.dart` — add Debug section with 3-way log mode selector
- `lib/screens/game_screen.dart` (X01) — wire `start`/`stop`
- `lib/screens/cricket_game_screen.dart` — wire `start`/`stop`
- `lib/screens/around_the_clock_game_screen.dart` — wire `start`/`stop`
- `lib/screens/killer_game_screen.dart` — wire `start`/`stop`
- `lib/screens/halve_it_game_screen.dart` — wire `start`/`stop`

**Note on testing:** This codebase has no existing unit tests (per the `project_unit_testing.md` memory, tests are planned but not yet started). The TDD steps below use the standard Flutter test runner; if a test file does not yet exist, create it as shown.

---

### Task 1: Add `battery_plus` dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add dependency**

In `pubspec.yaml`, add `battery_plus: ^6.0.0` to the `dependencies:` block, alphabetically between `audioplayers` and `cupertino_icons`:

```yaml
dependencies:
  flutter:
    sdk: flutter

  cupertino_icons: ^1.0.8
  audioplayers: ^6.0.0
  battery_plus: ^6.0.0
  shared_preferences: ^2.3.0
  flutter_tts: ^4.2.0
  video_player: ^2.9.2
  image_picker: ^1.1.2
  path_provider: ^2.1.5
  path: ^1.9.0
  share_plus: ^13.0.0
```

- [ ] **Step 2: Fetch the package**

Run: `flutter pub get`
Expected: `Got dependencies!` with no errors. `battery_plus` and its platform dependencies appear in `pubspec.lock`.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "feat: add battery_plus dependency for battery diagnostics"
```

---

### Task 2: Add `LogMode` enum and settings getter/setter

**Files:**
- Modify: `lib/services/app_settings.dart`
- Test: `test/services/app_settings_log_mode_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/services/app_settings_log_mode_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/services/app_settings.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('default log mode is full', () async {
    expect(await AppSettings.getLogMode(), LogMode.full);
  });

  test('persists log mode across reads', () async {
    await AppSettings.setLogMode(LogMode.minimal);
    expect(await AppSettings.getLogMode(), LogMode.minimal);

    await AppSettings.setLogMode(LogMode.off);
    expect(await AppSettings.getLogMode(), LogMode.off);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/app_settings_log_mode_test.dart`
Expected: FAIL — `LogMode` is not defined and `getLogMode`/`setLogMode` do not exist.

- [ ] **Step 3: Add the enum and getter/setter**

In `lib/services/app_settings.dart`, add at the top of the file (after the import on line 1):

```dart
enum LogMode { full, minimal, off }
```

In the `AppSettings` class, add a key constant alongside the others (e.g., after `_ttsVoiceKey`):

```dart
  // Logging
  static const String _logModeKey = 'log_mode';
```

At the end of the `AppSettings` class (before the closing `}`), add:

```dart
  // Log mode getters/setters
  static Future<LogMode> getLogMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_logModeKey) ?? 'full';
    return LogMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => LogMode.full,
    );
  }

  static Future<void> setLogMode(LogMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_logModeKey, mode.name);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/app_settings_log_mode_test.dart`
Expected: PASS — both tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/services/app_settings.dart test/services/app_settings_log_mode_test.dart
git commit -m "feat(settings): add LogMode enum and persistence"
```

---

### Task 3: Gate `GameLogger` writes by `LogMode` and add `logBattery`

**Files:**
- Modify: `lib/services/game_logger.dart`
- Test: `test/services/game_logger_log_mode_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/services/game_logger_log_mode_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/services/app_settings.dart';
import 'package:dart_scoring/services/game_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mode setter exposes current mode', () {
    GameLogger.instance.setMode(LogMode.full);
    expect(GameLogger.instance.mode, LogMode.full);

    GameLogger.instance.setMode(LogMode.minimal);
    expect(GameLogger.instance.mode, LogMode.minimal);

    GameLogger.instance.setMode(LogMode.off);
    expect(GameLogger.instance.mode, LogMode.off);
  });

  test('isBatteryAllowed reflects mode rules', () {
    GameLogger.instance.setMode(LogMode.full);
    expect(GameLogger.instance.isBatteryAllowed, isTrue);

    GameLogger.instance.setMode(LogMode.minimal);
    expect(GameLogger.instance.isBatteryAllowed, isTrue);

    GameLogger.instance.setMode(LogMode.off);
    expect(GameLogger.instance.isBatteryAllowed, isFalse);
  });

  test('isGeneralAllowed reflects mode rules', () {
    GameLogger.instance.setMode(LogMode.full);
    expect(GameLogger.instance.isGeneralAllowed, isTrue);

    GameLogger.instance.setMode(LogMode.minimal);
    expect(GameLogger.instance.isGeneralAllowed, isFalse);

    GameLogger.instance.setMode(LogMode.off);
    expect(GameLogger.instance.isGeneralAllowed, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/game_logger_log_mode_test.dart`
Expected: FAIL — `setMode`, `mode`, `isBatteryAllowed`, `isGeneralAllowed` not defined.

- [ ] **Step 3: Add mode field, gating helpers, and `logBattery` to `GameLogger`**

In `lib/services/game_logger.dart`, add the import at the top:

```dart
import 'app_settings.dart';
```

In the `GameLogger` class, just below the existing fields (after `int _gameIndex = 0;` on line 14), add:

```dart
  LogMode _mode = LogMode.full;

  LogMode get mode => _mode;
  void setMode(LogMode value) => _mode = value;

  bool get isBatteryAllowed => _mode != LogMode.off;
  bool get isGeneralAllowed => _mode == LogMode.full;
```

Update `init()` (currently at line 16) to load the mode after the existing init logic completes. Replace the body of `init()` with:

```dart
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logDir = Directory('${dir.path}/game_logs');
      if (!await _logDir!.exists()) {
        await _logDir!.create(recursive: true);
      }
      final today = _todayString();
      _logFile = File('${_logDir!.path}/game_log_$today.txt');
      await _cleanOldLogs();
    } catch (e) {
      debugPrint('GameLogger init failed: $e');
    }
    _mode = await AppSettings.getLogMode();
  }
```

Gate every public log method (`logGameStart`, `logGameEnd`, `logTurnStart`, `logThrow`, `logBust`, `logCheckout`, `logFinish`, `logAdvance`, `logRoundComplete`, `logResolve`, `logPostGame`, `logUndo`, `logState`, `logSound`, `logMeme`, `logTts`, `logError`, `log`) by adding this guard as the very first statement inside each:

```dart
    if (!isGeneralAllowed) return;
```

Add a new `logBattery` method in the "Generic" section (just before the existing `void log(String message)` method around line 247):

```dart
  void logBattery({required int level, required String state}) {
    if (!isBatteryAllowed) return;
    _write('BATTERY level=$level% state=$state');
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/game_logger_log_mode_test.dart`
Expected: PASS — all three tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/services/game_logger.dart test/services/game_logger_log_mode_test.dart
git commit -m "feat(logger): gate writes by LogMode and add logBattery"
```

---

### Task 4: Create `BatterySampler` service

**Files:**
- Create: `lib/services/battery_sampler.dart`
- Test: `test/services/battery_sampler_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/services/battery_sampler_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/services/battery_sampler.dart';

void main() {
  test('start sets running, stop clears it', () {
    final sampler = BatterySampler.instance;
    expect(sampler.isRunning, isFalse);

    sampler.start('Cricket');
    expect(sampler.isRunning, isTrue);

    sampler.stop();
    expect(sampler.isRunning, isFalse);
  });

  test('stop is idempotent when not running', () {
    final sampler = BatterySampler.instance;
    sampler.stop();
    sampler.stop();
    expect(sampler.isRunning, isFalse);
  });

  test('start while running is a no-op (no double timer)', () {
    final sampler = BatterySampler.instance;
    sampler.start('Cricket');
    sampler.start('X01');
    expect(sampler.isRunning, isTrue);
    sampler.stop();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/battery_sampler_test.dart`
Expected: FAIL — file `lib/services/battery_sampler.dart` does not exist.

- [ ] **Step 3: Create the service**

Create `lib/services/battery_sampler.dart`:

```dart
import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'game_logger.dart';

/// Periodically samples battery level/state during an active game and writes
/// the result to GameLogger. Active only between start() and stop() — never
/// runs globally. On API failure, logs once and stops trying.
class BatterySampler {
  BatterySampler._();
  static final BatterySampler instance = BatterySampler._();

  static const Duration _interval = Duration(seconds: 30);

  final Battery _battery = Battery();
  Timer? _timer;
  bool _failed = false;

  bool get isRunning => _timer != null;

  void start(String gameMode) {
    if (_timer != null) return;
    _failed = false;
    _sampleNow();
    _timer = Timer.periodic(_interval, (_) => _sampleNow());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _sampleNow() async {
    if (_failed) return;
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      GameLogger.instance.logBattery(
        level: level,
        state: state.name,
      );
    } catch (e) {
      _failed = true;
      GameLogger.instance.logError('BatterySampler failed; halting samples', e);
      debugPrint('BatterySampler error: $e');
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/battery_sampler_test.dart`
Expected: PASS — all three tests pass. (Tests do not exercise the actual battery API; they verify lifecycle/state. The first sample call may fail silently in the test environment, which is fine.)

- [ ] **Step 5: Commit**

```bash
git add lib/services/battery_sampler.dart test/services/battery_sampler_test.dart
git commit -m "feat(diagnostics): add BatterySampler service"
```

---

### Task 5: Add Debug section to settings screen

**Files:**
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Read existing settings_screen.dart to find the right insertion point**

Run: `grep -n "build(BuildContext" lib/screens/settings_screen.dart` and skim the build method to find a logical place for a new section (typically near the existing TTS or "send log" section).

- [ ] **Step 2: Add state field and load it in initState**

In the `_SettingsScreenState` class, add a new field alongside existing settings state:

```dart
  LogMode _logMode = LogMode.full;
```

Make sure `app_settings.dart` is imported (it almost certainly already is — check the import block at top of file). If not, add:

```dart
import '../services/app_settings.dart';
import '../services/game_logger.dart';
```

In the existing `initState()` (or wherever async settings are loaded — look for an `_load()` helper), add:

```dart
    _logMode = await AppSettings.getLogMode();
```

…and update the surrounding `setState` callback so the field gets reflected in UI.

- [ ] **Step 3: Add the Debug section UI**

In the `build` method, add a new section near the bottom (e.g., after existing TTS/sound sections, before "send log" if present). Use the same visual pattern as other sections in this file:

```dart
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Debug',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Log mode',
            style: TextStyle(fontSize: 14),
          ),
        ),
        RadioListTile<LogMode>(
          title: const Text('Full (every event)'),
          value: LogMode.full,
          groupValue: _logMode,
          onChanged: (v) async {
            if (v == null) return;
            await AppSettings.setLogMode(v);
            GameLogger.instance.setMode(v);
            setState(() => _logMode = v);
          },
        ),
        RadioListTile<LogMode>(
          title: const Text('Minimal (battery only)'),
          value: LogMode.minimal,
          groupValue: _logMode,
          onChanged: (v) async {
            if (v == null) return;
            await AppSettings.setLogMode(v);
            GameLogger.instance.setMode(v);
            setState(() => _logMode = v);
          },
        ),
        RadioListTile<LogMode>(
          title: const Text('Off'),
          value: LogMode.off,
          groupValue: _logMode,
          onChanged: (v) async {
            if (v == null) return;
            await AppSettings.setLogMode(v);
            GameLogger.instance.setMode(v);
            setState(() => _logMode = v);
          },
        ),
```

- [ ] **Step 4: Manually verify in the running app**

Run: `flutter run` on the connected tablet (or emulator).
Open Settings, scroll to Debug section. Verify:
- Three radio options appear: Full, Minimal, Off.
- Tapping each one persists across app restart (kill the app, reopen, return to Settings — the previously selected option is checked).

If `flutter run` is not available in this environment, skip this step and rely on the next task's wiring + an APK build at the end.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat(settings): add Debug section with log mode selector"
```

---

### Task 6: Wire `BatterySampler` into X01 game screen (`game_screen.dart`)

**Files:**
- Modify: `lib/screens/game_screen.dart` (around lines 79-103, 586, 683, 949)

- [ ] **Step 1: Add import**

At the top of `lib/screens/game_screen.dart`, add (next to the existing service imports):

```dart
import '../services/battery_sampler.dart';
```

- [ ] **Step 2: Start sampler at logGameStart**

Find the `_log.logGameStart(...)` call near line 85. Immediately after that call returns (next statement), add:

```dart
    BatterySampler.instance.start('X01');
```

- [ ] **Step 3: Stop sampler at every logGameEnd call site**

For each `_log.logGameEnd(...)` call (lines 586, 683, 949), add immediately after:

```dart
      BatterySampler.instance.stop();
```

- [ ] **Step 4: Defensive stop in dispose**

The screen already has a `dispose()` at line 101. Add this line as the first statement inside `dispose()` (before `super.dispose()`):

```dart
    BatterySampler.instance.stop();
```

- [ ] **Step 5: Smoke check — start a game, exit it**

If a device/emulator is available, run the app, start an X01 game, and let it sit for 35 seconds. Then exit. Send the log via the existing share button and verify it contains at least two `BATTERY level=...` lines.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/game_screen.dart
git commit -m "feat(x01): wire BatterySampler start/stop"
```

---

### Task 7: Wire `BatterySampler` into Cricket

**Files:**
- Modify: `lib/screens/cricket_game_screen.dart` (around lines 64-82, 546)

- [ ] **Step 1: Add import**

Add to the top of `lib/screens/cricket_game_screen.dart`:

```dart
import '../services/battery_sampler.dart';
```

- [ ] **Step 2: Start sampler after logGameStart**

Find `_log.logGameStart(...)` near line 78. Immediately after the call ends, add:

```dart
    BatterySampler.instance.start('Cricket');
```

- [ ] **Step 3: Stop sampler after logGameEnd**

Find `_log.logGameEnd(...)` near line 546. Immediately after the call ends, add:

```dart
    BatterySampler.instance.stop();
```

- [ ] **Step 4: Add defensive stop in dispose**

Cricket screen does not currently override `dispose()`. Add this method to `_CricketGameScreenState` (place it just below `initState`):

```dart
  @override
  void dispose() {
    BatterySampler.instance.stop();
    super.dispose();
  }
```

- [ ] **Step 5: Commit**

```bash
git add lib/screens/cricket_game_screen.dart
git commit -m "feat(cricket): wire BatterySampler start/stop"
```

---

### Task 8: Wire `BatterySampler` into Around the Clock

**Files:**
- Modify: `lib/screens/around_the_clock_game_screen.dart` (around lines 79-95, 844)

- [ ] **Step 1: Add import**

Add to the top of `lib/screens/around_the_clock_game_screen.dart`:

```dart
import '../services/battery_sampler.dart';
```

- [ ] **Step 2: Start sampler after logGameStart**

Find `_log.logGameStart(...)` near line 90. Immediately after the call ends, add:

```dart
    BatterySampler.instance.start('AroundTheClock');
```

- [ ] **Step 3: Stop sampler after logGameEnd**

Find `_log.logGameEnd(...)` near line 844. Immediately after the call ends, add:

```dart
    BatterySampler.instance.stop();
```

- [ ] **Step 4: Add defensive stop in dispose**

This screen does not currently override `dispose()`. Add this method to the state class (just below `initState`):

```dart
  @override
  void dispose() {
    BatterySampler.instance.stop();
    super.dispose();
  }
```

- [ ] **Step 5: Commit**

```bash
git add lib/screens/around_the_clock_game_screen.dart
git commit -m "feat(atc): wire BatterySampler start/stop"
```

---

### Task 9: Wire `BatterySampler` into Killer

**Files:**
- Modify: `lib/screens/killer_game_screen.dart` (around lines 74-95, 646)

- [ ] **Step 1: Add import**

Add to the top of `lib/screens/killer_game_screen.dart`:

```dart
import '../services/battery_sampler.dart';
```

- [ ] **Step 2: Start sampler after logGameStart**

Find `_log.logGameStart(...)` near line 90. Immediately after the call ends, add:

```dart
    BatterySampler.instance.start('Killer');
```

- [ ] **Step 3: Stop sampler after logGameEnd**

Find `_log.logGameEnd(...)` near line 646. Immediately after the call ends, add:

```dart
    BatterySampler.instance.stop();
```

- [ ] **Step 4: Add defensive stop in dispose**

This screen does not currently override `dispose()`. Add this method to the state class (just below `initState`):

```dart
  @override
  void dispose() {
    BatterySampler.instance.stop();
    super.dispose();
  }
```

- [ ] **Step 5: Commit**

```bash
git add lib/screens/killer_game_screen.dart
git commit -m "feat(killer): wire BatterySampler start/stop"
```

---

### Task 10: Wire `BatterySampler` into Halve It

**Files:**
- Modify: `lib/screens/halve_it_game_screen.dart` (around lines 74-105, 484)

- [ ] **Step 1: Add import**

Add to the top of `lib/screens/halve_it_game_screen.dart`:

```dart
import '../services/battery_sampler.dart';
```

- [ ] **Step 2: Start sampler after logGameStart**

Find `_log.logGameStart(...)` near line 88. Immediately after the call ends, add:

```dart
    BatterySampler.instance.start('HalveIt');
```

- [ ] **Step 3: Stop sampler after logGameEnd**

Find `_log.logGameEnd(...)` near line 484. Immediately after the call ends, add:

```dart
    BatterySampler.instance.stop();
```

- [ ] **Step 4: Add defensive stop in existing dispose**

Halve It already has a `dispose()` at line 100. Add this as the first line inside `dispose()` (before `super.dispose()`):

```dart
    BatterySampler.instance.stop();
```

- [ ] **Step 5: Commit**

```bash
git add lib/screens/halve_it_game_screen.dart
git commit -m "feat(halve_it): wire BatterySampler start/stop"
```

---

### Task 11: Full verification + APK build

**Files:**
- None (verification only)

- [ ] **Step 1: Run all tests**

Run: `flutter test`
Expected: All tests pass, including the three new test files from Tasks 2–4.

- [ ] **Step 2: Static analysis**

Run: `flutter analyze`
Expected: No new warnings or errors.

- [ ] **Step 3: Bump version + commit**

In `pubspec.yaml`, bump `version` from `1.2.1+4` to `1.3.0+5`. In `lib/screens/home_screen.dart` line 61, update the version label from `'v1.2.1'` to `'v1.3.0'`.

```bash
git add pubspec.yaml lib/screens/home_screen.dart
git commit -m "chore: bump version to 1.3.0 (battery diagnostics)"
```

- [ ] **Step 4: Build APK**

Run: `flutter build apk --release`
Expected: Build completes; APK appears under `build/app/outputs/flutter-apk/app-release.apk`.

- [ ] **Step 5: A/B test protocol (manual, on the actual tablet)**

Tell Bjørn:

> Install the new APK on the tablet. Charge to 100% before each test game.
>
> **Game A — Full logging:** Settings → Debug → "Full (every event)". Start a Cricket game with the usual lineup, play ~30 minutes. Exit, and send the log via the existing share button.
>
> **Game B — Minimal logging:** Settings → Debug → "Minimal (battery only)". Charge back to 100%. Repeat the same Cricket game format and length. Send that log too.
>
> Both logs land in the same chat. I'll grep out the `BATTERY` lines, compute drop-per-minute for each, and we'll know whether the logger is part of the problem and where to look next.

- [ ] **Step 6: Push**

```bash
git push
```

---

## Self-Review

**Spec coverage:**
- Architecture (BatterySampler + LogMode + game-screen wiring) → Tasks 4, 3, 6–10 ✓
- New `battery_plus` dependency → Task 1 ✓
- `lib/services/battery_sampler.dart` (~80 lines) → Task 4 ✓
- `LogMode` enum + `log_mode` SharedPreferences key → Task 2 ✓
- `GameLogger` gating + `logBattery` → Task 3 ✓
- Settings screen Debug section → Task 5 ✓
- Game screen wiring (5 modes) → Tasks 6–10 ✓
- Log format (`BATTERY level=X% state=Y`) → Task 3 Step 3 ✓
- A/B test protocol → Task 11 Step 5 ✓
- Temperature explicitly out of scope → respected ✓

**Placeholder scan:** No TBDs, no "TODO later", no "similar to Task N" — every code block contains the actual code. Verification steps include exact commands and expected outcomes.

**Type consistency:** `LogMode` enum, `setMode`/`mode`/`isBatteryAllowed`/`isGeneralAllowed` are used consistently across Tasks 2, 3, 4, 5. `BatterySampler.instance.start(String)` and `.stop()` signatures match across Tasks 4, 6–10.

No issues found.
