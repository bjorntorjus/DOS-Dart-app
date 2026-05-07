# Material 3 Color System Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the Dart Scoring app to Material 3 named color roles, eliminate ad hoc color usage, drop per-player colors from gameplay UI (kept on avatars only), unify the active-player highlight, and add Cricket closed-target dimming. End state: every meaningful color signal is paired with a shape/icon, and `red === error` semantically.

**Architecture:** `ColorScheme.fromSeed` in `main.dart` generates a 30-role tonal palette from a green seed. All UI chrome reads `Theme.of(context).colorScheme.<role>` instead of hex literals. A new `ActivePlayerHighlight` widget centralizes the active-player ring used across all six game modes. Avatar colors live in a new dedicated `_AvatarPalette` constant — separate from the theme.

**Tech Stack:** Flutter (Material 3), Dart. No new dependencies.

---

## Spec

This plan implements `docs/superpowers/specs/2026-04-29-material3-migration-design.md`. Re-read the spec if any task feels under-specified.

## Working invariants (apply to every task)

- Working directory: `.worktrees/m3-migration/` (the worktree on `feature/material3-migration`)
- After every task: `flutter analyze` shows no NEW errors/warnings (pre-existing info-lints OK), and `flutter test test/models/shanghai_engine_test.dart test/services/tts_service_init_test.dart` shows 25 passing
- Commit at the end of each task with `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>` in the trailer
- For any file you `Edit`, you must `Read` it first
- `cs` is shorthand used in this plan for `Theme.of(context).colorScheme`. In code use the full expression unless a local already exists.

---

## Phase 1: ColorScheme.fromSeed foundation

### Task 1.1: Switch main.dart to fromSeed

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Read the current theme block**

Read `lib/main.dart` lines 31-65 to confirm the existing `MaterialApp` setup.

- [ ] **Step 2: Replace the theme**

Replace this block:

```dart
theme: ThemeData(
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF43A047),
    secondary: Color(0xFFE53935),
    surface: Color(0xFF1E1E1E),
  ),
  scaffoldBackgroundColor: const Color(0xFF121212),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E1E1E),
    elevation: 0,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF43A047),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
),
```

with:

```dart
theme: ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF43A047),
    brightness: Brightness.dark,
    primary: const Color(0xFF43A047),
    secondary: const Color(0xFFE53935),
    error: const Color(0xFFE53935),
  ),
  appBarTheme: const AppBarTheme(elevation: 0),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
),
```

(We pin `primary`/`secondary`/`error` to the existing brand colors so the visual identity stays. M3 still derives the surface scale, tertiary, and outline from the seed. We drop `scaffoldBackgroundColor` and `AppBarTheme.backgroundColor` so they fall back on M3 surface defaults; we drop the explicit button colors so they pick up the theme.)

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze lib/main.dart`
Expected: No new errors. (May surface info-lints that already existed.)

- [ ] **Step 4: Run the app smoke-test**

Run: `flutter test test/widget_test.dart`
Expected: "App launches" test passes.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat(theme): migrate to ColorScheme.fromSeed (Material 3)

Generates a 30-role tonal palette from the brand green. Pins
primary/secondary/error to existing brand colors so visual identity
is preserved while making surfaceContainer*, outline, tertiary, etc.
available to consumers. Drops manual scaffoldBackgroundColor and
AppBarTheme.backgroundColor; M3 surface defaults take over.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 2: Migrate hex literals to color roles

This phase moves the bulk of `Color(0xFF...)` literals to `colorScheme` roles. Split into batches by file group to keep diffs reviewable.

**The mapping table** (apply consistently across every file in this phase):

| Hex literal | New code |
|-------------|----------|
| `Color(0xFF1E1E1E)` | `Theme.of(context).colorScheme.surface` |
| `Color(0xFF121212)` | `Theme.of(context).colorScheme.surfaceContainerLowest` |
| `Color(0xFF2A2A2A)` | `Theme.of(context).colorScheme.surfaceContainerLow` |
| `Color(0xFF374151)` | `Theme.of(context).colorScheme.surfaceContainer` |
| `Color(0xFF4B5563)` | `Theme.of(context).colorScheme.outline` |
| `Color(0xFFD1D5DB)` | `Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)` |
| `Color(0xFF43A047)` | `Theme.of(context).colorScheme.primary` |
| `Color(0xFFB71C1C)` | `Theme.of(context).colorScheme.error` |
| `Colors.grey[700]` / `Colors.grey.shade700` | `Theme.of(context).colorScheme.surfaceContainer` |
| `Colors.grey[800]` / `Colors.grey.shade800` | `Theme.of(context).colorScheme.surfaceContainerLow` |
| `Color(0xFFE53935)` | **leave as-is in this phase** (Phase 3 resolves) |

Where `BuildContext` is unavailable (e.g. inside `static` methods or `const` constructors), refactor to receive a `ColorScheme` or a `BuildContext` parameter. If the call site is genuinely const-required (e.g. `LinearGradient` const list), introduce a non-const variant that takes `ColorScheme cs`.

**Exempt files** (do NOT change in Phase 2):
- `lib/widgets/dart_board.dart` — physical dartboard colors
- `lib/widgets/heatmap_board.dart` — heatmap data viz (Phase 2.4 cleans this up separately)

### Task 2.1: Migrate widgets

**Files:**
- Modify: `lib/widgets/cricket_scoreboard.dart`
- Modify: `lib/widgets/halve_it_scoreboard.dart`
- Modify: `lib/widgets/checkout_widget.dart`
- Modify: `lib/widgets/clock_progress.dart`
- Modify: `lib/widgets/mid_game_player_sheet.dart`
- Modify: `lib/widgets/player_avatar.dart`

- [ ] **Step 1: For each file, find every hex literal and Colors.grey usage**

Run for each file:
```bash
grep -n "Color(0xFF\|Colors\.grey" lib/widgets/<filename>.dart
```

- [ ] **Step 2: Apply the mapping table**

For each match: read the file with `Read`, then `Edit` the literal to the matching role. If the surrounding code does not have access to `BuildContext`, take it as a parameter or refactor a `const` to a regular constructor.

Example (`cricket_scoreboard.dart` line 72):

Before:
```dart
DataRow(
  color: const WidgetStatePropertyAll(Color(0xFF2A2A2A)),
```

After:
```dart
DataRow(
  color: WidgetStatePropertyAll(Theme.of(context).colorScheme.surfaceContainerLow),
```

(Drop `const` since the value depends on context.)

- [ ] **Step 3: Repeat for every widget file**

Work through the 6 files in the file list. Do not touch dart_board.dart or heatmap_board.dart in this task.

- [ ] **Step 4: Run flutter analyze**

Run: `flutter analyze lib/widgets/`
Expected: No new errors.

- [ ] **Step 5: Run tests**

Run: `flutter test test/models/shanghai_engine_test.dart test/services/tts_service_init_test.dart`
Expected: 25 passing.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/cricket_scoreboard.dart lib/widgets/halve_it_scoreboard.dart lib/widgets/checkout_widget.dart lib/widgets/clock_progress.dart lib/widgets/mid_game_player_sheet.dart lib/widgets/player_avatar.dart
git commit -m "refactor(theme): migrate widget hex literals to colorScheme roles

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 2.2: Migrate game screens

**Files:**
- Modify: `lib/screens/game_screen.dart`
- Modify: `lib/screens/cricket_game_screen.dart`
- Modify: `lib/screens/shanghai_game_screen.dart`
- Modify: `lib/screens/around_the_clock_game_screen.dart`
- Modify: `lib/screens/killer_game_screen.dart`
- Modify: `lib/screens/halve_it_game_screen.dart`

- [ ] **Step 1: Apply the mapping table to each file**

Read each file, identify all hex literals and `Colors.grey[X]` usages, replace per the mapping table. Leave `Color(0xFFE53935)` for Phase 3.

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze lib/screens/`
Expected: No new errors.

- [ ] **Step 3: Run tests**

Run: `flutter test`
Expected: 25 passing (other test failures pre-existing).

- [ ] **Step 4: Commit**

```bash
git add lib/screens/game_screen.dart lib/screens/cricket_game_screen.dart lib/screens/shanghai_game_screen.dart lib/screens/around_the_clock_game_screen.dart lib/screens/killer_game_screen.dart lib/screens/halve_it_game_screen.dart
git commit -m "refactor(theme): migrate game-screen hex literals to colorScheme roles

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 2.3: Migrate other screens

**Files:**
- Modify: `lib/screens/home_screen.dart`
- Modify: `lib/screens/post_game_screen.dart`
- Modify: `lib/screens/stats_screen.dart`
- Modify: `lib/screens/settings_screen.dart`
- Modify: `lib/screens/player_setup_screen.dart`
- Modify: `lib/screens/meme_settings_screen.dart`

- [ ] **Step 1: Apply the mapping table to each file**

Same process as Task 2.2.

Special cases in this batch:
- `home_screen.dart` line 50: `Icon(Icons.adjust, size: 80, color: Color(0xFFE53935))` is the BRAND LOGO. **Leave for Phase 3** — keep it as-is in this task.
- `home_screen.dart` lines 147-149: `goldColor`, `silverColor`, `bronzeColor` constants. **Keep as-is** — these are intentional medal colors.
- `stats_screen.dart` line 77: `backgroundColor: const Color(0xFFE53935)` is a delete dialog button. **Leave for Phase 3.**
- `stats_screen.dart` lines 892, 894, 900: `0xFF43A047` with alpha for the game-mode label badge. Replace with `cs.primary.withValues(alpha: 0.12)` and `cs.primary.withValues(alpha: 0.32)` (badge bg / border) and `cs.primary` (text).

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze lib/screens/`
Expected: No new errors.

- [ ] **Step 3: Run tests**

Run: `flutter test`
Expected: 25 passing.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/home_screen.dart lib/screens/post_game_screen.dart lib/screens/stats_screen.dart lib/screens/settings_screen.dart lib/screens/player_setup_screen.dart lib/screens/meme_settings_screen.dart
git commit -m "refactor(theme): migrate non-game screen hex literals to colorScheme

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 2.4: Extract heatmap palette to a named const block

**Files:**
- Modify: `lib/widgets/heatmap_board.dart`

This file's red→amber→green→teal gradient is data viz. Don't migrate to roles, but DO collect the hex constants in one place.

- [ ] **Step 1: Read heatmap_board.dart**

- [ ] **Step 2: Add a private palette block at the top**

After the imports, add:

```dart
/// Heatmap gradient — DO NOT migrate to colorScheme. These are data-viz
/// colors selected to be perceptually distinct and color-blind tolerant.
class _HeatmapPalette {
  static const cold = Color(0xFF1565C0);    // blue
  static const cool = Color(0xFF00ACC1);    // teal
  static const mid = Color(0xFF4CAF50);     // green
  static const warm = Color(0xFFFFB300);    // amber
  static const hot = Color(0xFFE53935);     // red
  static const empty = Color(0xFF1A1A1A);   // empty cell
  static const board = Color(0xFF2C2C2C);   // board background
  static const wireframe = Color(0xFFA0A0A0); // grid lines
}
```

- [ ] **Step 3: Replace inline hex with palette references**

Substitute every existing `const Color(0xFF...)` in the file with the matching `_HeatmapPalette.<name>` constant.

- [ ] **Step 4: Run flutter analyze**

Run: `flutter analyze lib/widgets/heatmap_board.dart`
Expected: No new errors.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/heatmap_board.dart
git commit -m "refactor(heatmap): extract palette constants to named block

Heatmap colors are data viz, not UI chrome — they don't migrate to
colorScheme. Centralizing them in _HeatmapPalette makes the boundary
explicit so future migration sweeps don't accidentally touch them.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 3: Semantic disambiguation of red and rating arrows

### Task 3.1: Quit dialogs and Remove player buttons

**Files:**
- Modify: `lib/screens/shanghai_game_screen.dart`
- Modify: `lib/screens/cricket_game_screen.dart`
- Modify: `lib/screens/around_the_clock_game_screen.dart`
- Modify: `lib/screens/killer_game_screen.dart`
- Modify: `lib/screens/halve_it_game_screen.dart`
- Modify: `lib/screens/game_screen.dart` (X01)
- Modify: `lib/screens/stats_screen.dart`

- [ ] **Step 1: Find every Quit / Remove / destructive button**

Search:
```bash
grep -n "0xFFE53935\|0xFFB71C1C" lib/screens/*.dart
```

- [ ] **Step 2: Replace destructive-button red with cs.error**

For every match in a Quit-dialog button, Remove-player button, or delete confirmation:

Before:
```dart
style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFFE53935)),
```

After:
```dart
style: ElevatedButton.styleFrom(
    backgroundColor: Theme.of(context).colorScheme.error,
    foregroundColor: Theme.of(context).colorScheme.onError),
```

If the literal appears as a default `Colors.red` for the destructive button, change to `Theme.of(context).colorScheme.error`.

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze lib/screens/`
Expected: No new errors.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/
git commit -m "refactor(theme): map destructive buttons to colorScheme.error

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 3.2: X01 bust state

**Files:**
- Modify: `lib/screens/game_screen.dart`

- [ ] **Step 1: Find bust-related red usage**

Run:
```bash
grep -n "0xFFE53935\|bust\|Bust\|BUST" lib/screens/game_screen.dart
```

Expected matches at lines around 1437, 1581, 1618, 1828.

- [ ] **Step 2: Replace bust foreground/border red with cs.error**

For every bust-state foreground or border use of `Color(0xFFE53935)` or `Color(0xFFB71C1C)`:

Before:
```dart
color: const Color(0xFFE53935),
```

After:
```dart
color: Theme.of(context).colorScheme.error,
```

For bust-state backgrounds (the bust banner / chip), use:
```dart
color: Theme.of(context).colorScheme.errorContainer,
```
with foreground:
```dart
color: Theme.of(context).colorScheme.onErrorContainer,
```

- [ ] **Step 3: Verify "BUST" text is paired with an icon**

Find the "BUST" text label (around line 1581 area). Confirm or add `Icons.warning_amber` next to it so the signal is not color-only:

```dart
Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Icon(Icons.warning_amber, color: cs.error, size: 18),
    const SizedBox(width: 4),
    Text('BUST', style: TextStyle(color: cs.error, fontWeight: FontWeight.bold)),
  ],
),
```

(Where `cs = Theme.of(context).colorScheme`. If a `cs` local doesn't exist in the build method, add it at the top.)

- [ ] **Step 4: Run flutter analyze**

Run: `flutter analyze lib/screens/game_screen.dart`
Expected: No new errors.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/game_screen.dart
git commit -m "refactor(x01): bust state uses colorScheme.error + warning icon

Pairs the red color with an explicit warning icon so the BUST signal
works for color-blind users.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 3.3: Shanghai action buttons

**Files:**
- Modify: `lib/screens/shanghai_game_screen.dart`

- [ ] **Step 1: Locate the action buttons**

The single/double/triple action buttons are around line 660-680 of `shanghai_game_screen.dart` (`_buildActionButtons`). Currently they pass hardcoded green/blue/red.

- [ ] **Step 2: Replace with cs.primary / cs.secondary / cs.tertiary**

Before:
```dart
Expanded(
    child: _bigButton('${engine.currentTarget}',
        () => _onHit(HitType.single),
        const Color(0xFF43A047))),
const SizedBox(width: 8),
Expanded(
    child: _bigButton('D${engine.currentTarget}',
        () => _onHit(HitType.double_),
        const Color(0xFF1E88E5))),
const SizedBox(width: 8),
Expanded(
    child: _bigButton('T${engine.currentTarget}',
        () => _onHit(HitType.triple),
        const Color(0xFFE53935))),
```

After:
```dart
final cs = Theme.of(context).colorScheme;
// ...
Expanded(
    child: _bigButton('${engine.currentTarget}',
        () => _onHit(HitType.single),
        cs.primary)),
const SizedBox(width: 8),
Expanded(
    child: _bigButton('D${engine.currentTarget}',
        () => _onHit(HitType.double_),
        cs.secondary)),
const SizedBox(width: 8),
Expanded(
    child: _bigButton('T${engine.currentTarget}',
        () => _onHit(HitType.triple),
        cs.tertiary)),
```

(Make sure `cs` is in scope — declare it at the top of `_buildActionButtons` if needed.)

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze lib/screens/shanghai_game_screen.dart`
Expected: No new errors.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/shanghai_game_screen.dart
git commit -m "refactor(shanghai): action buttons use primary/secondary/tertiary

Single = primary (green, target hit), Double = secondary (red, brand
accent for the bigger hit), Triple = tertiary (seed-derived accent
distinct from danger). Frees red from doing double duty as triple.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 3.4: Rating arrows in post-game

**Files:**
- Modify: `lib/screens/post_game_screen.dart`

- [ ] **Step 1: Read post-game screen and find the rating delta widget**

Read the file fully. Look for where `ratingBefore` and `ratingAfter` are compared and rendered. The current rendering may be a colored `Text` showing a +/- delta.

- [ ] **Step 2: Add an icon to the rating change**

Replace the rating-delta rendering with:

```dart
Widget _buildRatingDelta(BuildContext context, double? before, double? after) {
  if (before == null || after == null) return const SizedBox.shrink();
  final delta = after - before;
  if (delta.abs() < 0.5) {
    return Text(
      '±0',
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }
  final cs = Theme.of(context).colorScheme;
  final positive = delta > 0;
  final color = positive ? cs.primary : cs.error;
  final icon = positive ? Icons.arrow_upward : Icons.arrow_downward;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 2),
      Text(
        '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(0)}',
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
      ),
    ],
  );
}
```

Wire this helper into the existing rendering. (Adapt to whatever the current rating-delta layout is — the key change is adding the arrow icon next to the colored number.)

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze lib/screens/post_game_screen.dart`
Expected: No new errors.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/post_game_screen.dart
git commit -m "refactor(post-game): rating delta uses arrow icon + semantic color

Positive delta → primary green + arrow_upward; negative → error red +
arrow_downward. Color is no longer the only signal.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 4: Drop per-player color from gameplay UI

### Task 4.1: Rename palette + introduce `_AvatarPalette`

**Files:**
- Modify: `lib/utils/player_colors.dart`

- [ ] **Step 1: Read the current file**

It exports `playerColors` (List<Color>) and `playerColor(int index)`.

- [ ] **Step 2: Rewrite the file**

```dart
import 'package:flutter/material.dart';

/// Avatar background palette. Used ONLY by PlayerAvatar to make different
/// players visually distinguishable in scoreboards. NOT used for gameplay
/// chrome — see docs/superpowers/specs/2026-04-29-material3-migration-design.md.
///
/// Colors selected to:
/// - Avoid colorScheme.primary (no greens), .secondary/.error (no pure reds),
///   .tertiary (avoid seed-derived hue), and amber/gold (winner medals).
/// - Be visually distinct from each other (≥30° hue separation).
/// - Pass WCAG 4.5:1 contrast against white initial-letter text.
const avatarColors = [
  Color(0xFF7E57C2), // purple
  Color(0xFFEC407A), // pink
  Color(0xFF26A69A), // teal
  Color(0xFFFFA726), // orange
  Color(0xFF5C6BC0), // indigo
  Color(0xFF8D6E63), // brown
  Color(0xFF42A5F5), // light blue
  Color(0xFF9E9D24), // olive
];

Color avatarColor(int index) => avatarColors[index % avatarColors.length];

// Backwards-compatible aliases — to be removed once all callers migrate.
@Deprecated('Use avatarColor(index) and only on avatar widgets')
const playerColors = avatarColors;
@Deprecated('Use avatarColor(index) and only on avatar widgets')
Color playerColor(int index) => avatarColor(index);
```

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze lib/`
Expected: deprecation warnings on every existing `playerColor` / `playerColors` call site. No errors.

- [ ] **Step 4: Run tests**

Run: `flutter test`
Expected: 25 passing.

- [ ] **Step 5: Commit**

```bash
git add lib/utils/player_colors.dart
git commit -m "refactor(theme): rename playerColor → avatarColor with new palette

New 8-hue palette tuned to avoid colliding with Material 3 colorScheme
roles or medal gold. Deprecated aliases remain so subsequent commits
can migrate call sites incrementally.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 4.2: Migrate avatar call sites to avatarColor()

**Files:**
- Modify: `lib/widgets/player_avatar.dart`
- Modify: `lib/widgets/mid_game_player_sheet.dart`
- Modify: `lib/screens/post_game_screen.dart` (if it passes a color)
- Modify: any other file calling `playerColor(...)` for an avatar context

- [ ] **Step 1: Find all call sites**

Run:
```bash
grep -rn "playerColor\|playerColors" lib/
```

- [ ] **Step 2: Replace each with avatarColor**

For each call site that is genuinely an avatar context (PlayerAvatar widget or similar), replace `playerColor(...)` with `avatarColor(...)` and update the import if needed.

For call sites that are NOT avatar contexts (mark buttons, scoreboard text, etc.), leave them flagged for Task 4.3.

- [ ] **Step 3: Run flutter analyze**

Expected: deprecation warnings remain only on non-avatar gameplay-UI call sites.

- [ ] **Step 4: Commit**

```bash
git add lib/
git commit -m "refactor(theme): migrate avatar call sites to avatarColor

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 4.3: Remove per-player color from non-avatar UI

**Files:**
- Modify: `lib/screens/cricket_game_screen.dart`
- Modify: `lib/widgets/cricket_scoreboard.dart`
- Modify: `lib/widgets/halve_it_scoreboard.dart`
- Modify: `lib/screens/shanghai_game_screen.dart`
- Modify: any other gameplay file using `playerColor(...)`

- [ ] **Step 1: Find remaining call sites**

Run:
```bash
grep -rn "playerColor\|playerColors" lib/
```

- [ ] **Step 2: Replace per-player color with semantic colors**

In **`lib/screens/cricket_game_screen.dart`** `_markButton` (around line 1019):

Before:
```dart
final color = playerColor(currentPlayerIndex);
// ...
backgroundColor:
    isFilled ? color.withAlpha(170) : Theme.of(context).colorScheme.surfaceContainer,
foregroundColor: isFilled ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
// ...
side: BorderSide(
  color: isFilled ? color.withAlpha(200) : Theme.of(context).colorScheme.outline,
),
```

After:
```dart
final cs = Theme.of(context).colorScheme;
// ...
backgroundColor:
    isFilled ? cs.primary.withValues(alpha: 0.7) : cs.surfaceContainer,
foregroundColor: isFilled ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.7),
// ...
side: BorderSide(
  color: isFilled ? cs.primary.withValues(alpha: 0.8) : cs.outline,
),
```

(Removes `final color = playerColor(currentPlayerIndex)` entirely.)

In **`lib/widgets/cricket_scoreboard.dart`**:

Before:
```dart
Text(
  playerNames[pi].length > 6 ? playerNames[pi].substring(0, 6) : playerNames[pi],
  style: TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    color: playerColor(pi),
    decoration: isCurrent ? TextDecoration.underline : null,
  ),
),
```

After:
```dart
Text(
  playerNames[pi].length > 6 ? playerNames[pi].substring(0, 6) : playerNames[pi],
  style: TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    color: Theme.of(context).colorScheme.onSurface,
    // (decoration removed — Phase 5 introduces ActivePlayerHighlight)
  ),
),
```

(Active player marker is removed here — it comes back in Phase 5 via the wrapper.)

In **`lib/widgets/halve_it_scoreboard.dart`**: any `playerColor` usage in text or chrome → `cs.onSurface` for text, `cs.surfaceContainer` for backgrounds. Active marker deferred to Phase 5.

In **`lib/screens/shanghai_game_screen.dart`** `_buildScoreboard`: the avatar already uses `playerColor(i)`. Change to `avatarColor(i)` (this is an avatar context). Remove any other `playerColor(i)` references in non-avatar parts (e.g. score text colors).

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze lib/`
Expected: zero deprecation warnings on `playerColor`/`playerColors` (every call site migrated).

- [ ] **Step 4: Run tests**

Run: `flutter test`
Expected: 25 passing.

- [ ] **Step 5: Commit**

```bash
git add lib/
git commit -m "refactor(gameplay): remove per-player color from non-avatar UI

Cricket mark buttons now light up in cs.primary regardless of who's
throwing. Scoreboards drop player-color name styling and underlines
(active-player highlight is centralized in Phase 5).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 4.4: Remove deprecated playerColor aliases

**Files:**
- Modify: `lib/utils/player_colors.dart`

- [ ] **Step 1: Verify no remaining usage**

Run:
```bash
grep -rn "playerColor\|playerColors" lib/
```
Expected: zero matches (the helper itself is gone after this task).

- [ ] **Step 2: Drop the deprecated aliases**

Delete the two `@Deprecated` lines + their bodies from `lib/utils/player_colors.dart`. The file should now only export `avatarColors` and `avatarColor`.

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze lib/`
Expected: No errors.

- [ ] **Step 4: Run tests**

Run: `flutter test`
Expected: 25 passing.

- [ ] **Step 5: Commit**

```bash
git add lib/utils/player_colors.dart
git commit -m "refactor(theme): drop deprecated playerColor aliases

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 5: ActivePlayerHighlight + Cricket dead-target dimming

### Task 5.1: Create the `ActivePlayerHighlight` widget

**Files:**
- Create: `lib/widgets/active_player_highlight.dart`
- Test: `test/widgets/active_player_highlight_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/active_player_highlight.dart';

void main() {
  group('ActivePlayerHighlight', () {
    testWidgets('renders the child unchanged when isActive=false', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ActivePlayerHighlight(
            isActive: false,
            child: const Text('hello'),
          ),
        ),
      ));
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('renders a bordered container when isActive=true', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ActivePlayerHighlight(
            isActive: true,
            child: const Text('hello'),
          ),
        ),
      ));
      expect(find.text('hello'), findsOneWidget);
      // The wrapper renders a Container with a Border for the active state.
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasBordered = containers.any((c) {
        final deco = c.decoration;
        return deco is BoxDecoration && deco.border != null;
      });
      expect(hasBordered, isTrue,
          reason: 'expected an active-state Container with a border');
    });

    testWidgets('does not shift layout between active and inactive', (tester) async {
      Future<Size> renderSize(bool active) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Center(
              child: ActivePlayerHighlight(
                isActive: active,
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ));
        return tester.getSize(find.byType(ActivePlayerHighlight));
      }
      final inactive = await renderSize(false);
      final active = await renderSize(true);
      expect(active, inactive,
          reason: 'wrapper must reserve same size in both states '
              'so layout does not shift when active player changes');
    });
  });
}
```

- [ ] **Step 2: Run the test to confirm it fails**

Run: `flutter test test/widgets/active_player_highlight_test.dart`
Expected: FAIL — `Couldn't resolve the package 'dart_scoring/widgets/active_player_highlight.dart'`.

- [ ] **Step 3: Implement the widget**

Create `lib/widgets/active_player_highlight.dart`:

```dart
import 'package:flutter/material.dart';

/// Standard active-player ring used across all game modes. When [isActive]
/// is true the child is wrapped in a bordered, tinted container; when false
/// the wrapper reserves the same total size with a transparent border so
/// switching active player does not shift surrounding layout.
class ActivePlayerHighlight extends StatelessWidget {
  final bool isActive;
  final Widget child;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final double borderWidth;

  const ActivePlayerHighlight({
    super.key,
    required this.isActive,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.borderWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        border: Border.all(
          color: isActive ? cs.primary : Colors.transparent,
          width: borderWidth,
        ),
        borderRadius: borderRadius,
        color: isActive ? cs.primary.withValues(alpha: 0.08) : null,
      ),
      child: child,
    );
  }
}
```

- [ ] **Step 4: Run the test to confirm it passes**

Run: `flutter test test/widgets/active_player_highlight_test.dart`
Expected: 3 passing.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/active_player_highlight.dart test/widgets/active_player_highlight_test.dart
git commit -m "feat(widget): ActivePlayerHighlight wrapper for unified active state

Wraps a child with a primary-color border + tinted background when
isActive is true, and reserves the same total size when false so
layout does not shift between turns.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 5.2: Adopt ActivePlayerHighlight in Shanghai

**Files:**
- Modify: `lib/screens/shanghai_game_screen.dart`

- [ ] **Step 1: Replace the inline border container in _buildScoreboard**

The current scoreboard (around line 540) wraps each player column in a hand-rolled `Container` with a `Border.all(color: ...primary)`. Replace that with `ActivePlayerHighlight`:

Before:
```dart
final wrapped = Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  decoration: BoxDecoration(
    border: Border.all(
      color: isActive ? primary : Colors.transparent,
      width: 3,
    ),
    borderRadius: BorderRadius.circular(12),
    color: isActive ? primary.withValues(alpha: 0.08) : null,
  ),
  child: col,
);
return Opacity(
  opacity: isRemoved ? 0.4 : 1.0,
  child: wrapped,
);
```

After:
```dart
return Opacity(
  opacity: isRemoved ? 0.4 : 1.0,
  child: ActivePlayerHighlight(
    isActive: isActive,
    child: col,
  ),
);
```

Add the import: `import '../widgets/active_player_highlight.dart';`

Also remove the local `final primary = Theme.of(context).colorScheme.primary;` if it's no longer used.

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze lib/screens/shanghai_game_screen.dart`
Expected: No new errors.

- [ ] **Step 3: Run tests**

Run: `flutter test`
Expected: 28 passing (25 + 3 new ActivePlayerHighlight tests).

- [ ] **Step 4: Commit**

```bash
git add lib/screens/shanghai_game_screen.dart
git commit -m "refactor(shanghai): use ActivePlayerHighlight widget

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 5.3: Adopt ActivePlayerHighlight in Cricket and Halve It scoreboards

**Files:**
- Modify: `lib/widgets/cricket_scoreboard.dart`
- Modify: `lib/widgets/halve_it_scoreboard.dart`

- [ ] **Step 1: Cricket scoreboard — wrap player column header**

In `cricket_scoreboard.dart` `DataColumn` for each player (around line 32), wrap the header in `ActivePlayerHighlight`:

Before:
```dart
return DataColumn(
  label: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        playerNames[pi].length > 6 ? playerNames[pi].substring(0, 6) : playerNames[pi],
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ],
  ),
);
```

After:
```dart
return DataColumn(
  label: ActivePlayerHighlight(
    isActive: isCurrent,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    borderRadius: BorderRadius.circular(8),
    borderWidth: 2,
    child: Text(
      playerNames[pi].length > 6 ? playerNames[pi].substring(0, 6) : playerNames[pi],
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  ),
);
```

(Smaller padding/border for the column header since space is tight.)

Add: `import 'active_player_highlight.dart';`

- [ ] **Step 2: Halve It scoreboard — wrap active player cell similarly**

Find the player-name rendering in `halve_it_scoreboard.dart`. Apply the same `ActivePlayerHighlight` wrapper (small padding/border) where the active player's column or row is identified. Use `currentPlayerIndex` to determine `isActive`.

If the widget doesn't currently take `currentPlayerIndex`, add it as a constructor parameter and update callers in `lib/screens/halve_it_game_screen.dart`.

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze lib/widgets/`
Expected: No new errors.

- [ ] **Step 4: Run tests**

Run: `flutter test`
Expected: 28 passing.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/cricket_scoreboard.dart lib/widgets/halve_it_scoreboard.dart lib/screens/halve_it_game_screen.dart
git commit -m "refactor(scoreboards): use ActivePlayerHighlight in Cricket + Halve It

Replaces the underline marker (Cricket) and ad-hoc highlights (Halve It)
with the shared bordered + tinted wrapper.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 5.4: Adopt ActivePlayerHighlight in X01, ATC, Killer

**Files:**
- Modify: `lib/screens/game_screen.dart` (X01)
- Modify: `lib/screens/around_the_clock_game_screen.dart`
- Modify: `lib/screens/killer_game_screen.dart`

- [ ] **Step 1: For each screen, identify the "active player" anchor**

The active player is currently shown as either:
- A colored player banner / current-player tile near the top of the screen
- A row in a scoreboard widget

In each file, locate the widget that renders the current player's name + score and visually represents "this is whose turn it is."

- [ ] **Step 2: Wrap that widget in ActivePlayerHighlight**

For each found widget, wrap it:

```dart
ActivePlayerHighlight(
  isActive: true,  // always true — this is the active-player anchor
  child: <existing widget>,
)
```

Add `import '../widgets/active_player_highlight.dart';`.

If the screen renders a list of all players in a scoreboard, the wrapper should be applied per-row with `isActive: i == currentPlayerIndex`.

Remove any pre-existing ad-hoc highlight (colored background, underline, etc.) that the wrapper now subsumes. If the only existing highlight was an avatar background being `cs.primary`, set the avatar back to `avatarColor(playerIndex)` for consistency with Phase 4.

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze lib/screens/`
Expected: No new errors.

- [ ] **Step 4: Run tests**

Run: `flutter test`
Expected: 28 passing.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/game_screen.dart lib/screens/around_the_clock_game_screen.dart lib/screens/killer_game_screen.dart
git commit -m "refactor(modes): unify active-player highlight in X01/ATC/Killer

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 5.5: Cricket dead-target dimming

**Files:**
- Modify: `lib/widgets/cricket_scoreboard.dart`
- Modify: `lib/screens/cricket_game_screen.dart`

- [ ] **Step 1: Add deadTargets parameter to CricketScoreboard**

In `cricket_scoreboard.dart`, add to the constructor:

```dart
final Set<int> deadTargets;
```

Update the constructor and required-args list:
```dart
const CricketScoreboard({
  super.key,
  required this.targets,
  required this.playerNames,
  required this.marks,
  required this.scores,
  required this.currentPlayerIndex,
  this.deadTargets = const {},
});
```

- [ ] **Step 2: Dim dead-target rows**

Find the per-target row in `build` (around line 57). Wrap the row in `Opacity(opacity: 0.35, ...)` when the target is dead, and switch the closed-mark icon color from `Colors.green` to `Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)`.

```dart
...targets.map((target) {
  final isDead = deadTargets.contains(target);
  return DataRow(cells: [
    DataCell(
      Opacity(
        opacity: isDead ? 0.35 : 1.0,
        child: Text(
          target == 25 ? 'Bull' : '$target',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            decoration: isDead ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    ),
    ...List.generate(playerNames.length, (pi) {
      final m = marks[pi][target] ?? 0;
      return DataCell(Center(
        child: Opacity(
          opacity: isDead ? 0.35 : 1.0,
          child: _markWidget(m, isDead, Theme.of(context).colorScheme),
        ),
      ));
    }),
  ]);
}),
```

Update `_markWidget` signature:

```dart
Widget _markWidget(int count, bool isDead, ColorScheme cs) {
  if (count == 0) return const SizedBox(width: 24);
  final closedColor = isDead ? cs.onSurface.withValues(alpha: 0.4) : Colors.green;
  if (count == 1) {
    return Text('/', style: TextStyle(fontSize: 16, color: cs.onSurface));
  }
  if (count == 2) {
    return Text('X', style: TextStyle(fontSize: 16, color: cs.onSurface));
  }
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(isDead ? Icons.lock_outline : Icons.radio_button_checked,
          size: 16, color: closedColor),
      if (count > 3)
        Text('+${count - 3}',
            style: TextStyle(fontSize: 10, color: closedColor)),
    ],
  );
}
```

(Adds a lock icon for "dead target — cannot score on this anymore" so the signal isn't only the dimmed color.)

- [ ] **Step 3: Compute dead targets in the game screen and pass to scoreboard**

In `lib/screens/cricket_game_screen.dart`, add a helper next to `_isClosedByAll`:

```dart
Set<int> get _deadTargets =>
    targets.where(_isClosedByAll).toSet();
```

Find where `CricketScoreboard` is instantiated and pass `deadTargets: _deadTargets`.

- [ ] **Step 4: Disable mark buttons for dead targets**

In `cricket_game_screen.dart` `_markButton` (around line 1016), replace:

```dart
return SizedBox.expand(
  child: ElevatedButton(
    onPressed: () => _registerHit(target, multiplier),
```

with:

```dart
final isDead = _isClosedByAll(target);
return SizedBox.expand(
  child: Tooltip(
    message: isDead ? 'Closed by all players' : '',
    child: ElevatedButton(
      onPressed: isDead ? null : () => _registerHit(target, multiplier),
```

(Wrap the existing closing braces accordingly.)

`onPressed: null` triggers Material 3's default disabled visual.

- [ ] **Step 5: Run flutter analyze**

Run: `flutter analyze lib/`
Expected: No new errors.

- [ ] **Step 6: Run tests**

Run: `flutter test`
Expected: 28 passing.

- [ ] **Step 7: Commit**

```bash
git add lib/widgets/cricket_scoreboard.dart lib/screens/cricket_game_screen.dart
git commit -m "feat(cricket): dim and disable targets closed by all players

Targets where every player has 3+ marks are now visually dimmed in the
scoreboard (line-through + lock icon) and their mark buttons are
disabled. Removes the dead state where players could still throw at
targets that no longer scored anything.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 6: Final verification + version bump

### Task 6.1: Color-blindness sanity check

**Files:** none (manual verification)

- [ ] **Step 1: Capture before/after screenshots** of one representative gameplay state per mode (X01 mid-game, Cricket mid-game with dead target, Shanghai mid-turn, ATC, Killer playing phase, Halve It).

- [ ] **Step 2: With OS color filter set to "Deuteranomaly"** (red-green color-blind simulation), confirm:
  - Active-player ring is still visible (it's a clear shape, not just a color)
  - Cricket dead targets are clearly dimmed (line-through + lock icon)
  - Rating arrows in post-game show the direction (icon, not just color)
  - Bust state in X01 shows "BUST" + warning icon

- [ ] **Step 3: Note any failures** in `docs/superpowers/specs/2026-04-29-material3-migration-design.md` under a new "Followups" section if needed; otherwise skip.

### Task 6.2: Final cleanup grep

**Files:** none (verification only)

- [ ] **Step 1: Verify no stray hex literals**

```bash
grep -rn "Color(0xFF" lib/ --include='*.dart' | grep -v dart_board.dart | grep -v heatmap_board.dart | grep -v player_colors.dart | grep -v home_screen.dart
```
Expected: zero matches. (Exemptions: dartboard physical colors, heatmap palette, avatar palette, home-screen logo.)

- [ ] **Step 2: Verify no stray playerColor / playerColors**

```bash
grep -rn "playerColor\b\|playerColors\b" lib/
```
Expected: zero matches.

- [ ] **Step 3: Verify all 28 tests pass**

Run: `flutter test test/models/shanghai_engine_test.dart test/services/tts_service_init_test.dart test/widgets/active_player_highlight_test.dart`
Expected: 28 passing.

If anything is unclean: fix in a follow-up commit, repeat.

### Task 6.3: Bump version + build APK

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: Update pubspec.yaml**

Change `version: 1.6.1+10` → `version: 1.7.0+11` (minor bump — substantial UX/theme overhaul).

- [ ] **Step 2: Update home screen version label**

Change `'v1.6.1'` → `'v1.7.0'`.

- [ ] **Step 3: Build the APK**

Run: `flutter build apk --release`
Expected: `Built build/app/outputs/flutter-apk/app-release.apk`.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml lib/screens/home_screen.dart
git commit -m "chore: bump version to 1.7.0 (color system overhaul)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 6.4: Hand-off to user for merge

**Files:** none

- [ ] **Step 1: Summarize the branch state**

Print:
- Number of commits ahead of `main`
- Whether all tests pass
- Whether the APK built
- Path to before/after screenshots if any

- [ ] **Step 2: Pause for user review**

Do not merge. Wait for the user to inspect the worktree, possibly run the APK on a device, and decide when to merge to `main`.

---

## Self-review notes

- All 5 spec phases have task coverage: Phase 1 (Task 1.1), Phase 2 (Tasks 2.1-2.4), Phase 3 (Tasks 3.1-3.4), Phase 4 (Tasks 4.1-4.4), Phase 5 (Tasks 5.1-5.5). Plus Phase 6 verification + release.
- Function names: `avatarColor` (Task 4.1) is referenced consistently in 4.2, 4.3, 4.4, and 5.4.
- `ActivePlayerHighlight` parameter list defined in 5.1, used identically in 5.2 (Shanghai), 5.3 (Cricket/HalveIt), 5.4 (X01/ATC/Killer).
- Mapping table in Phase 2 is repeated in full at the top of Phase 2 so a reader doesn't need to chase.
- No "TODO" or "TBD" placeholders.
