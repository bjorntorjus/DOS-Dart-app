# Continue Dialog + Play Again Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the keep-playing/end choice out of the result screen into a game-screen dialog (X01, Cricket, ATC), make PostGameScreen always final, and add a PLAY AGAIN action that reopens setup prefilled with the previous game's rules and roster.

**Architecture:** A shared `showContinuePrompt` dialog (DOSSEDART + classic variants) replaces the provisional PostGameScreen. `GameResult.canContinue` and all provisional branches are deleted. PLAY AGAIN pops `'again'` from PostGameScreen; each game screen records deferred stats exactly like the leave path, then pushes its setup screen with new prefill parameters (`initialSelectedIds` on `DossedartSetupScaffold`, `SetupPrefill` on classic `PlayerSetupScreen`).

**Tech Stack:** Flutter (Dart), flutter_test widget tests, SharedPreferences mocks.

**Spec:** `docs/superpowers/specs/2026-08-14-continue-dialog-play-again-design.md`

## Global Constraints

- UI text is **English**. Code/comments English. (CLAUDE.md)
- Classic-track widgets use `Theme.of(context).colorScheme.<role>` only; DOSSEDART widgets use `DossedartTokens` only — never raw hex, never `colorScheme`. (CLAUDE.md palette rules)
- Stats recording stays **deferred until the user leaves** the result screen (post-game Undo must never strand persisted stats). The `'again'` path must record exactly once, same as `'home'`.
- Changes to one game mode must be mirrored in all applicable modes (consistency memory).
- Work on the current branch `feat/elo-seasons`. Do NOT push; Bjørn triggers CI.
- Run tests with `flutter test <path>` (PowerShell). Full suite at the end: `flutter test`.
- Field names of the config classes (`GotchaConfig` etc.) are used below as they appear in `_startGame` in `lib/screens/player_setup_screen.dart:484-587`; verify against `lib/models/game_config.dart` when touching each file.

---

### Task 1: `showContinuePrompt` dialog widget

**Files:**
- Create: `lib/widgets/continue_prompt_dialog.dart`
- Test: `test/widgets/continue_prompt_dialog_test.dart`

**Interfaces:**
- Produces: `Future<bool> showContinuePrompt(BuildContext context, {required String finisherName, required int remainingCount, required bool dossedart, String finishVerb = 'FINISHED'})` — returns `true` = keep playing (also on barrier dismiss), `false` = end game. Used by Tasks 3–5.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/widgets/continue_prompt_dialog.dart';

void main() {
  Future<bool?> open(WidgetTester tester,
      {required bool dossedart, String verb = 'FINISHED'}) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showContinuePrompt(
              context,
              finisherName: 'Kristian',
              remainingCount: 2,
              dossedart: dossedart,
              finishVerb: verb,
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('DOSSEDART: shows finisher, count, and both actions',
      (tester) async {
    await open(tester, dossedart: true, verb: 'CHECKED OUT');
    expect(find.text('★ KRISTIAN CHECKED OUT ★'), findsOneWidget);
    expect(find.text('2 PLAYERS CAN STILL PLAY FOR THE PLACES'), findsOneWidget);
    expect(find.text('KEEP PLAYING'), findsOneWidget);
    expect(find.text('END GAME'), findsOneWidget);
  });

  testWidgets('KEEP PLAYING returns true', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showContinuePrompt(context,
                finisherName: 'A', remainingCount: 2, dossedart: true);
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('KEEP PLAYING'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('END GAME returns false', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showContinuePrompt(context,
                finisherName: 'A', remainingCount: 2, dossedart: true);
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('END GAME'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('tapping outside the dialog returns true (safe default)',
      (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showContinuePrompt(context,
                finisherName: 'A', remainingCount: 2, dossedart: true);
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5)); // barrier
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('classic variant renders an AlertDialog with sentence copy',
      (tester) async {
    await open(tester, dossedart: false, verb: 'CHECKED OUT');
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Kristian checked out!'), findsOneWidget);
    expect(
        find.text('2 players can still play for the places.'), findsOneWidget);
    expect(find.text('Keep playing'), findsOneWidget);
    expect(find.text('End game'), findsOneWidget);
  });

  testWidgets('singular copy for one remaining player', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showContinuePrompt(context,
                finisherName: 'A', remainingCount: 1, dossedart: true);
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('1 PLAYER CAN STILL PLAY FOR THE PLACES'), findsOneWidget);
    await tester.tap(find.text('KEEP PLAYING'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/continue_prompt_dialog_test.dart`
Expected: FAIL — `continue_prompt_dialog.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:flutter/material.dart';

import '../theme/dossedart_tokens.dart';

/// Modal "keep playing or end?" prompt, shown on the GAME screen when a player
/// finishes while others can still play for the places (X01, Cricket, ATC).
/// The result screen never carries this choice — it is always final.
///
/// Returns true = keep playing (also on barrier dismiss, the safe default),
/// false = end the game now.
Future<bool> showContinuePrompt(
  BuildContext context, {
  required String finisherName,
  required int remainingCount,
  required bool dossedart,
  String finishVerb = 'FINISHED',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => dossedart
        ? _DossedartContinuePrompt(
            finisherName: finisherName,
            remainingCount: remainingCount,
            finishVerb: finishVerb,
          )
        : AlertDialog(
            title: Text('$finisherName ${finishVerb.toLowerCase()}!'),
            content: Text(remainingCount == 1
                ? '1 player can still play for the places.'
                : '$remainingCount players can still play for the places.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('End game'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Keep playing'),
              ),
            ],
          ),
  );
  return result ?? true;
}

class _DossedartContinuePrompt extends StatelessWidget {
  const _DossedartContinuePrompt({
    required this.finisherName,
    required this.remainingCount,
    required this.finishVerb,
  });

  final String finisherName;
  final int remainingCount;
  final String finishVerb;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 560,
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
        decoration: BoxDecoration(
          color: DossedartTokens.bg,
          border: Border.all(color: DossedartTokens.lime, width: 3),
          boxShadow: [
            BoxShadow(
              color: DossedartTokens.lime.withValues(alpha: 0.4),
              blurRadius: 32,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '★ ${finisherName.toUpperCase()} $finishVerb ★',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 14,
                color: DossedartTokens.lime,
                letterSpacing: 2,
                height: 1.4,
                shadows: [Shadow(color: DossedartTokens.lime, blurRadius: 12)],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              remainingCount == 1
                  ? '1 PLAYER CAN STILL PLAY FOR THE PLACES'
                  : '$remainingCount PLAYERS CAN STILL PLAY FOR THE PLACES',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'VT323',
                fontSize: 20,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _PromptButton(
                    label: 'KEEP PLAYING',
                    color: DossedartTokens.lime,
                    primary: true,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _PromptButton(
                    label: 'END GAME',
                    color: DossedartTokens.magenta,
                    primary: false,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Same visual grammar as the post-game action bar's buttons: primary is
/// filled with a glow, secondary is a 2px outline.
class _PromptButton extends StatelessWidget {
  const _PromptButton({
    required this.label,
    required this.color,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: primary ? color : Colors.transparent,
          border: Border.all(color: primary ? Colors.white : color, width: 2),
          boxShadow: primary
              ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 18)]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 11,
              color: primary ? DossedartTokens.bg : color,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}
```

Note: check `DossedartTokens` for the exact token names (`lime`, `magenta`, `bg` are used by `dossedart_post_game_actions.dart` and `dossedart_wildcard_dialogs.dart`; reuse the same).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/continue_prompt_dialog_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```powershell
git add lib/widgets/continue_prompt_dialog.dart test/widgets/continue_prompt_dialog_test.dart
git commit -m @'
feat(post-game): keep-playing/end prompt dialog for mid-game finishers

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
'@
```

---

### Task 2: Remove provisional mode — PostGameScreen becomes always final, CONTINUE → PLAY AGAIN

**Files:**
- Modify: `lib/models/game_result.dart` (remove `canContinue`)
- Modify: `lib/widgets/dossedart/post_game/dossedart_post_game_actions.dart`
- Modify: `lib/screens/post_game_screen.dart`
- Modify: `lib/screens/game_screen.dart` (delete `canContinue:` args at ~line 1372 and 1545-1547)
- Modify: `lib/screens/cricket_game_screen.dart` (delete `canContinue:` arg at ~line 656-657)
- Modify: `lib/screens/around_the_clock_game_screen.dart` (delete `canContinue:` arg at ~line 1106-1107)
- Test: `test/screens/post_game_dossedart_test.dart`, `test/widgets/post_game_widgets_test.dart`

**Interfaces:**
- Produces: `DossedartPostGameActions({required bool canUndo, required bool canPlayAgain, required bool canShowDetails, required VoidCallback onBack, required VoidCallback onPlayAgain, required VoidCallback onDetails, required VoidCallback onFinish})`. PLAY AGAIN button label is `'↻ PLAY AGAIN'`; PostGameScreen pops `'again'` when tapped. Tasks 9–11 consume the `'again'` pop result.
- The `'again'` action is safe before Tasks 9–11: every game screen's existing else-branch treats unknown pop results like `'home'` (records stats, goes home).

- [ ] **Step 1: Update the two test files first (failing tests)**

In `test/screens/post_game_dossedart_test.dart`:
- Delete the whole `group('provisional screen (canContinue — the game is still running)', ...)` (starts ~line 171) and remove `canContinue:` from any remaining `GameResult(...)` constructions in the file.
- Add:

```dart
  testWidgets('PLAY AGAIN pops the screen with the again action',
      (tester) async {
    String? popped;
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            popped = await Navigator.of(context).push<String>(
              MaterialPageRoute(
                builder: (_) => PostGameScreen(
                  result: GameResult(
                    gameMode: 'x01',
                    results: [
                      PlayerResult(name: 'Jonas', placement: 1, stats: const {
                        'avgTurn': 62.4,
                        'highestTurn': 140,
                        'darts': 24,
                      }),
                    ],
                  ),
                ),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('↻ PLAY AGAIN'));
    await tester.pumpAndSettle();
    expect(popped, 'again');
  });
```

In `test/widgets/post_game_widgets_test.dart`: rename `canContinue` → `canPlayAgain`, `onContinue` → `onPlayAgain`, `'▶ CONTINUE'` → `'↻ PLAY AGAIN'` in the DossedartPostGameActions tests (~lines 129-153); keep the dimmed/disabled assertions structurally identical.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/post_game_dossedart_test.dart test/widgets/post_game_widgets_test.dart`
Expected: FAIL (compile errors on renamed parameters / removed field).

- [ ] **Step 3: Implement**

1. `lib/models/game_result.dart`: delete the `canContinue` field, its constructor parameter, and default.
2. `dossedart_post_game_actions.dart`: rename `canContinue`→`canPlayAgain`, `onContinue`→`onPlayAgain`; button label `'▶ CONTINUE'` → `'↻ PLAY AGAIN'` (same slot, same `DossedartTokens.cyan`, same flex 125). Update the class doc comment: the bar now reads BACK / PLAY AGAIN / DETAILS + FINISH GAME.
3. `lib/screens/post_game_screen.dart`:
   - Delete `final provisional = result.canContinue;` and the explanatory comment block above it (~lines 146-155).
   - `DossedartWinnerSpotlight(... showStats: true)` (was `!provisional`).
   - Section label: always `PostGameSectionLabel('FINAL STANDINGS', note: '· ${result.results.length} players')`.
   - `DossedartPlacementCard(... showStats: true)`.
   - Drop the `if (!provisional)` guards around the golf scorecard, progression chart, and match summary (keep the null/`showDetails` guards).
   - Bottom bar: `canPlayAgain: true, onPlayAgain: () => Navigator.of(context).pop('again')`. In the defensive empty-results branch (~line 124-132): `canPlayAgain: false, onPlayAgain: () {}`.
4. Remove the `canContinue:` argument (and its computation where now unused, e.g. the `activePlayers`/`active`/`remainingActive` locals if they have no other use) from:
   - `game_screen.dart` `_buildGameResult()` (~1545) and `_showEarlyTerminationPostGame()`'s inline `GameResult` (~1372),
   - `cricket_game_screen.dart` `_buildGameResult()` (~656),
   - `around_the_clock_game_screen.dart` `_buildGameResult()` (~1106).

Do NOT remove the game screens' `'continue'` pop-result branches yet — they are dead but compiling; Tasks 3–5 remove them.

- [ ] **Step 4: Run tests**

Run: `flutter test test/screens/post_game_dossedart_test.dart test/widgets/post_game_widgets_test.dart test/screens/game_detail_screen_test.dart`
Expected: PASS. Also run `flutter analyze` — no errors (unused-local warnings must be fixed by deleting the locals).

- [ ] **Step 5: Commit**

```powershell
git add -A
git commit -m @'
feat(post-game): result screen is always final - PLAY AGAIN replaces CONTINUE

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
'@
```

---

### Task 3: X01 — continue prompt at all four mid-game trigger sites

**Files:**
- Modify: `lib/screens/game_screen.dart`
- Test: `test/screens/x01_continue_prompt_test.dart` (new)

**Interfaces:**
- Consumes: `showContinuePrompt` (Task 1).
- Produces: private `_promptContinueOrEnd({required String finisherName, required bool earlyTermination})` and `_resumeAfterFinisher()` in `_GameScreenState`.

- [ ] **Step 1: Write the failing test**

Model on `test/screens/postgame_record_once_test.dart` (mock prefs, disable VideoService, bounded pumps). Three players so a finisher leaves two active.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/services/video_service.dart';

/// The keep-playing/end choice moved OUT of the result screen (2026-08-14):
/// a mid-game finisher raises a dialog on the game screen; the result screen
/// only ever appears once the game is final.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoService.instance.setEnabled(false);
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<dynamic> pumpThreePlayerGame(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        players: [
          Player(name: 'A', score: 501),
          Player(name: 'B', score: 501),
          Player(name: 'C', score: 501),
        ],
        startingScore: 501,
        masterOut: 'double',
      ),
    ));
    await tester.pumpAndSettle();
    return tester.state<State<GameScreen>>(find.byType(GameScreen));
  }

  // A checks out; B and C each throw three darts so the round resolves.
  Future<void> finishPlayerA(WidgetTester tester, dynamic s) async {
    s.injectScoreForTest(0, 40);
    await s.onDartHitForTest(20, 2); // A: D20 checkout
    for (var p = 0; p < 2; p++) {
      for (var d = 0; d < 3; d++) {
        await s.onDartHitForTest(1, 1);
      }
    }
    await settle(tester);
  }

  testWidgets('mid-game finisher raises the prompt, not the result screen',
      (tester) async {
    final s = await pumpThreePlayerGame(tester);
    await finishPlayerA(tester, s);

    expect(find.text('A checked out!'), findsOneWidget);
    expect(find.text('✓ FINISH GAME'), findsNothing);
  });

  testWidgets('Keep playing resumes the round for the remaining players',
      (tester) async {
    final s = await pumpThreePlayerGame(tester);
    await finishPlayerA(tester, s);

    await tester.tap(find.text('Keep playing'));
    await settle(tester);

    expect(find.text('✓ FINISH GAME'), findsNothing);
    expect(s.finishedPlayersForTest, [0]);
    // B (seat 1) is first active and on turn.
    expect(s.currentPlayerIndexForTest, 1);
  });

  testWidgets('End game shows the final result screen', (tester) async {
    final s = await pumpThreePlayerGame(tester);
    await finishPlayerA(tester, s);

    await tester.tap(find.text('End game'));
    await settle(tester);
    await settle(tester);

    expect(find.text('✓ FINISH GAME'), findsOneWidget);
    expect(find.text('FINAL STANDINGS'), findsOneWidget);
    expect(find.text('↻ PLAY AGAIN'), findsOneWidget);
  });

  testWidgets('the LAST finisher goes straight to the final result screen',
      (tester) async {
    final s = await pumpThreePlayerGame(tester);
    await finishPlayerA(tester, s);
    await tester.tap(find.text('Keep playing'));
    await settle(tester);

    // B checks out; C throws three darts; round resolves with one active left.
    s.injectScoreForTest(1, 40);
    await s.onDartHitForTest(20, 2);
    for (var d = 0; d < 3; d++) {
      await s.onDartHitForTest(1, 1);
    }
    await settle(tester);
    await settle(tester);

    expect(find.text('Keep playing'), findsNothing);
    expect(find.text('✓ FINISH GAME'), findsOneWidget);
  });
}
```

Note: the screen is pumped WITHOUT `useDossedartDesign`, so `showContinuePrompt` renders the classic AlertDialog — that is why the finders above use the classic copy (`'A checked out!'`, `'Keep playing'`, `'End game'`).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/x01_continue_prompt_test.dart`
Expected: FAIL — the result screen still appears mid-game (finds `✓ FINISH GAME`).

- [ ] **Step 3: Implement in `game_screen.dart`**

1. Import `../widgets/continue_prompt_dialog.dart`.
2. Extract the `'continue'` branch body of `_showPostGame()` (~lines 1569-1586: reset `winnerIndex`, `dartsInTurn`, `_turnIdCounter++`, pick first non-finished player, announcements, scroll) into:

```dart
  /// Resume play after a mid-round finisher when the players chose to keep
  /// playing: start the next round from the first active seat.
  void _resumeAfterFinisher() {
    setState(() {
      winnerIndex = null;
      dartsInTurn = 0;
      _turnIdCounter++;
      for (int i = 0; i < players.length; i++) {
        if (!finishedPlayers.contains(i)) {
          currentPlayerIndex = i;
          break;
        }
      }
      scoreAtStartOfTurn = players[currentPlayerIndex].score;
    });
    _log.logPostGame(action: 'continue', details: 'startPlayer=P$currentPlayerIndex(${players[currentPlayerIndex].name}) score=${players[currentPlayerIndex].score}');
    _announcer.announceNextPlayer(players[currentPlayerIndex].name);
    _announcer.announceScore('${players[currentPlayerIndex].score} remaining');
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentPlayer());
  }
```

3. Add the prompt method:

```dart
  /// Game-screen dialog shown when a player finishes while ≥2 active players
  /// remain. KEEP PLAYING resumes; END GAME finalizes and shows the (always
  /// final) result screen. [earlyTermination] = the no-bust "nobody can beat
  /// the leader" flow, where play is mid-round and the no-bust ranking screen
  /// is the end screen.
  Future<void> _promptContinueOrEnd({
    required String finisherName,
    required bool earlyTermination,
  }) async {
    final remaining = List.generate(players.length, (i) => i)
        .where((i) => !finishedPlayers.contains(i))
        .length;
    final keepPlaying = await showContinuePrompt(
      context,
      finisherName: finisherName,
      remainingCount: remaining,
      dossedart: widget.useDossedartDesign,
      finishVerb: 'CHECKED OUT',
    );
    if (!mounted) return;
    if (keepPlaying) {
      // Early termination fires mid-round — play just carries on.
      if (!earlyTermination) _resumeAfterFinisher();
      return;
    }
    _log.logGameEnd(
        playerNames: players.map((p) => p.name).toList(),
        finishedOrder: finishedPlayers,
        gameFullyOver: true);
    BatterySampler.instance.stop();
    setState(() => _gameFullyOver = true);
    await _prepareRatingPreview();
    if (!mounted) return;
    if (earlyTermination) {
      await _showEarlyTerminationPostGame();
    } else {
      _showPostGame();
    }
  }
```

4. Replace the four mid-game trigger sites:
   - No-bust branch (~line 929-931): `else { _showPostGame(); }` → `else { _promptContinueOrEnd(finisherName: players[newFinishersThisRound.last].name, earlyTermination: false); }`
   - `_resolveRound` (~line 1024-1026): `else { _showPostGame(); }` → `else { _promptContinueOrEnd(finisherName: players[finishedPlayers.last].name, earlyTermination: false); }`
   - `_resolveSuddenDeath` (~line 1125-1127): same replacement as `_resolveRound`.
   - Early-termination call site (~line 473-479): `await _showEarlyTerminationPostGame();` → `await _promptContinueOrEnd(finisherName: players[_finishes.last.playerIndex].name, earlyTermination: true);` (verify the `_finishes` entry type exposes `playerIndex`; it does in `_noBustRankIndices`).
5. Clean up the now-dead `'continue'` branches:
   - In `_showPostGame()`: delete the whole `else if (result == 'continue') {...}` — its body now lives in `_resumeAfterFinisher`.
   - In `_showEarlyTerminationPostGame()`: delete `if (action == 'continue') { return; }`.
   - `_showEarlyTerminationPostGame` no longer needs to handle a non-final game: its leave branch's `_gameFullyOver = true` line stays harmlessly.

- [ ] **Step 4: Run tests**

Run: `flutter test test/screens/x01_continue_prompt_test.dart test/screens/postgame_record_once_test.dart test/screens/x01_sudden_death_stats_test.dart test/screens/midgame_roster_rules_test.dart`
Expected: PASS. (`postgame_record_once_test` uses a 2-player game — first checkout is the last finisher, so no dialog interferes.)

- [ ] **Step 5: Commit**

```powershell
git add -A
git commit -m @'
feat(x01): ask keep-playing/end on the game screen, result screen only when final

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
'@
```

---

### Task 4: Cricket — continue prompt

**Files:**
- Modify: `lib/screens/cricket_game_screen.dart`
- Test: `test/screens/cricket_continue_prompt_test.dart` (new)

**Interfaces:**
- Consumes: `showContinuePrompt` (Task 1).

- [ ] **Step 1: Write the failing test**

Cricket's dart hook is `registerHitForTest(int segment, int multiplier)` (`cricket_game_screen.dart:409-411`); misses are `(0, 0)`. Player A closes 15-20 with triples plus bull with three singles (0 points scored anywhere → closing everything finishes A).

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/cricket_game_screen.dart';
import 'package:dart_scoring/services/video_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoService.instance.setEnabled(false);
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<dynamic> pumpGame(WidgetTester tester, {int playerCount = 3}) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: CricketGameScreen(
        players: [
          for (var i = 0; i < playerCount; i++)
            Player(name: String.fromCharCode(65 + i), score: 0),
        ],
        config: CricketConfig(
          isRandom: false,
          targetCount: 7,
          includeBull: true,
          isCutthroat: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return tester.state<State<CricketGameScreen>>(
        find.byType(CricketGameScreen));
  }

  // A closes everything over three of A's turns; every other player throws
  // three misses in between so the rotation keeps moving.
  Future<void> finishPlayerA(WidgetTester tester, dynamic s,
      {required int others}) async {
    Future<void> othersMiss() async {
      for (var p = 0; p < others; p++) {
        for (var d = 0; d < 3; d++) {
          await s.registerHitForTest(0, 0);
        }
      }
    }

    await s.registerHitForTest(15, 3);
    await s.registerHitForTest(16, 3);
    await s.registerHitForTest(17, 3);
    await othersMiss();
    await s.registerHitForTest(18, 3);
    await s.registerHitForTest(19, 3);
    await s.registerHitForTest(20, 3);
    await othersMiss();
    await s.registerHitForTest(25, 1);
    await s.registerHitForTest(25, 1);
    await s.registerHitForTest(25, 1);
    await settle(tester);
  }

  testWidgets('finisher with two active left raises the prompt, not the result',
      (tester) async {
    final s = await pumpGame(tester);
    await finishPlayerA(tester, s, others: 2);

    expect(find.text('A finished!'), findsOneWidget);
    expect(find.text('✓ FINISH GAME'), findsNothing);
  });

  testWidgets('Keep playing advances the turn off the finisher seat',
      (tester) async {
    final s = await pumpGame(tester);
    await finishPlayerA(tester, s, others: 2);

    await tester.tap(find.text('Keep playing'));
    await settle(tester);

    expect(find.text('✓ FINISH GAME'), findsNothing);
    expect(s.finishedPlayersForTest, [0]);
    expect(s.currentPlayerIndexForTest, isNot(0));
  });

  testWidgets('End game shows the final result screen', (tester) async {
    final s = await pumpGame(tester);
    await finishPlayerA(tester, s, others: 2);

    await tester.tap(find.text('End game'));
    await settle(tester);
    await settle(tester);

    expect(find.text('✓ FINISH GAME'), findsOneWidget);
    expect(find.text('FINAL STANDINGS'), findsOneWidget);
  });

  testWidgets('two players: the first finisher ends the game with no prompt',
      (tester) async {
    final s = await pumpGame(tester, playerCount: 2);
    await finishPlayerA(tester, s, others: 1);
    await settle(tester);

    expect(find.text('A finished!'), findsNothing);
    expect(find.text('✓ FINISH GAME'), findsOneWidget);
  });
}
```

If A's marks alone don't finish (points rule), have A add one scoring surplus hit (e.g. a fourth `(20, 3)`) before the bull turn. Verify with `s.finishedPlayersForTest`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/cricket_continue_prompt_test.dart`
Expected: FAIL — result screen appears instead of the dialog.

- [ ] **Step 3: Implement in `cricket_game_screen.dart`**

1. Import `../widgets/continue_prompt_dialog.dart`.
2. Replace the mid-game trigger (~lines 322-327):

```dart
    } else if (finishedPlayers.contains(currentPlayerIndex) && !_gameFullyOver) {
      final active = List.generate(players.length, (i) => i)
          .where((i) => !finishedPlayers.contains(i))
          .length;
      if (active > 1) {
        _promptContinueOrEnd();
      } else {
        // One (or zero) active left — the game is decided; skip the question.
        _gameFullyOver = true;
        _showPostGame();
      }
    }
```

(The old `players.length <= 2` special case is subsumed: with 2 players the first finisher always leaves ≤1 active.)

3. Add:

```dart
  /// The finisher's seat is still current when this fires (the engine leaves
  /// the finisher current so the screen can show them).
  Future<void> _promptContinueOrEnd() async {
    final finisherName = players[currentPlayerIndex].name;
    final remaining = List.generate(players.length, (i) => i)
        .where((i) => !finishedPlayers.contains(i))
        .length;
    final keepPlaying = await showContinuePrompt(
      context,
      finisherName: finisherName,
      remainingCount: remaining,
      dossedart: widget.useDossedartDesign,
    );
    if (!mounted) return;
    if (keepPlaying) {
      _log.logPostGame(action: 'continue', details: 'game continues with remaining players');
      setState(_advanceToNextActivePlayer);
      return;
    }
    setState(() => _gameFullyOver = true);
    _showPostGame(); // does the rating preview itself when fully over
  }
```

4. In `_showPostGame()` delete the dead `else if (result == 'continue') {...}` branch (~lines 687-691). Update `_advanceToNextActivePlayer`'s doc comment ("post-game continue flow" → "continue-prompt flow").

- [ ] **Step 4: Run tests**

Run: `flutter test test/screens/cricket_continue_prompt_test.dart` plus every existing cricket test file (`Get-ChildItem test -Recurse -Filter *cricket*`).
Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add -A
git commit -m @'
feat(cricket): keep-playing/end prompt replaces the provisional result screen

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
'@
```

---

### Task 5: Around the Clock — continue prompt

**Files:**
- Modify: `lib/screens/around_the_clock_game_screen.dart`
- Test: `test/screens/atc_continue_prompt_test.dart` (new)

**Interfaces:**
- Consumes: `showContinuePrompt` (Task 1).

- [ ] **Step 1: Write the failing test**

ATC's dart hook is `onDartHitForTest(int segment, int multiplier)` (`around_the_clock_game_screen.dart:167-169`); the current target per seat is readable via `currentTargetsForTest`. Same harness as Task 4 (mock prefs, VideoService off, `settle`, 1200×2000).

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/around_the_clock_game_screen.dart';
import 'package:dart_scoring/services/video_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoService.instance.setEnabled(false);
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<dynamic> pumpGame(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: AroundTheClockGameScreen(
        players: [
          Player(name: 'A', score: 0),
          Player(name: 'B', score: 0),
          Player(name: 'C', score: 0),
        ],
        config: AroundTheClockConfig(
          includeBull: false,
          countMultiples: true,
          reverse: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return tester.state<State<AroundTheClockGameScreen>>(
        find.byType(AroundTheClockGameScreen));
  }

  // Seat A always hits its CURRENT target with a triple (3 steps with
  // countMultiples); B and C miss. Loop until A appears in finishedPlayers —
  // reading currentTargetsForTest keeps the sequence correct regardless of
  // exactly how the engine steps past 20.
  Future<void> finishPlayerA(WidgetTester tester, dynamic s) async {
    for (var round = 0; round < 10; round++) {
      for (var d = 0; d < 3; d++) {
        if ((s.finishedPlayersForTest as List).contains(0)) break;
        final target = (s.currentTargetsForTest as List)[0] as int;
        await s.onDartHitForTest(target, target <= 20 ? 3 : 1);
      }
      if ((s.finishedPlayersForTest as List).contains(0)) break;
      for (var p = 0; p < 2; p++) {
        for (var d = 0; d < 3; d++) {
          await s.onDartHitForTest(0, 0);
        }
      }
    }
    await settle(tester);
    expect(s.finishedPlayersForTest, contains(0));
  }

  testWidgets('finisher with two active left raises the prompt, not the result',
      (tester) async {
    final s = await pumpGame(tester);
    await finishPlayerA(tester, s);

    expect(find.text('A finished!'), findsOneWidget);
    expect(find.text('✓ FINISH GAME'), findsNothing);
  });

  testWidgets('Keep playing resumes with the next active player',
      (tester) async {
    final s = await pumpGame(tester);
    await finishPlayerA(tester, s);

    await tester.tap(find.text('Keep playing'));
    await settle(tester);

    expect(find.text('✓ FINISH GAME'), findsNothing);
    expect(s.currentPlayerIndexForTest, isNot(0));
  });

  testWidgets('End game shows the final result screen', (tester) async {
    final s = await pumpGame(tester);
    await finishPlayerA(tester, s);

    await tester.tap(find.text('End game'));
    await settle(tester);
    await settle(tester);

    expect(find.text('✓ FINISH GAME'), findsOneWidget);
    expect(find.text('FINAL STANDINGS'), findsOneWidget);
  });
}
```

Timing note: ATC resolves finishes at round end (like X01) — if the prompt does not appear right after A's finishing dart, the miss turns for B and C inside `finishPlayerA` complete the round and the prompt appears after `settle`. If a `finishPlayerA` loop iteration throws because a dialog is already up, break out of the loop when `find.text('A finished!')` matches.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/atc_continue_prompt_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement in `around_the_clock_game_screen.dart`**

1. Import `../widgets/continue_prompt_dialog.dart`.
2. Add:

```dart
  Future<void> _promptContinueOrEnd() async {
    final finisherName = players[finishedPlayers.last].name;
    final remaining = List.generate(players.length, (i) => i)
        .where((i) =>
            !finishedPlayers.contains(i) && !_removedPlayerIndices.contains(i))
        .length;
    final keepPlaying = await showContinuePrompt(
      context,
      finisherName: finisherName,
      remainingCount: remaining,
      dossedart: widget.useDossedartDesign,
    );
    if (!mounted) return;
    if (keepPlaying) {
      _log.logPostGame(action: 'continue', details: 'remaining players: ${players.length - finishedPlayers.length}');
      setState(() {
        winnerIndex = null;
        _advancePlayer();
      });
      return;
    }
    setState(() => _gameFullyOver = true);
    await _prepareRatingPreview();
    if (!mounted) return;
    _showPostGame();
  }
```

3. Replace both mid-game trigger sites:
   - Round resolve (~lines 590-592): `else { _showPostGame(); }` → `else { _promptContinueOrEnd(); }`
   - Sudden-death resolve (~lines 677-680): keep the `announceWinner` line, then `_promptContinueOrEnd();` instead of `_showPostGame();`
4. In `_showPostGame()` delete the dead `else if (result == 'continue') {...}` branch (~lines 1131-1137).

- [ ] **Step 4: Run tests**

Run: `flutter test test/screens/atc_continue_prompt_test.dart` plus existing ATC tests (`Get-ChildItem test -Recurse | Select-String -List "around_the_clock|AroundTheClock" | % Path`).
Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add -A
git commit -m @'
feat(atc): keep-playing/end prompt replaces the provisional result screen

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
'@
```

---

### Task 6: `SetupPrefill` model + `rematchPlayerIds` + scaffold `initialSelectedIds`

**Files:**
- Create: `lib/models/setup_prefill.dart`
- Modify: `lib/widgets/dossedart/setup/dossedart_setup_scaffold.dart`
- Test: `test/models/setup_prefill_test.dart` (new), `test/widgets/dossedart_setup_scaffold_prefill_test.dart` (new)

**Interfaces:**
- Produces:
  - `class SetupPrefill { const SetupPrefill({required this.playerIds, this.masterOut, this.handicap, this.noBust, this.config}); final List<String> playerIds; final String? masterOut; final bool? handicap; final bool? noBust; final GameConfig? config; }`
  - `List<String> rematchPlayerIds(List<Player> players, bool Function(int seat) isRemoved)` — saved ids for the end-of-game roster in seat order; removed seats and guests (null id) skipped.
  - `DossedartSetupScaffold` gains `final List<String>? initialSelectedIds;` — preselects those saved players (order preserved, archived/unknown ids dropped).

- [ ] **Step 1: Write the failing tests**

`test/models/setup_prefill_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/setup_prefill.dart';

void main() {
  test('rematchPlayerIds keeps seat order, drops removed seats and guests', () {
    final players = [
      Player(name: 'A', score: 0, savedPlayerId: 'a'),
      Player(name: 'Guest', score: 0), // no saved id
      Player(name: 'B', score: 0, savedPlayerId: 'b'),
      Player(name: 'C', score: 0, savedPlayerId: 'c'),
    ];
    final ids = rematchPlayerIds(players, (i) => i == 3); // C removed mid-game
    expect(ids, ['a', 'b']);
  });
}
```

`test/widgets/dossedart_setup_scaffold_prefill_test.dart` (pump pattern: mirror `test/widgets/dossedart_setup_scaffold_test.dart` — mock SharedPreferences, seed `PlayerStorage.savePlayers`, pump a `DossedartSetupScaffold` with trivial `rulesSection`/`summaryBuilder`/`onStart`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/player_storage.dart';
import 'package:dart_scoring/widgets/dossedart/setup/dossedart_setup_scaffold.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('initialSelectedIds preselects existing, skips unknown/archived',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await PlayerStorage.savePlayers([
      SavedPlayer(id: 'a', name: 'Anna', createdAt: DateTime(2026)),
      SavedPlayer(id: 'b', name: 'Bo', createdAt: DateTime(2026)),
      SavedPlayer(
          id: 'x', name: 'Xena', createdAt: DateTime(2026), archived: true),
    ]);

    var started = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: DossedartSetupScaffold(
        title: 'TEST',
        minPlayers: 1,
        initialSelectedIds: const ['b', 'a', 'x', 'gone'],
        rulesSection: (r, cb) => const SizedBox.shrink(),
        summaryBuilder: (n) => '$n',
        onStart: (players, _) =>
            started = players.map((p) => p.savedPlayerId!).toList(),
      ),
    ));
    await tester.pumpAndSettle();

    // Start immediately: the selection came exclusively from the prefill,
    // in prefill order, with archived/unknown ids dropped.
    await tester.tap(find.textContaining('START'));
    await tester.pumpAndSettle();
    expect(started, ['b', 'a']);
  });
}
```

Check `SavedPlayer`'s constructor for the `archived` parameter name, and the scaffold's START button text (`find.textContaining('START')` — adjust to the actual label if needed; if random order is ON by default, turn it off in the test via the scaffold's toggle or assert with `unorderedEquals(['a','b'])` and selection-chip presence instead of start-order).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/models/setup_prefill_test.dart test/widgets/dossedart_setup_scaffold_prefill_test.dart`
Expected: FAIL — file/param missing.

- [ ] **Step 3: Implement**

`lib/models/setup_prefill.dart`:

```dart
import 'game_config.dart';
import 'player.dart';

/// Prefill payload for the rematch flow ("PLAY AGAIN" on the result screen):
/// the previous game's rules + end-of-game roster, handed to a setup screen.
class SetupPrefill {
  const SetupPrefill({
    required this.playerIds,
    this.masterOut,
    this.handicap,
    this.noBust,
    this.config,
  });

  /// SavedPlayer ids in seat order at game end — mid-game joiners included,
  /// removed players excluded.
  final List<String> playerIds;

  // X01 options (X01 has no GameConfig subclass — it uses discrete params).
  final String? masterOut;
  final bool? handicap;
  final bool? noBust;

  /// The previous game's config for every other mode.
  final GameConfig? config;
}

/// Saved-player ids for the end-of-game roster, in seat order. [isRemoved] is
/// the calling screen's own removed-marker — the same check its
/// `_buildGameResult` uses. Guests (no saved id) are skipped.
List<String> rematchPlayerIds(
    List<Player> players, bool Function(int seat) isRemoved) {
  return [
    for (int i = 0; i < players.length; i++)
      if (!isRemoved(i) && players[i].savedPlayerId != null)
        players[i].savedPlayerId!,
  ];
}
```

`dossedart_setup_scaffold.dart`: add `this.initialSelectedIds` to the constructor + `final List<String>? initialSelectedIds;`, and seed in `_load()` after players are fetched:

```dart
    setState(() {
      _savedPlayers = players;
      _isLoading = false;
      final initial = widget.initialSelectedIds;
      if (initial != null && _selectedIds.isEmpty) {
        final selectable =
            players.where((p) => !p.archived).map((p) => p.id).toSet();
        _selectedIds.addAll(initial.where(selectable.contains));
      }
    });
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/models/setup_prefill_test.dart test/widgets/dossedart_setup_scaffold_prefill_test.dart test/widgets/dossedart_setup_scaffold_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add -A
git commit -m @'
feat(setup): SetupPrefill model and preselected roster in the DOSSEDART scaffold

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
'@
```

---

### Task 7: Prefill parameters on all 10 DOSSEDART setup screens

**Files:**
- Modify: all of `lib/screens/dossedart/dossedart_{x01,cricket,atc,killer,splitscore,shanghai,gotcha,wildcard,one_up,golf}_setup_screen.dart`
- Test: `test/screens/dossedart_setup_prefill_test.dart` (new)

**Interfaces:**
- Produces (consumed by Tasks 9-11): each setup screen gains `final List<String>? initialPlayerIds;` passed straight to the scaffold's `initialSelectedIds`, plus typed initial options:
  - `DossedartX01SetupScreen({required int startingScore, String? initialOutRule, bool? initialNoBust, bool? initialHandicap, List<String>? initialPlayerIds})`
  - Every other screen: `Dossedart<Mode>SetupScreen({<Mode>Config? initialConfig, List<String>? initialPlayerIds})`

- [ ] **Step 1: Write the failing test**

One representative widget test (gotcha) + a compile-level use of X01:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/screens/dossedart/dossedart_gotcha_setup_screen.dart';
import 'package:dart_scoring/screens/dossedart/dossedart_x01_setup_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('gotcha setup seeds rules from initialConfig', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: DossedartGotchaSetupScreen(
        initialConfig: GotchaConfig(targetScore: 501, hardcore: true),
        initialPlayerIds: [],
      ),
    ));
    await tester.pumpAndSettle();
    // Summary line reflects the seeded rules.
    expect(find.textContaining('RACE TO 501'), findsOneWidget);
    expect(find.textContaining('HARDCORE'), findsWidgets);
  });

  testWidgets('x01 setup seeds discrete options', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: DossedartX01SetupScreen(
        startingScore: 301,
        initialOutRule: 'double',
        initialNoBust: true,
        initialPlayerIds: [],
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('DOUBLE OUT'), findsWidgets);
    expect(find.textContaining('NO-BUST'), findsWidgets);
  });
}
```

(If `GotchaConfig` has no const constructor, drop the `const` keywords. If the summary text is only visible after selecting players, assert on the rules chips' selected state instead — keep it to what renders without a roster.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/dossedart_setup_prefill_test.dart`
Expected: FAIL — parameters don't exist.

- [ ] **Step 3: Implement — the same mechanical change per screen**

Pattern (gotcha shown in full; apply identically to the others):

```dart
class DossedartGotchaSetupScreen extends StatefulWidget {
  const DossedartGotchaSetupScreen(
      {super.key, this.initialConfig, this.initialPlayerIds});

  /// Rematch prefill: the previous game's rules and roster (PLAY AGAIN).
  final GotchaConfig? initialConfig;
  final List<String>? initialPlayerIds;
  ...
}

class _DossedartGotchaSetupScreenState ... {
  late int _targetScore = widget.initialConfig?.targetScore ?? 301;
  late bool _hardcore = widget.initialConfig?.hardcore ?? false;

  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      ...
      initialSelectedIds: widget.initialPlayerIds,
      ...
```

Per-screen option seeding (existing state fields ← config fields; keep each screen's current defaults as the `??` fallback):

| Screen | initialConfig type | Seeded fields |
|---|---|---|
| x01 | (discrete params) | `_outRule = widget.initialOutRule ?? 'none'`, `_noBust = widget.initialNoBust ?? false`, `_handicap = widget.initialHandicap ?? false` |
| cricket | `CricketConfig` | `isRandom, targetCount, includeBull, isCutthroat` |
| atc | `AroundTheClockConfig` | `includeBull, countMultiples, reverse` |
| killer | `KillerConfig` | `throwToPick, lives, multiplyHits, shields, suicide` |
| splitscore | `HalveItConfig` | `isRandom, roundCount, includeDouble, includeTriple, includeBull` |
| shanghai | `ShanghaiConfig` | `targetEnd` |
| gotcha | `GotchaConfig` | `targetScore, hardcore` |
| wildcard | `WildcardConfig` | `rounds, startingChaos` |
| one_up | `OneUpConfig` | `lives, variant, randomOrder` |
| golf | `GolfConfig` | `holes` |

Match each screen's actual local state variable names (read the file; they follow the `_targetScore`-style shown in the gotcha/x01 files). Where a state field is initialized in `initState` instead of inline, seed it there.

- [ ] **Step 4: Run tests**

Run: `flutter test test/screens/dossedart_setup_prefill_test.dart` and `flutter analyze`
Expected: PASS, no analyzer errors.

- [ ] **Step 5: Commit**

```powershell
git add -A
git commit -m @'
feat(setup): rematch prefill parameters on all DOSSEDART setup screens

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
'@
```

---

### Task 8: Prefill on the classic `PlayerSetupScreen`

**Files:**
- Modify: `lib/screens/player_setup_screen.dart`
- Test: `test/screens/player_setup_prefill_test.dart` (new)

**Interfaces:**
- Produces: `PlayerSetupScreen({required GameMode gameMode, int? startingScore, SetupPrefill? prefill})`. Applies X01 discrete fields and the 5 classic-track configs (cricket, atc, killer, halveIt, shanghai); preselects `prefill.playerIds`; suppresses the auto-open player sheet when the prefill roster is non-empty.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_mode.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/models/setup_prefill.dart';
import 'package:dart_scoring/screens/player_setup_screen.dart';
import 'package:dart_scoring/services/player_storage.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('prefill preselects players and skips the auto-open sheet',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await PlayerStorage.savePlayers([
      SavedPlayer(id: 'a', name: 'Anna', createdAt: DateTime(2026)),
      SavedPlayer(id: 'b', name: 'Bo', createdAt: DateTime(2026)),
    ]);

    await tester.pumpWidget(const MaterialApp(
      home: PlayerSetupScreen(
        gameMode: GameMode.x01,
        startingScore: 301,
        prefill: SetupPrefill(
            playerIds: ['a', 'b'], masterOut: 'double', noBust: true),
      ),
    ));
    await tester.pumpAndSettle();

    // Both players preselected, and no bottom sheet auto-opened over them.
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Bo'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });
}
```

(If `SetupPrefill` cannot be `const` because of the list literal, drop `const` on the pumped widget.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/player_setup_prefill_test.dart`
Expected: FAIL — `prefill` parameter does not exist.

- [ ] **Step 3: Implement**

1. Add `final SetupPrefill? prefill;` to `PlayerSetupScreen` (+ constructor param, + `import '../models/setup_prefill.dart';`).
2. In `_PlayerSetupScreenState`, apply option prefill in `initState` before `_loadSavedPlayers()`:

```dart
  void _applyPrefillOptions() {
    final p = widget.prefill;
    if (p == null) return;
    _masterOut = p.masterOut ?? _masterOut;
    _handicap = p.handicap ?? _handicap;
    _noBust = p.noBust ?? _noBust;
    switch (p.config) {
      case CricketConfig c:
        _cricketIsRandom = c.isRandom;
        _cricketTargetCount = c.targetCount;
        _cricketIncludeBull = c.includeBull;
        _cricketIsCutthroat = c.isCutthroat;
      case AroundTheClockConfig c:
        _clockIncludeBull = c.includeBull;
        _clockCountMultiples = c.countMultiples;
        _clockReverse = c.reverse;
      case KillerConfig c:
        _killerThrowToPick = c.throwToPick;
        _killerLives = c.lives;
        _killerMultiplyHits = c.multiplyHits;
        _killerShields = c.shields;
        _killerSuicide = c.suicide;
      case HalveItConfig c:
        _halveItIsRandom = c.isRandom;
        _halveItRoundCount = c.roundCount;
        _halveItIncludeDouble = c.includeDouble;
        _halveItIncludeTriple = c.includeTriple;
        _halveItIncludeBull = c.includeBull;
      case ShanghaiConfig c:
        _shanghaiTargetEnd = c.targetEnd;
      default:
        break;
    }
  }
```

(Verify the config field names against `lib/models/game_config.dart` and adjust the pattern-match syntax to what the file's Dart version supports — the codebase already uses Dart 3 switch expressions.)

3. In `_loadSavedPlayers()`, seed the selection inside the existing `setState`:

```dart
      final prefillIds = widget.prefill?.playerIds ?? const [];
      for (final id in prefillIds) {
        final sp = players
            .where((s) => s.id == id && !s.archived)
            .firstOrNull;
        if (sp != null && !_selectedPlayers.any((sel) => sel.id == sp.id)) {
          _selectedPlayers.add(sp);
        }
      }
```

The existing auto-open guard (`if (mounted && _selectedPlayers.isEmpty)`) then suppresses the sheet automatically for a non-empty prefill.

- [ ] **Step 4: Run tests**

Run: `flutter test test/screens/player_setup_prefill_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add -A
git commit -m @'
feat(setup): SetupPrefill support on the classic player setup screen

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
'@
```

---

### Task 9: `'again'` handling — X01, Cricket, ATC (dual-track routing)

**Files:**
- Modify: `lib/screens/game_screen.dart`, `lib/screens/cricket_game_screen.dart`, `lib/screens/around_the_clock_game_screen.dart`
- Test: `test/screens/play_again_x01_test.dart` (new)

**Interfaces:**
- Consumes: `rematchPlayerIds`, `SetupPrefill` (Task 6), setup-screen prefill params (Tasks 7-8), pop result `'again'` (Task 2).

- [ ] **Step 1: Write the failing test**

Model directly on `test/screens/postgame_record_once_test.dart` (2 players, checkout, result screen). Then:

```dart
    // PLAY AGAIN: records exactly once and lands on the setup screen with
    // the same players preselected and the same rules.
    await tester.tap(find.text('↻ PLAY AGAIN'));
    await settle();
    await settle();

    final saved = await PlayerStorage.loadPlayers();
    expect(saved.firstWhere((p) => p.id == 'a').gamesPlayed, 1,
        reason: 'again must record exactly once, like Finish');
    expect(find.byType(PlayerSetupScreen), findsOneWidget,
        reason: 'classic-track x01 rematch goes to the classic setup');
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
```

Use `masterOut: 'double'` in the pumped GameScreen and assert the setup's out-rule state via the visible selected option (or read the state with `tester.state`). Import `package:dart_scoring/screens/player_setup_screen.dart`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/play_again_x01_test.dart`
Expected: FAIL — `'again'` currently falls through to the home path (no setup screen pushed).

- [ ] **Step 3: Implement**

**game_screen.dart** — add imports (`../models/setup_prefill.dart`, `player_setup_screen.dart`, `dossedart/dossedart_x01_setup_screen.dart`) and a route helper:

```dart
  /// PLAY AGAIN: reopen setup prefilled with this game's rules and the
  /// end-of-game roster. Stats were already recorded by the caller.
  void _pushRematchSetup() {
    final ids = rematchPlayerIds(players, _removedPlayerIndices.contains);
    final nav = Navigator.of(context);
    nav.popUntil((route) => route.isFirst);
    nav.push(MaterialPageRoute(
      builder: (_) => widget.useDossedartDesign
          ? DossedartX01SetupScreen(
              startingScore: widget.startingScore,
              initialOutRule: widget.masterOut,
              initialNoBust: widget.noBust,
              initialHandicap: widget.handicap,
              initialPlayerIds: ids,
            )
          : PlayerSetupScreen(
              gameMode: GameMode.x01,
              startingScore: widget.startingScore,
              prefill: SetupPrefill(
                playerIds: ids,
                masterOut: widget.masterOut,
                handicap: widget.handicap,
                noBust: widget.noBust,
              ),
            ) as Widget,
    ));
  }
```

In `_showPostGame()` insert BEFORE the final else-block (mirroring the leave path exactly, then routing to setup instead of stopping at home):

```dart
    } else if (result == 'again') {
      _log.logPostGame(action: 'again');
      _log.logGameEnd(playerNames: players.map((p) => p.name).toList(), finishedOrder: finishedPlayers, gameFullyOver: _gameFullyOver);
      BatterySampler.instance.stop();
      if (!_gameFullyOver) _gameFullyOver = true;
      await _updateStats();
      if (!mounted) return;
      _pushRematchSetup();
    } else {
```

Same insertion in `_showEarlyTerminationPostGame()`'s action handling (before its leave block, ~line 1395), calling the same `_pushRematchSetup()` after `await _updateStats();`.

**cricket_game_screen.dart** — imports (`../models/setup_prefill.dart`, `player_setup_screen.dart`, `dossedart/dossedart_cricket_setup_screen.dart`); in `_showPostGame()` before the final else:

```dart
    } else if (result == 'again') {
      _log.logPostGame(action: 'again');
      if (!_gameFullyOver) _gameFullyOver = true;
      await _updateStats();
      if (!mounted) return;
      final ids = rematchPlayerIds(players, _removedPlayerIndices.contains);
      final nav = Navigator.of(context);
      nav.popUntil((route) => route.isFirst);
      nav.push(MaterialPageRoute(
        builder: (_) => widget.useDossedartDesign
            ? DossedartCricketSetupScreen(
                initialConfig: widget.config, initialPlayerIds: ids)
            : PlayerSetupScreen(
                gameMode: GameMode.cricket,
                prefill: SetupPrefill(playerIds: ids, config: widget.config),
              ) as Widget,
      ));
    } else {
```

**around_the_clock_game_screen.dart** — identical shape with `DossedartAtcSetupScreen` (verify exact class name in `dossedart_atc_setup_screen.dart`), `GameMode.aroundTheClock`, and `widget.config`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/screens/play_again_x01_test.dart test/screens/postgame_record_once_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add -A
git commit -m @'
feat(rematch): PLAY AGAIN reopens prefilled setup - x01, cricket, atc

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
'@
```

---

### Task 10: `'again'` handling — Killer, Splitscore, Shanghai (dual-track routing)

**Files:**
- Modify: `lib/screens/killer_game_screen.dart`, `lib/screens/halve_it_game_screen.dart`, `lib/screens/shanghai_game_screen.dart`

**Interfaces:**
- Consumes: same as Task 9.

- [ ] **Step 1: Implement (pattern from Task 9)**

Insert the `'again'` branch in each screen's post-game action handling, before the leave/else block, mirroring that screen's own leave path exactly:

- **killer_game_screen.dart** (~line 857, `if (result == 'undo') ... else`): between them add `else if (result == 'again') { _log.logPostGame(action: 'again', details: 'rematch'); await _updateStats(); if (!mounted) return; <route>; }` with `<route>` = `rematchPlayerIds(players, _removedPlayerIndices.contains)` → `widget.useDossedartDesign ? DossedartKillerSetupScreen(initialConfig: widget.config, initialPlayerIds: ids) : PlayerSetupScreen(gameMode: GameMode.killer, prefill: SetupPrefill(playerIds: ids, config: widget.config))`, using the captured-navigator pattern (`final nav = Navigator.of(context); nav.popUntil(...); nav.push(...)`).
- **halve_it_game_screen.dart** (~line 646): same, `_updateStats()`, `GameMode.halveIt`, `DossedartSplitscoreSetupScreen` (verify class name).
- **shanghai_game_screen.dart** (~line 490, inside the `.then((action) async {...})`): add before the leave block:

```dart
      if (action == 'again') {
        await _updateStats(ranking);
        if (!mounted) return;
        final ids = rematchPlayerIds(players, engine.isSkipped);
        final nav = Navigator.of(context);
        nav.popUntil((route) => route.isFirst);
        nav.push(MaterialPageRoute(
          builder: (_) => widget.useDossedartDesign
              ? DossedartShanghaiSetupScreen(
                  initialConfig: widget.config, initialPlayerIds: ids)
              : PlayerSetupScreen(
                  gameMode: GameMode.shanghai,
                  prefill: SetupPrefill(playerIds: ids, config: widget.config),
                ) as Widget,
        ));
        return;
      }
```

For each screen verify the removed-marker (`_removedPlayerIndices.contains` vs `engine.isSkipped`) against what that screen's `_buildGameResult` filters on, and match `_updateStats`'s signature to the screen's own leave path (`ranking`, no args, etc.).

- [ ] **Step 2: Analyze and run mode tests**

Run: `flutter analyze` then `flutter test test/screens/killer_kills_undo_test.dart test/screens/halve_it_clutch_undo_test.dart test/screens/halve_it_halving_test.dart` plus any `*shanghai*` test files.
Expected: no analyzer errors, tests PASS.

- [ ] **Step 3: Commit**

```powershell
git add -A
git commit -m @'
feat(rematch): PLAY AGAIN routing - killer, splitscore, shanghai

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
'@
```

---

### Task 11: `'again'` handling — Gotcha, Wildcard, 1UP, Golf (DOSSEDART-only)

**Files:**
- Modify: `lib/screens/gotcha_game_screen.dart`, `lib/screens/wildcard_game_screen.dart`, `lib/screens/one_up_game_screen.dart`, `lib/screens/golf_game_screen.dart`
- Test: `test/screens/play_again_gotcha_test.dart` (new)

**Interfaces:**
- Consumes: same as Task 9; these four screens have no classic track — always route to their DOSSEDART setup screen.

- [ ] **Step 1: Write the failing test**

Mirror `test/screens/gotcha_postgame_undo_test.dart`'s harness (it already pumps `GotchaGameScreen` to the result screen). After reaching the result screen:

```dart
    await tester.tap(find.text('↻ PLAY AGAIN'));
    await settle(tester);
    await settle(tester);

    expect(find.byType(DossedartGotchaSetupScreen), findsOneWidget);
    final saved = await PlayerStorage.loadPlayers();
    expect(saved.firstWhere((p) => p.id == 'a').gamesPlayed, 1,
        reason: 'again records exactly once');
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/play_again_gotcha_test.dart`
Expected: FAIL — `'again'` falls through to home.

- [ ] **Step 3: Implement**

In each screen's `.then((action) async {...})` post-game handler, before the leave block:

```dart
      if (action == 'again') {
        await _updateStats(ranking); // golf: _updateStats(placements)
        if (!mounted) return;
        final ids = rematchPlayerIds(players, engine.isSkipped);
        final nav = Navigator.of(context);
        nav.popUntil((route) => route.isFirst);
        nav.push(MaterialPageRoute(
          builder: (_) => DossedartGotchaSetupScreen(
            initialConfig: widget.config,
            initialPlayerIds: ids,
          ),
        ));
        return;
      }
```

Per screen: `DossedartWildcardSetupScreen`, `DossedartOneUpSetupScreen`, `DossedartGolfSetupScreen` (verify exact class names in their files), each with `initialConfig: widget.config`. Match `_updateStats`'s argument to the screen's own leave path (`ranking` for gotcha/wildcard/one_up, `placements` for golf). Verify the removed-marker per screen (`engine.isSkipped` — same as `_buildGameResult`).

- [ ] **Step 4: Run tests**

Run: `flutter test test/screens/play_again_gotcha_test.dart test/screens/gotcha_postgame_undo_test.dart test/screens/wildcard_postgame_undo_test.dart test/screens/golf_postgame_undo_test.dart test/screens/one_up_game_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add -A
git commit -m @'
feat(rematch): PLAY AGAIN routing - gotcha, wildcard, one-up, golf

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
'@
```

---

### Task 12: Full-suite verification

- [ ] **Step 1: Analyzer**

Run: `flutter analyze`
Expected: no errors, no new warnings.

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: all tests pass (baseline before this plan: 1077). Known flake: `dossedart_setup_scaffold_test.dart` has failed in full-suite runs before while passing standalone — if it is the only failure, rerun it standalone before investigating.

- [ ] **Step 3: Fix any fallout**

Likely candidates: tests that construct `GameResult(canContinue: ...)`, tests asserting `'▶ CONTINUE'`, or X01/Cricket/ATC flow tests that previously expected the provisional result screen mid-game. Fix them to the new flow (dialog first, final-only result screen).

- [ ] **Step 4: Commit any test fixes**

```powershell
git add -A
git commit -m @'
test: align remaining tests with the final-only result screen

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
'@
```

Do NOT push — Bjørn triggers CI. Tablet smoke test (Galaxy Tab emulator) is a follow-up outside this plan.
