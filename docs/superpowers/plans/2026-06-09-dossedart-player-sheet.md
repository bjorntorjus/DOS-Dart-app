# Unified Arcade Player Sheet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the two divergent arcade "player overview" surfaces with one shared bottom-sheet (`DossedartPlayerSheet`) that shows standings + remove + add-from-saved, wired into all 6 DOSSEDART cockpits.

**Architecture:** One pure stateless widget (`DossedartPlayerSheet`) takes a list of `DossedartStandingRow` view-models plus an already-loaded `available` saved-player list; a thin `showDossedartPlayerSheet(...)` wrapper does the async `PlayerStorage` load and presents the modal. Each cockpit maps its live engine state into rows and passes its existing `_addSavedPlayerMidGame` / `_removePlayerMidGame` handlers. The legacy Material `mid_game_player_sheet.dart` stays for the still-live classic (non-arcade) scaffold.

**Tech Stack:** Flutter, Dart, `flutter_test`. Package name: `dart_scoring`. Tokens in `lib/theme/dossedart_tokens.dart`.

**Spec:** `docs/superpowers/specs/2026-06-09-dossedart-player-sheet-design.md`

**Labels:** UI text is English (matches existing `DossedartMenuSheet` + CLAUDE.md), even though the design HTML uses Norwegian (SPILLER-OVERSIKT/FJERN/LEGG TIL). Title = `PLAYER OVERVIEW`, action = `REMOVE`, section = `ADD PLAYER`.

**Color rule in the sheet:** active row = cyan, every other row = phosphor, for ALL modes (Killer's red-enemy coloring stays on the cockpit board, not this shared sheet — consistency).

---

## File Structure

- **Create** `lib/widgets/dossedart/dossedart_player_sheet.dart` — `DossedartStandingRow` model, `DossedartPlayerSheet` widget, `showDossedartPlayerSheet` wrapper.
- **Create** `test/widgets/dossedart/dossedart_player_sheet_test.dart` — widget tests for the pure sheet.
- **Modify** the 6 cockpits to build rows + open the new sheet:
  - `lib/screens/game_screen.dart` (X01)
  - `lib/screens/cricket_game_screen.dart`
  - `lib/screens/around_the_clock_game_screen.dart`
  - `lib/screens/killer_game_screen.dart`
  - `lib/screens/shanghai_game_screen.dart`
  - `lib/screens/halve_it_game_screen.dart` (Splitscore)
- **Delete** `lib/screens/dossedart/x01/dossedart_player_overview_screen.dart` + its test (if any).
- **Keep untouched** `lib/widgets/mid_game_player_sheet.dart` (classic path).

---

### Task 1: `DossedartPlayerSheet` widget + model

**Files:**
- Create: `lib/widgets/dossedart/dossedart_player_sheet.dart`
- Test: `test/widgets/dossedart/dossedart_player_sheet_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/widgets/dossedart/dossedart_player_sheet.dart';

SavedPlayer _saved(String id, String name) =>
    SavedPlayer(id: id, name: name, createdAt: DateTime(2020));

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  List<DossedartStandingRow> threeActive() => const [
        DossedartStandingRow(
            playerIndex: 0, name: 'Ada', avatarPath: null, isActive: true, isRemoved: false, primary: '251'),
        DossedartStandingRow(
            playerIndex: 1, name: 'Bo', avatarPath: null, isActive: false, isRemoved: false, primary: '300'),
        DossedartStandingRow(
            playerIndex: 2, name: 'Cy', avatarPath: null, isActive: false, isRemoved: false, primary: '180'),
      ];

  testWidgets('renders title, each row name + primary', (tester) async {
    await tester.pumpWidget(_host(DossedartPlayerSheet(
      rows: threeActive(), gameOver: false, available: const [],
      onAdd: (_) {}, onRemove: (_) {},
    )));
    expect(find.text('PLAYER OVERVIEW'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('251'), findsOneWidget);
    expect(find.text('300'), findsOneWidget);
  });

  testWidgets('REMOVE fires onRemove with playerIndex when >2 active', (tester) async {
    int? removed;
    await tester.pumpWidget(_host(DossedartPlayerSheet(
      rows: threeActive(), gameOver: false, available: const [],
      onAdd: (_) {}, onRemove: (i) => removed = i,
    )));
    await tester.tap(find.text('REMOVE').first);
    expect(removed, 0);
  });

  testWidgets('REMOVE disabled when only 2 active', (tester) async {
    int? removed;
    final rows = const [
      DossedartStandingRow(
          playerIndex: 0, name: 'Ada', avatarPath: null, isActive: true, isRemoved: false, primary: '1'),
      DossedartStandingRow(
          playerIndex: 1, name: 'Bo', avatarPath: null, isActive: false, isRemoved: false, primary: '2'),
    ];
    await tester.pumpWidget(_host(DossedartPlayerSheet(
      rows: rows, gameOver: false, available: const [],
      onAdd: (_) {}, onRemove: (i) => removed = i,
    )));
    await tester.tap(find.text('REMOVE').first);
    expect(removed, isNull);
  });

  testWidgets('removed row shows REMOVED tag and no REMOVE action', (tester) async {
    final rows = const [
      DossedartStandingRow(
          playerIndex: 0, name: 'Ada', avatarPath: null, isActive: true, isRemoved: false, primary: '1'),
      DossedartStandingRow(
          playerIndex: 1, name: 'Bo', avatarPath: null, isActive: false, isRemoved: false, primary: '2'),
      DossedartStandingRow(
          playerIndex: 2, name: 'Cy', avatarPath: null, isActive: false, isRemoved: true, primary: '0'),
    ];
    await tester.pumpWidget(_host(DossedartPlayerSheet(
      rows: rows, gameOver: false, available: const [], onAdd: (_) {}, onRemove: (_) {},
    )));
    expect(find.text('REMOVED'), findsOneWidget);
    // 2 active rows -> 2 REMOVE buttons (removed row has none)
    expect(find.text('REMOVE'), findsNWidgets(2));
  });

  testWidgets('empty available shows empty-state; populated fires onAdd', (tester) async {
    SavedPlayer? added;
    await tester.pumpWidget(_host(DossedartPlayerSheet(
      rows: threeActive(), gameOver: false, available: [_saved('x', 'Zed')],
      onAdd: (sp) => added = sp, onRemove: (_) {},
    )));
    expect(find.text('Zed'), findsOneWidget);
    await tester.tap(find.text('Zed'));
    expect(added?.id, 'x');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/dossedart/dossedart_player_sheet_test.dart`
Expected: FAIL — `dossedart_player_sheet.dart` / `DossedartPlayerSheet` not found.

- [ ] **Step 3: Write the widget**

Create `lib/widgets/dossedart/dossedart_player_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import '../../models/saved_player.dart';
import '../../services/player_storage.dart';
import '../../theme/dossedart_tokens.dart';
import 'dossedart_player_avatar.dart';

/// One standing row in the unified arcade player sheet. Every cockpit maps its
/// live engine state into this shape so the sheet renders identically across modes.
class DossedartStandingRow {
  const DossedartStandingRow({
    required this.playerIndex,
    required this.name,
    required this.avatarPath,
    required this.isActive,
    required this.isRemoved,
    required this.primary,
  });

  final int playerIndex;
  final String name;
  final String? avatarPath;
  final bool isActive;
  final bool isRemoved;
  final String primary;
}

/// Unified DOSSEDART player sheet ("PLAYER OVERVIEW"; SPILLER-OVERSIKT in the
/// design): standings + remove + add-from-saved in one arcade bottom sheet,
/// shared by all 6 cockpits. The async saved-player load lives in the wrapper;
/// the widget itself is pure so it is trivially testable.
Future<void> showDossedartPlayerSheet(
  BuildContext context, {
  required List<DossedartStandingRow> rows,
  required bool gameOver,
  required Set<String> excludeSavedIds,
  required void Function(SavedPlayer saved) onAdd,
  required void Function(int index) onRemove,
  String? addInfoText,
}) async {
  final saved = await PlayerStorage.loadPlayers();
  final available = saved.where((sp) => !excludeSavedIds.contains(sp.id)).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    backgroundColor: DossedartTokens.surface,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: DossedartPlayerSheet(
        rows: rows,
        gameOver: gameOver,
        available: available,
        addInfoText: addInfoText,
        onAdd: (sp) {
          Navigator.pop(ctx);
          onAdd(sp);
        },
        onRemove: (i) {
          Navigator.pop(ctx);
          onRemove(i);
        },
      ),
    ),
  );
}

class DossedartPlayerSheet extends StatelessWidget {
  const DossedartPlayerSheet({
    super.key,
    required this.rows,
    required this.gameOver,
    required this.available,
    required this.onAdd,
    required this.onRemove,
    this.addInfoText,
  });

  final List<DossedartStandingRow> rows;
  final bool gameOver;
  final List<SavedPlayer> available;
  final void Function(SavedPlayer saved) onAdd;
  final void Function(int index) onRemove;
  final String? addInfoText;

  int get _activeCount => rows.where((r) => !r.isRemoved).length;

  @override
  Widget build(BuildContext context) {
    final canRemove = !gameOver && _activeCount > 2;
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const _SheetTitle('PLAYER OVERVIEW'),
          const SizedBox(height: 4),
          for (final row in rows)
            _StandingTile(row: row, canRemove: canRemove, onRemove: onRemove),
          Container(
            height: 1,
            margin: const EdgeInsets.fromLTRB(18, 10, 18, 6),
            color: Colors.white.withValues(alpha: 0.08),
          ),
          const _SheetTitle('ADD PLAYER'),
          if (addInfoText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 4),
              child: Text(
                addInfoText!,
                style: const TextStyle(color: DossedartTokens.phosphor, fontSize: 11),
              ),
            ),
          if (available.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 8, 18, 16),
              child: Text(
                'No more saved players available.',
                style: TextStyle(color: DossedartTokens.phosphor, fontSize: 12),
              ),
            )
          else
            for (final sp in available)
              _AddTile(player: sp, enabled: !gameOver, onTap: () => onAdd(sp)),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 12,
          color: DossedartTokens.yellow,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _StandingTile extends StatelessWidget {
  const _StandingTile({required this.row, required this.canRemove, required this.onRemove});
  final DossedartStandingRow row;
  final bool canRemove;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final accent = row.isActive ? DossedartTokens.cyan : DossedartTokens.phosphor;
    return Opacity(
      opacity: row.isRemoved ? 0.4 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(
          children: [
            DossedartPlayerAvatar(
              size: 36,
              borderColor: accent,
              avatarPath: row.avatarPath,
              borderWidth: 2,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  if (row.isRemoved)
                    const Text(
                      'REMOVED',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 8,
                        color: DossedartTokens.red,
                        letterSpacing: 1,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              row.primary,
              style: TextStyle(fontFamily: 'PressStart2P', fontSize: 13, color: accent),
            ),
            if (!row.isRemoved) ...[
              const SizedBox(width: 12),
              _RemoveButton(enabled: canRemove, onTap: () => onRemove(row.playerIndex)),
            ],
          ],
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? DossedartTokens.red : DossedartTokens.disabledFg;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(border: Border.all(color: color, width: 1)),
        child: Text(
          'REMOVE',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 8,
            color: color,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.player, required this.enabled, required this.onTap});
  final SavedPlayer player;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(
          children: [
            DossedartPlayerAvatar(
              size: 32,
              borderColor: DossedartTokens.green,
              avatarPath: player.avatarPath,
              borderWidth: 2,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
            Icon(Icons.add_circle,
                color: enabled ? DossedartTokens.green : DossedartTokens.disabledFg, size: 26),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/dossedart/dossedart_player_sheet_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/dossedart/dossedart_player_sheet.dart test/widgets/dossedart/dossedart_player_sheet_test.dart
git commit -m "feat(dossedart): unified arcade player sheet (standings + add/remove)"
```

---

### Task 2: Wire X01 (game_screen.dart)

**Files:**
- Modify: `lib/screens/game_screen.dart` (`_openPlayerOverview` body + imports)

- [ ] **Step 1: Replace the import**

Remove `import 'dossedart/x01/dossedart_player_overview_screen.dart';` (path relative to the file's existing import block) and add:
```dart
import '../widgets/dossedart/dossedart_player_sheet.dart';
```

- [ ] **Step 2: Rewrite `_openPlayerOverview()`**

Replace the entire `_openPlayerOverview()` method (currently builds `PlayerOverviewRow`s and pushes `DossedartPlayerOverviewScreen`) with:

```dart
void _openPlayerOverview() {
  final rows = <DossedartStandingRow>[];
  for (int i = 0; i < players.length; i++) {
    final p = players[i];
    rows.add(DossedartStandingRow(
      playerIndex: i,
      name: p.name,
      avatarPath: p.avatarPath,
      isActive: i == currentPlayerIndex,
      isRemoved: _removedPlayerIndices.contains(i),
      primary: '${p.score}',
    ));
  }
  showDossedartPlayerSheet(
    context,
    rows: rows,
    gameOver: _gameFullyOver,
    excludeSavedIds: players.map((p) => p.savedPlayerId).whereType<String>().toSet(),
    addInfoText: 'Rating is skipped for this game once you add or remove a player.',
    onAdd: _addSavedPlayerMidGame,
    onRemove: _removePlayerMidGame,
  );
}
```

- [ ] **Step 3: Verify analyze + run the X01 menu test**

Run: `flutter analyze --no-pub`
Expected: No issues (the `dossedart_player_overview_screen` import is gone; the file is deleted in Task 8 — until then it is simply unused, still valid).

Run: `flutter test test/widgets/dossedart/x01/dossedart_menu_sheet_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/game_screen.dart
git commit -m "feat(dossedart-x01): open unified player sheet from cockpit menu"
```

---

### Tasks 3–7: Wire the remaining 5 cockpits

Each cockpit follows the **same pattern**: add a `_openDossedartPlayerSheet()` method that builds rows from that mode's live state, and repoint the arcade `⋯ MENU`'s `onPlayerOverview` to it. **Do not touch** `_openPlayerManagement` — the classic scaffold's popup still uses it.

**Per-cockpit parameters** (verify each field name against the file before editing — confirmed values shown):

| Task | File | active flag | removed flag | gameOver flag | `primary` expression |
|---|---|---|---|---|---|
| 3 | `cricket_game_screen.dart` | `i == currentPlayerIndex` | `_removedPlayerIndices.contains(i)` | `_gameFullyOver` | `'${players[i].score}'` |
| 4 | `around_the_clock_game_screen.dart` | `i == currentPlayerIndex` | `_removedPlayerIndices.contains(i)` | verify (e.g. `_gameFullyOver` / `_isGameOver`) | `finishedPlayers.contains(i) ? 'DONE' : '${currentTargets[i]}'` |
| 5 | `killer_game_screen.dart` | `i == currentPlayerIndex` | `_removedPlayerIndices.contains(i)` | verify | `isEliminated[i] ? 'OUT' : '${lives[i]} ♥'` |
| 6 | `shanghai_game_screen.dart` | `i == engine.currentPlayerIndex` | `engine.isSkipped(i)` | verify | `'${engine.totalScores[i]}'` |
| 7 | `halve_it_game_screen.dart` (Splitscore) | `i == currentPlayerIndex` | `_removedPlayerIndices.contains(i)` | verify | `'${totalScores[i]}'` |

For names/avatars use the same player list the cockpit's scoreboard iterates (`players[i].name` / `players[i].avatarPath`; for Shanghai use whatever list it already reads names from — confirm in the file).

**Steps for EACH of Tasks 3–7:**

- [ ] **Step 1: Add the import**

Add to the file's import block:
```dart
import '../widgets/dossedart/dossedart_player_sheet.dart';
```

- [ ] **Step 2: Add `_openDossedartPlayerSheet()`** (substitute the row of the table for this mode)

```dart
void _openDossedartPlayerSheet() {
  final rows = <DossedartStandingRow>[];
  for (int i = 0; i < players.length; i++) {
    final p = players[i];
    rows.add(DossedartStandingRow(
      playerIndex: i,
      name: p.name,
      avatarPath: p.avatarPath,
      isActive: /* active flag */,
      isRemoved: /* removed flag */,
      primary: /* primary expression */,
    ));
  }
  showDossedartPlayerSheet(
    context,
    rows: rows,
    gameOver: /* gameOver flag */,
    excludeSavedIds: players.map((p) => p.savedPlayerId).whereType<String>().toSet(),
    addInfoText: 'Rating is skipped for this game once you add or remove a player.',
    onAdd: _addSavedPlayerMidGame,
    onRemove: _removePlayerMidGame,
  );
}
```

(Shanghai: if it has no `players` list with `savedPlayerId`, build `rows`/`excludeSavedIds` from the same source its `_addSavedPlayerMidGame`/scoreboard already use; mirror the existing `isRemoved: (i) => engine.isSkipped(i)` filter.)

- [ ] **Step 3: Repoint the arcade menu**

In the `showDossedartCockpitMenu(...)` call (or X01-style inline `DossedartMenuSheet`), change:
```dart
onPlayerOverview: () { if (!_gameFullyOver) _openPlayerManagement(); },
```
to:
```dart
onPlayerOverview: _openDossedartPlayerSheet,
```
(the gating is handled inside the sheet — REMOVE/ADD disable themselves when `gameOver`).

- [ ] **Step 4: Verify**

Run: `flutter analyze --no-pub` → No issues.
Run: `flutter test` → all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/<this_file>.dart
git commit -m "feat(dossedart-<mode>): open unified player sheet from cockpit menu"
```

---

### Task 8: Delete the dead X01 overview screen

**Files:**
- Delete: `lib/screens/dossedart/x01/dossedart_player_overview_screen.dart`
- Delete (if it exists): the matching test under `test/screens/dossedart/x01/` or `test/widgets/dossedart/x01/` for the overview screen.

- [ ] **Step 1: Confirm no remaining references**

Run: `grep -rn "DossedartPlayerOverviewScreen\|PlayerOverviewRow\|dossedart_player_overview_screen" lib test`
Expected: no matches (Task 2 removed the only consumer).

- [ ] **Step 2: Delete the file(s)**

```bash
git rm lib/screens/dossedart/x01/dossedart_player_overview_screen.dart
```
(plus its test file if one is found in Step 1's directory scan.)

- [ ] **Step 3: Full verification**

Run: `flutter analyze --no-pub` → No issues found.
Run: `flutter test` → All tests passed.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor(dossedart): drop dead X01 full-screen player overview"
```

---

## Self-Review

- **Spec coverage:** new shared sheet (Task 1) ✓; replaces X01 full-screen (Tasks 2, 8) ✓; all 6 cockpits wired (Tasks 2–7) ✓; Material sheet kept for classic path (no deletion task — explicit) ✓; compact primary-only rows (`DossedartStandingRow.primary`) ✓; min-2-active + gameOver gating (Task 1 `canRemove`) ✓; tests (Task 1) ✓.
- **Type consistency:** `DossedartStandingRow` fields and `showDossedartPlayerSheet` signature are identical across Tasks 1–7. `onAdd: (SavedPlayer)`, `onRemove: (int)` match every cockpit's existing `_addSavedPlayerMidGame` / `_removePlayerMidGame`.
- **Verify-before-edit notes:** Tasks 4–7 list `gameOver` flag as "verify" because only X01/Cricket were confirmed to expose `_gameFullyOver`; the executor confirms the equivalent flag (and Shanghai's name/avatar source) against each file before editing. This is intentional, not a placeholder.
