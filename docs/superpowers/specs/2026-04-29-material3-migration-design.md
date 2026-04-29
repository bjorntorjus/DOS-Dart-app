# Material 3 Color System Migration

**Date:** 2026-04-29
**Branch:** `feature/material3-migration`
**Worktree:** `.worktrees/m3-migration/`

## Problem

Color usage in the Dart Scoring app is inconsistent:

- **194 hardcoded hex literals** (`Color(0xFF...)`) across 22 files. Same colors repeated everywhere instead of referencing the theme.
- **Red `#E53935` is overloaded with conflicting meanings**: brand-secondary (logo), danger (Quit/Remove buttons), bust (X01), and high-value triple (Shanghai). Same pixel, opposite signals.
- **Player palette collides with semantic colors**: player 0 is blue (collides with "double" blue in Shanghai action buttons); player 2 is green (collides with the active-player ring just introduced in v1.6.0).
- **Greyscale is ad hoc**: `#374151`, `#4B5563`, `#1E1E1E`, `#2A2A2A`, `#1A1A1A`, `#121212`, `Colors.grey[700/800]` — no system, just guessed values per screen.
- **Shanghai action button colors are arbitrary**: green/blue/red for single/double/triple, no relation to dartboard or semantic meaning.

The app implicitly runs on Material 3 (Flutter 3.16+ default) but uses M2-era APIs — manually-picked `ColorScheme.dark` with three colors, no surface scale, no tonal palette. We get M3 widget defaults but none of the systematic gains.

## Goal

Adopt Material 3's tonal color system so the app uses **named roles** (`colorScheme.surfaceContainer`, `colorScheme.error`) instead of hex literals. Free `red` from its overloaded meanings. Make grey-scale systematic. Keep the visual identity (green primary, red as accent for danger only) recognizable.

## Non-goals

- **Light mode.** App stays dark-only. M3 makes light mode trivial later, but it is not in scope.
- **Dynamic Color** (Android 12+ wallpaper-derived theme). Not in scope.
- **Visual redesign.** Layouts, button shapes, typography, padding stay as they are. This change is purely about how colors are *expressed* in code, with three deliberate semantic shifts (see below).
- **Player palette generation algorithm.** Player colors stay a static list, but the list itself gets reshuffled to avoid collisions.

## Approach

Three sequential phases, each independently shippable. Each phase ends with `flutter analyze` clean and the existing test suite green.

### Phase 1 — Switch to `ColorScheme.fromSeed`

Replace the hand-rolled `ColorScheme.dark(...)` in `main.dart` with `ColorScheme.fromSeed(seedColor: <green>, brightness: dark)`. Override `secondary` to keep the existing red, and override `error` to a slightly more vivid red so it reads clearly as "danger".

Result after Phase 1: app builds and runs identically; surface scale and tonal palettes are now *available* via `Theme.of(context).colorScheme`, but no consumer uses them yet. This is the safe "land the foundation" step.

### Phase 2 — Migrate hex literals to color roles

Systematic search-and-replace across all 22 files using a fixed mapping table:

| Hex literal | New role |
|-------------|----------|
| `0xFF1E1E1E` (surface, AppBar bg) | `colorScheme.surface` |
| `0xFF121212` (scaffold bg) | `colorScheme.surfaceContainerLowest` |
| `0xFF2A2A2A` (table cell) | `colorScheme.surfaceContainerLow` |
| `0xFF374151` (raised tile bg) | `colorScheme.surfaceContainer` |
| `0xFF4B5563` (tile border) | `colorScheme.outline` |
| `0xFF1A1A1A` (dartboard black) | stays a const in `dart_board.dart` (board-specific identity, not UI surface) |
| `0xFF43A047` (brand green) | `colorScheme.primary` |
| `0xFFE53935` (semantic — see Phase 3) | resolved per call site in Phase 3 |

The mapping is approximate — actual M3 tones from a green seed will not match the existing greys exactly. Visually verify each screen after migration; refine the mapping if specific surfaces look wrong.

Heatmap (`heatmap_board.dart`) gets an exemption: its red→amber→green→teal gradient is a data visualization, not UI chrome. Keep its hex constants but extract them to a named `_HeatmapPalette` constant block at the top of the file.

Dartboard rendering (`dart_board.dart`) keeps its `boardBlack/boardCream/boardRed/boardGreen` constants — those are physical dartboard colors, not part of the UI theme.

### Phase 3 — Semantic disambiguation of red

After Phase 2, every `0xFFE53935` is still inline somewhere because Phase 2 deferred it. Now resolve each one per intent:

| Use site | New role |
|----------|----------|
| Quit-game button (every game screen) | `colorScheme.error` |
| Remove player dialog button | `colorScheme.error` |
| Bust button / Bust state highlight (X01) | `colorScheme.error` / `colorScheme.errorContainer` for backgrounds |
| Brand logo on home screen | stays `colorScheme.secondary` (red is intentional brand) |
| Shanghai "Triple" action button | `colorScheme.tertiary` (M3 generates an amber-leaning third color from the seed) |
| Shanghai "Double" action button | `colorScheme.secondary` |
| Shanghai "Single" (target) action button | `colorScheme.primary` |

After this phase, `red === error semantically` everywhere except the brand logo. "Triple" is no longer dangerous-red; it's a distinct accent (tertiary).

### Player palette adjustment

Reshuffle `playerColors` in `lib/utils/player_colors.dart` to avoid collisions:

- Remove **green** (collides with active-player ring / primary)
- Remove **blue** as position 0 (collides with Shanghai's "double" action color, which becomes `colorScheme.secondary` post-migration; but if we keep red as secondary, blue might be fine — decide after Phase 3)
- Replace with two distinct hues that have not appeared in any semantic role: e.g. **deep purple**, **lime**, **brown**

Final palette: 8-10 hues, all visually distinct, none colliding with primary/secondary/tertiary/error.

## Files affected

**Core (Phase 1):**
- `lib/main.dart` — theme definition

**Mass migration (Phase 2):** all 22 files identified by grep, especially:
- `lib/screens/*.dart` (12 files)
- `lib/widgets/*.dart` (9 files)

**Phase 3 disambiguation:**
- `lib/screens/game_screen.dart` (X01 — bust)
- `lib/screens/shanghai_game_screen.dart` (action buttons)
- `lib/screens/cricket_game_screen.dart`, `killer_game_screen.dart`, `halve_it_game_screen.dart`, `around_the_clock_game_screen.dart`, `shanghai_game_screen.dart` (Quit dialogs)
- `lib/utils/player_colors.dart` (palette reshuffle)

## Testing & verification

- `flutter analyze` clean after each phase
- Existing test suite (25 tests) stays green at every commit
- **Manual visual smoke-test** after each phase: launch each game screen (X01, Cricket, Shanghai, ATC, Killer, Halve It), confirm colors look intentional. Take screenshots at start of Phase 1 and after Phase 3 for before/after comparison.
- No new tests needed — this is a presentational change. Existing widget tests already cover layout structure.

## Risk & mitigations

| Risk | Mitigation |
|------|-----------|
| M3 auto-generated greens differ from `#43A047` exactly | Override `primary` after `fromSeed` if the difference is visually unacceptable |
| Hex→role mapping is wrong for some surfaces (e.g. tile bg looks too dark) | Visually verify per phase; refine mapping inline |
| Player palette change confuses returning users | Document in commit; saved players don't have hardcoded colors so nothing breaks |
| Worktree drifts from main if main gets new commits during work | Phases are short; rebase if needed |

## Definition of done

- All 194 hardcoded hex `Color(0xFF...)` literals are gone from `lib/screens/` and `lib/widgets/` (except documented exemptions: `dart_board.dart` board colors, `heatmap_board.dart` heat gradient)
- Red is used exclusively for: brand logo (1 site) and `colorScheme.error` semantics (danger/bust). No red action buttons.
- Greyscale uses `colorScheme.surface*` roles, no raw `0xFF1E1E1E`-style values
- Player palette regenerated to avoid collisions with primary/secondary/tertiary/error
- `flutter analyze` clean, all 25 tests pass, app runs and all 6 game screens have been opened to visually verify
- Branch ready to merge to `main`
