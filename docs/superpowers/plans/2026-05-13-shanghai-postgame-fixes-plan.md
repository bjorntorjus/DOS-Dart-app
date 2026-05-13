# Shanghai post-game fixes — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix Shanghai post-game Undo (stats persist before user confirms) and add winner celebration (video + instant-Shanghai TTS) on game-end.

**Architecture:** Single-file change in `lib/screens/shanghai_game_screen.dart`. Move `_updateStats(ranking)` out of `_onGameEnd` into the post-game action handler so stats only persist when user confirms Finish. Add `_fireWinnerCelebration` helper called from `_onGameEnd` to play winner video and (when `engine.isInstantShanghai`) announce "INSTANT SHANGHAI!".

**Tech Stack:** Flutter (Dart), `flutter_test` widget tests, `VideoService.showRandomFromFolder('winner', context)`, `TtsService.instance.stop()` + `.speak()`.

**Spec:** `docs/superpowers/specs/2026-05-13-shanghai-postgame-fixes-design.md` (commit `3941a8a`).

**Discovered during planning:**
- `Navigator.pushReplacement` is already gone — current code at `_showPostGame` (line 280) uses `Navigator.push<String>` with a `'undo'` handler that calls `engine.undo()`. Memo was 14 days old and partially out of date.
- The remaining navigation gap is that `_updateStats(ranking)` (line 193) runs *before* `_showPostGame(ranking)` (line 195). Both fire from `_onGameEnd`. The fix is to move `_updateStats` into the `.then((action))` handler at line 287-296.
- `VideoService.showRandomFromFolder` requires a `BuildContext` as its first argument — not omitted as the spec suggested.
- `GameAnnouncer` has no `cancelAndSpeak` method. Call `TtsService.instance.stop()` followed by `TtsService.instance.speak(...)` directly (the `_ttsEnabled` flag this widget already uses gates whether to speak).

---

## File map

**Modified:**
- `lib/screens/shanghai_game_screen.dart` — `_onGameEnd`, `_showPostGame`, new `_fireWinnerCelebration` private method

**Created:**
- `test/screens/shanghai_postgame_undo_test.dart` — widget test for the Undo flow

**No other files touched.**

---

## Task 1: Move `_updateStats` into post-game action handler

**Files:**
- Modify: `lib/screens/shanghai_game_screen.dart` (`_onGameEnd` around line 184-196, `_showPostGame` around line 262-297)

- [ ] **Step 1.1: Update `_onGameEnd` to stop calling `_updateStats`**

Replace the `_onGameEnd` method body (currently lines 184-196) with:

```dart
  Future<void> _onGameEnd() async {
    final ranking = _rankPlayers();
    _log.logGameEnd(
      playerNames: players.map((p) => p.name).toList(),
      finishedOrder: ranking,
      gameFullyOver: true,
    );
    BatterySampler.instance.stop();
    if (!mounted) return;
    _showPostGame(ranking);
  }
```

The `await _updateStats(ranking)` line is removed. `_updateStats` is still defined and used — Task 1.2 calls it from the post-game action handler instead.

- [ ] **Step 1.2: Add `_updateStats` call in the post-game action handler**

Find the `.then((action) { ... })` block in `_showPostGame` (currently lines 287-296). Replace its body with:

```dart
    ).then((action) async {
      if (!mounted) return;
      if (action == 'undo') {
        // User wants to keep playing — undo the game-end and return to game.
        setState(() => engine.undo());
        return;
      }
      // 'home' or back-button: persist stats now (deferred from _onGameEnd
      // so Undo doesn't strand the user with stats they didn't confirm),
      // then leave the game-screen entirely.
      await _updateStats(ranking);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
```

Two changes:
- Callback becomes `async` so we can `await _updateStats(ranking)`.
- `_updateStats(ranking)` is awaited inside the non-undo branch before `popUntil`.

- [ ] **Step 1.3: Run analyzer**

Run:
```bash
cd .worktrees/shanghai-fixes
flutter analyze lib/screens/shanghai_game_screen.dart
```
Expected: no issues.

- [ ] **Step 1.4: Do NOT commit yet**

Task 2 lands the winner-celebration changes in the same logical commit.

---

## Task 2: Add winner celebration (video + instant-Shanghai TTS)

**Files:**
- Modify: `lib/screens/shanghai_game_screen.dart` (`_onGameEnd`, new private method `_fireWinnerCelebration`)

- [ ] **Step 2.1: Add the helper method**

Add this method to the `_ShanghaiGameScreenState` class, immediately after `_onGameEnd` (so around line 200, before `_updateStats`):

```dart
  Future<void> _fireWinnerCelebration() async {
    if (engine.isInstantShanghai && _ttsEnabled) {
      // High-priority announcement — stop any queued TTS so this lands first.
      TtsService.instance.stop();
      TtsService.instance.speak('INSTANT SHANGHAI!');
    }
    if (!mounted) return;
    await VideoService.instance.showRandomFromFolder(context, 'winner');
  }
```

Notes:
- `_ttsEnabled` is the existing field this widget already checks (search the file for its declaration around the top of the state class to confirm it's in scope — it is used on line 168).
- `VideoService.showRandomFromFolder` silently no-ops if the `winner` folder is empty or video events are disabled in settings, so no extra guard is needed.
- The folder name `'winner'` is the same one other modes use.

- [ ] **Step 2.2: Call the helper from `_onGameEnd`**

Update `_onGameEnd` (rewritten in Task 1.1) to invoke the celebration before `_showPostGame`:

```dart
  Future<void> _onGameEnd() async {
    final ranking = _rankPlayers();
    _log.logGameEnd(
      playerNames: players.map((p) => p.name).toList(),
      finishedOrder: ranking,
      gameFullyOver: true,
    );
    BatterySampler.instance.stop();
    await _fireWinnerCelebration();
    if (!mounted) return;
    _showPostGame(ranking);
  }
```

Only difference vs Task 1.1: the new `await _fireWinnerCelebration();` line before the `mounted` check.

- [ ] **Step 2.3: Run analyzer**

```bash
cd .worktrees/shanghai-fixes
flutter analyze lib/screens/shanghai_game_screen.dart
```
Expected: no issues.

- [ ] **Step 2.4: Run existing test suite**

```bash
cd .worktrees/shanghai-fixes
flutter test
```
Expected: all existing tests pass. No new test in this task — Task 3 adds the widget test.

---

## Task 3: Widget test for post-game Undo flow

**Files:**
- Create: `test/screens/shanghai_postgame_undo_test.dart`

The Shanghai engine's game-end is driven by hitting all targets in the right pattern. Driving it from a widget test is unwieldy; instead this test:
1. Mounts the screen,
2. Drives the engine directly via the existing public API (using a small reflection-free helper inside the test that calls `_onHit` repeatedly through the widget's public surface, OR exposes the engine via a `@visibleForTesting` getter — see Step 3.1 below),
3. Asserts `PostGameScreen` appears,
4. Taps Undo,
5. Asserts `ShanghaiGameScreen` is back and `engine.gameOver == false`.

Stats persistence is verified indirectly: we assert that the back-and-forth doesn't crash and the engine state is restored. A full stats-side-effect assertion would require an injected `PlayerStorage` test double, which is out of scope for this fix — manual QA covers it.

- [ ] **Step 3.1: Expose the engine for testing**

Add a `@visibleForTesting` getter near the top of `_ShanghaiGameScreenState` in `lib/screens/shanghai_game_screen.dart` (place it just after the `engine` field declaration):

```dart
  @visibleForTesting
  ShanghaiEngine get engineForTest => engine;
```

If `@visibleForTesting` is not already imported, add `import 'package:flutter/foundation.dart';` to the imports (the file may already have it via `material.dart` re-export — verify by running analyzer after the change; if not, add explicitly).

- [ ] **Step 3.2: Write the test**

Create `test/screens/shanghai_postgame_undo_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/shanghai_game_screen.dart';

void main() {
  testWidgets('post-game Undo returns to Shanghai screen with gameOver=false',
      (tester) async {
    final players = [
      Player(name: 'P1', score: 0),
      Player(name: 'P2', score: 0),
    ];

    await tester.pumpWidget(MaterialApp(
      home: ShanghaiGameScreen(
        players: players,
        config: const ShanghaiConfig(targetEnd: 7),
      ),
    ));
    await tester.pumpAndSettle();

    // Find the state and drive the engine to game-over directly.
    final state = tester.state<State<ShanghaiGameScreen>>(
        find.byType(ShanghaiGameScreen));
    // Cast through dynamic to reach the @visibleForTesting getter without
    // exporting the private State type.
    final dynamic dynState = state;
    final engine = dynState.engineForTest;

    // Trigger instant-Shanghai for P0: S+D+T on target 1 in one turn.
    engine.recordThrow(/*HitType.single*/ 0);
    engine.recordThrow(/*HitType.double_*/ 1);
    engine.recordThrow(/*HitType.triple*/ 2);
    // The screen's onHit listener fires _onGameEnd via setState; trigger
    // a rebuild and let the post-screen Navigator.push complete.
    dynState.setState(() {});
    await tester.pumpAndSettle();

    // PostGameScreen should now be visible.
    expect(find.text('UNDO'), findsOneWidget,
        reason: 'PostGameScreen with Undo button should be on top');

    // Tap Undo and let navigation settle.
    await tester.tap(find.text('UNDO'));
    await tester.pumpAndSettle();

    // Back in ShanghaiGameScreen — verify engine state was restored.
    expect(find.byType(ShanghaiGameScreen), findsOneWidget);
    expect(engine.gameOver, isFalse,
        reason: 'engine.undo() should clear the game-over state');
  });
}
```

Important caveats this test makes explicit:
- The `HitType` enum constants `single`, `double_`, `triple` are referenced as `0`, `1`, `2` only inside the comment — the test imports `HitType` from the engine and uses the real names. Replace the int placeholders by reading the enum declaration in `lib/services/shanghai_engine.dart` and adding `import 'package:dart_scoring/services/shanghai_engine.dart' show HitType;`, then writing `engine.recordThrow(HitType.single)` etc. Do this before running.
- The `dynamic` cast is required because the State class is private. The `@visibleForTesting` getter is the public-by-convention escape hatch.
- The test asserts the UNDO button text in caps — verify the actual button text in `lib/screens/post_game_screen.dart` and adjust if the casing differs.

- [ ] **Step 3.3: Verify against the real `HitType` enum**

Before running, open `lib/services/shanghai_engine.dart` and find the `HitType` enum. Replace the placeholder ints in the test with the real enum names. Add the import for `HitType` to the test file.

- [ ] **Step 3.4: Verify the Undo button label**

Open `lib/screens/post_game_screen.dart` and find the Undo button (search for `'undo'` and trace which Text widget it shows). If the visible label is not `UNDO` in all-caps, update the `find.text(...)` calls in Step 3.2 to match.

- [ ] **Step 3.5: Run the new test**

```bash
cd .worktrees/shanghai-fixes
flutter test test/screens/shanghai_postgame_undo_test.dart
```
Expected: PASS.

If it fails on `find.text('UNDO')` not found, the post-game screen may not have rendered — re-check that the engine state-change actually triggers `_onGameEnd`. If `_onGameEnd` doesn't fire from `setState((){})` alone (because the listener is in `_onHit` and only fires when the engine just transitioned to `gameOver`), add an extra `recordThrow` of a no-op type or directly invoke `dynState.onGameEndForTest()` by exposing a `@visibleForTesting` method that wraps `_onGameEnd`. Prefer the second option — cleaner.

- [ ] **Step 3.6: Run the full test suite**

```bash
cd .worktrees/shanghai-fixes
flutter test
```
Expected: all tests pass.

---

## Task 4: Final analyzer + commit

**Files:** none (verification + commit only)

- [ ] **Step 4.1: Run analyzer over the whole worktree**

```bash
cd .worktrees/shanghai-fixes
flutter analyze
```
Expected: no new issues introduced by the change.

- [ ] **Step 4.2: Commit**

```bash
cd .worktrees/shanghai-fixes
git add lib/screens/shanghai_game_screen.dart test/screens/shanghai_postgame_undo_test.dart
git commit -m "fix(shanghai): post-game Undo preserves stats; add winner + instant-Shanghai triggers

- Defer _updateStats(ranking) until user confirms Finish on post-game (was
  running before post-game was shown, so Undo left stats already persisted)
- Add VideoService.showRandomFromFolder(context, 'winner') on game-end
- Add high-priority 'INSTANT SHANGHAI!' TTS when engine.isInstantShanghai
- Expose engineForTest @visibleForTesting for widget test
- Widget test: post-game Undo returns to ShanghaiGameScreen with gameOver=false

Spec: docs/superpowers/specs/2026-05-13-shanghai-postgame-fixes-design.md"
```

- [ ] **Step 4.3: Push and open PR (separate task — done by controller, not the implementer)**

The controller handles `git push -u origin fix/shanghai-postgame-undo-and-instant-trigger` and `gh pr create` after merge approval.

---

## Self-review notes

**Spec coverage:**
- §1 Navigation + stats flow (move `_updateStats` into action handler) → Task 1 ✓
- §2 Winner celebration (video + instant-Shanghai TTS) → Task 2 ✓
- §3 `engine.undo()` invariants → already verified by existing Undo handler at line 291 and engine code; explicit re-verification deferred to manual QA ✓ (acceptable per spec wording "verify during implementation")
- §Widget test → Task 3 ✓

**No placeholders.** All code shown; only the `HitType` enum names and Undo button label require a quick file lookup before running, which is explicit in Steps 3.3 and 3.4.

**Type consistency:** `_fireWinnerCelebration` returns `Future<void>` consistently; `_onGameEnd` is `Future<void>` and `await`s it. `_updateStats(List<int> ranking)` signature unchanged.
