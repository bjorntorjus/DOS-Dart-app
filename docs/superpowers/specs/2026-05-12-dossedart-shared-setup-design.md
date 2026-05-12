# DOSSEDART shared setup screens

**Status:** Approved 2026-05-12
**Branch:** `feat/dossedart-arcade-v1`
**Context:** Apply the arcade-styled player picker (currently only in X01 setup) to all game modes. Extract shared scaffold + picker into reusable widgets so future modes (Shanghai variants, Gotcha) can adopt the pattern cheaply.

## Goals

- Consistent DOSSEDART setup screen for X01, Cricket, Killer, Around the Clock, Splitscore (Halve It), and Shanghai.
- Reuse a single picker grid + scaffold across all modes.
- Each mode owns its own RULES section, composed from a small set of arcade primitives.
- No new sliders or other custom widgets beyond a `[-] N [+]` stepper.

## Non-goals

- Roster / profile management screen (planned separately).
- Persisting last-used mode config across sessions.
- Manual reorder of selected players (selection order = play order).
- Replacing the legacy `PlayerSetupScreen` until DOSSEDART is the default theme.

## Architecture

### New files

```
lib/screens/dossedart/
  dossedart_cricket_setup_screen.dart
  dossedart_killer_setup_screen.dart
  dossedart_atc_setup_screen.dart
  dossedart_splitscore_setup_screen.dart
  dossedart_shanghai_setup_screen.dart

lib/widgets/dossedart/setup/
  dossedart_setup_scaffold.dart
  dossedart_player_picker.dart
  dossedart_picker_tile.dart
  rules_primitives.dart
```

### Refactored files

- `lib/screens/dossedart/dossedart_x01_setup_screen.dart` — slimmed to ~150 lines, composes scaffold + X01 RULES.
- `lib/screens/dossedart/dossedart_home_screen.dart` — all five mode tiles route to the new per-mode setup screens (currently non-X01 modes route via legacy `PlayerSetupScreen`).

### Untouched

- `lib/screens/player_setup_screen.dart` — kept as fallback for non-DOSSEDART flow. Deleted once DOSSEDART becomes default.
- Engine files, `dossedart_tokens.dart`, `ArcadeFrame`.

## Components

### `DossedartSetupScaffold`

Owns picker state and the surrounding chrome. Takes:

```dart
DossedartSetupScaffold({
  required String title,
  required Widget rulesSection,
  required int minPlayers,
  required String Function(int playerCount) summaryBuilder,
  required void Function(List<Player> players, bool randomize) onStart,
});
```

Internal state: `_savedPlayers`, `_selectedIds`, `_randomOrder` (default `true`), `_isLoading`. Loads players from `PlayerStorage` on init. Handles ADD-player dialog and long-press → profile-edit dialog (reuses the existing dialog logic from `PlayerSetupScreen`).

### `DossedartPlayerPicker`

Stateless. Renders a 2-column grid of tiles + an ADD PLAYER tile. Takes `savedPlayers`, `selectedIds`, `onToggle(SavedPlayer)`, `onLongPress(SavedPlayer)`, `onAdd()`.

### `DossedartPickerTile`

One tile. Shows:

- Avatar (round, top-left) via the existing `PlayerAvatar` widget. Falls back to a colored circle with the player's initial when `avatarPath` is null.
- Player name (large, centered, uppercase).
- `R 1420` rating + 5 W/L pips on one row.
- `P1/P2/P3…` slot badge on selected tiles (rotated, yellow).
- Border: magenta unselected, yellow selected.
- **No 3-letter handle.** Avatar replaces the handle. (Handle is being phased out across the design.)

### `rules_primitives.dart`

Three reusable building blocks used by all mode RULES sections:

- `ArcadeChipRow<T>` — radio-style chip row, generic on value type. Takes `label`, `value`, `options: List<(String label, T value)>`, `onChanged`.
- `ArcadeToggleRow` — a row of 2-3 toggles, each with its own accent color (magenta/cyan/purple).
- `ArcadeStepper` — `[-] N [+]` for range config. Takes `label`, `value`, `min`, `max`, `onChanged`.

### Per-mode RULES sections

Built inline in each `Dossedart<Mode>SetupScreen` from the primitives above. Not extracted into separate widget files — keeping each setup screen self-explanatory.

Example (Cricket):

```dart
Widget _buildRules() => Column(children: [
  ArcadeChipRow<bool>(
    label: 'MODE',
    value: _isCutthroat,
    options: const [('STANDARD', false), ('CUTTHROAT', true)],
    onChanged: (v) => setState(() => _isCutthroat = v),
  ),
  ArcadeChipRow<bool>(
    label: 'TARGETS',
    value: _isRandom,
    options: const [('15-20', false), ('RANDOM', true)],
    onChanged: (v) => setState(() => _isRandom = v),
  ),
  if (_isRandom)
    ArcadeStepper(
      label: 'COUNT',
      value: _targetCount,
      min: 3,
      max: 15,
      onChanged: (v) => setState(() => _targetCount = v),
    ),
  ArcadeToggleRow(toggles: [
    ('BULL', _includeBull, DossedartTokens.magenta,
     (v) => setState(() => _includeBull = v)),
  ]),
]);
```

## Data flow

- **Scaffold owns picker state.** Mode screen owns mode-config state.
- Mode screen passes scaffold two callbacks: `summaryBuilder(playerCount)` and `onStart(players, randomize)`.
- Scaffold builds `List<Player>` from selected `SavedPlayer`s with `score: 0` (placeholder) and calls `onStart`.
- Mode screen adjusts scores (X01 handicap only), shuffles when `randomize`, then `pushReplacement` to the right game screen.
- No async coupling: picker state changes never trigger mode-config reloads.

## Defaults per mode

| Mode | Min players | Mode-specific defaults |
|---|---|---|
| X01 | 2 | `outRule=none, noBust=false, handicap=false` |
| Cricket | 2 | `isCutthroat=false, isRandom=false, includeBull=true, targetCount=7` |
| Killer | 2 | `lives=3, throwToPick=true, multiplyHits=false, shields=false, suicide=false` |
| ATC | 1 | `includeBull=false, countMultiples=true, reverse=false` |
| Splitscore | 1 | `isRandom=false, roundCount=9, includeDouble=true, includeTriple=true, includeBull=true` |
| Shanghai | 1 | `targetEnd=7` |

All modes default `_randomOrder = true`.

Killer min-players is **2** (changed from legacy 3) per design decision.

## Validation and edge cases

- START button disabled while `selected < minPlayers`. Summary line shows `N PLAYERS · MIN M`. No SnackBar.
- Empty name in ADD PLAYER → "CREATE" disabled.
- Duplicate names allowed (current behavior).
- Long-press on an unselected tile: profile dialog opens, selection state unchanged.
- Long-press on ADD PLAYER tile: ignored.
- Empty player roster: grid renders only the ADD PLAYER tile.
- `PlayerStorage` failures: not handled (follows existing pattern).

## Testing

### Widget tests

- `test/widgets/dossedart/rules_primitives_test.dart`:
  - `ArcadeChipRow` — tap calls `onChanged` with the right value; selected chip renders with yellow background.
  - `ArcadeToggleRow` — tap toggles state; accent color applied per toggle.
  - `ArcadeStepper` — `[+]` and `[-]` respect `min`/`max`; `onChanged` called with the new value.
- `test/widgets/dossedart/dossedart_setup_scaffold_test.dart`:
  - START disabled when `selectedIds.length < minPlayers`.
  - Summary shows `MIN N` when under threshold.
  - `onStart` called with the correct player count and `randomize` flag.

### Not tested

- Per-mode RULES composition (covered by primitive tests).
- ADD PLAYER and profile-edit dialogs (reused from `PlayerSetupScreen`).
- Navigation to game screens (Flutter framework).
- Tile pixel rendering (visual QA in emulator).

### Manual QA checklist (per mode, before merge)

1. Home → mode tile → setup. Top bar title is correct.
2. Select 2-3 players. P1/P2/P3 slot badges appear in selection order.
3. Long-press → profile dialog opens. Edit name → tile refreshes.
4. Mode-config: tap each chip, toggle each switch, stepper `[+]`/`[-]` respects bounds.
5. Start-bar summary updates on every config change.
6. START disabled below min-players, enables at or above.
7. START → correct game screen opens with correct config and player order (shuffled when RANDOM is on).
