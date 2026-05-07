# Material 3 Color System Migration & Color-Logic Cleanup

**Date:** 2026-04-29
**Branch:** `feature/material3-migration`
**Worktree:** `.worktrees/m3-migration/`

## Problem

Color usage in the Dart Scoring app is inconsistent and violates basic UI color best practices.

### Theme & roles
- **194 hardcoded hex literals** (`Color(0xFF...)`) across 22 files. Same colors repeated everywhere instead of referencing the theme.
- **Greyscale is ad hoc**: `#374151`, `#4B5563`, `#1E1E1E`, `#2A2A2A`, `#1A1A1A`, `#121212`, `Colors.grey[700/800]` — no system, just guessed values per screen.
- The app implicitly runs on Material 3 (Flutter 3.16+ default) but uses M2-era APIs — manually-picked `ColorScheme.dark` with three colors, no surface scale, no tonal palette.

### Overloaded semantics
- **Red `#E53935` is overloaded with conflicting meanings**: brand-secondary (logo), danger (Quit/Remove buttons), bust (X01), and high-value triple (Shanghai). Same pixel, opposite signals.
- **Player palette collides with semantic colors**: player 0 is blue (collides with "double" blue in Shanghai action buttons); player 2 is green (collides with the active-player ring introduced in v1.6.0).
- **Shanghai action button colors are arbitrary**: green/blue/red for single/double/triple — no relation to dartboard or any semantic system.

### Per-screen color logic
- **Per-player color is overused.** Mark buttons, scoreboards, score text, throw history all use `playerColor(i)`. The user's brain learns "green is Bjørn", but green also means primary/active/success in the rest of the app — these collide constantly.
- **Cricket "closed by all" is invisible.** When every player has closed a number it is dead, but the scoreboard still shows green ring icons and the mark buttons stay enabled. The player can throw at a target that does nothing.
- **Cricket mark buttons recolor based on whose turn it is**, conflating "this mark belongs to player X" with "this is your turn."
- **Active-player highlight is inconsistent across modes.** Shanghai got a green border + tinted background in v1.6.0; Cricket uses underline; X01/ATC/Killer/Halve It use mostly-colored backgrounds. No common pattern.

## Goal

Adopt Material 3's tonal color system *and* clean up the color logic that has accreted across screens, applying common color-design best practice:

1. Color is a signal — limit the palette to a small set of meaningful roles
2. Use opacity/saturation for hierarchy, not new colors
3. Reserve red for danger/error
4. Reserve green for success/active/positive
5. Color must never be the *only* signal (color-blindness)
6. Categorical color (player avatars) uses a calibrated palette, kept separate from semantic roles

Keep the visual identity (green primary, red as danger, gold for winners) recognizable.

## Non-goals

- **Light mode.** App stays dark-only. M3 makes light mode trivial later; not in scope.
- **Dynamic Color** (Android 12+ wallpaper-derived theme). Not in scope.
- **Visual redesign of layouts.** Layouts, button shapes, typography, padding stay as they are. This change is purely about how colors are used, with deliberate semantic shifts (see below).
- **New game features.** No mechanics change.

## Color role inventory

After this migration the app uses exactly these color roles. Every other color is a deviation that needs justification.

| Role | Source | Used for |
|------|--------|----------|
| `colorScheme.primary` | seeded green | Active state, primary action buttons, brand chrome, success/positive trend |
| `colorScheme.secondary` | overridden red | Brand logo only (1 site) |
| `colorScheme.tertiary` | seed-derived | Distinct accents (e.g. Shanghai "Triple", info badges) |
| `colorScheme.error` | overridden vivid red | Danger/destructive actions (Quit, Remove, Bust), error state |
| `colorScheme.surface*` (8-level scale) | seed-derived neutrals | All chrome backgrounds, tile fills, dividers |
| `colorScheme.outline` | seed-derived | Borders, dividers |
| `Colors.amber` (gold) | constant | Winner medals (1st place), gold trophy |
| `Colors.grey.shade300/400` (silver/bronze) | constants | 2nd/3rd place medals only |
| `_AvatarPalette` (8 hues, defined in code) | hand-tuned | **Avatar backgrounds only.** Not used anywhere else. |

Anything else (bright purple borders, magenta highlights, custom navy backgrounds) is a smell to investigate.

## Approach

Five sequential phases. Phases 1-3 are the M3 plumbing; phases 4-5 are the cleanup of color logic the user flagged. Each phase is independently shippable: `flutter analyze` clean, 25 tests green, app runs at every commit.

### Phase 1 — Switch to `ColorScheme.fromSeed`

Replace the hand-rolled `ColorScheme.dark(...)` in `main.dart`:

```dart
colorScheme: ColorScheme.fromSeed(
  seedColor: const Color(0xFF43A047),
  brightness: Brightness.dark,
  secondary: const Color(0xFFE53935),  // keep brand red as accent
  error: const Color(0xFFE53935),       // M3 default error is more orange; force red
),
```

Drop `scaffoldBackgroundColor` (M3 surface handles it). Set `useMaterial3: true` explicitly even though it is the default in Flutter 3.16+ (defensive against Flutter SDK bumps that change defaults).

After Phase 1: app builds and runs identically; surface scale and tonal palettes become available via `Theme.of(context).colorScheme`. No consumer uses them yet.

### Phase 2 — Migrate hex literals to color roles

Mapping table applied across all 22 files:

| Hex literal | New role |
|-------------|----------|
| `0xFF1E1E1E` (surface, AppBar bg) | `cs.surface` |
| `0xFF121212` (scaffold bg) | `cs.surfaceContainerLowest` |
| `0xFF2A2A2A` (table cell) | `cs.surfaceContainerLow` |
| `0xFF374151` (raised tile bg) | `cs.surfaceContainer` |
| `0xFF4B5563` (tile border) | `cs.outline` |
| `0xFFD1D5DB` (dim foreground) | `cs.onSurface.withValues(alpha: 0.7)` |
| `0xFF43A047` (brand green) | `cs.primary` |
| `0xFFE53935` (deferred to Phase 3) | left as-is in this phase |

Hardcoded `Colors.grey[700/800]` etc. in disabled/empty states map to `cs.surfaceContainer` (background) and `cs.onSurface.withValues(alpha: 0.4)` (foreground).

The mapping is approximate — actual M3 tones from a green seed will not match the existing greys exactly. Visually verify each screen after migration; refine mapping if specific surfaces look wrong.

**Exemptions** (these do not migrate to roles):
- `dart_board.dart` — `boardBlack/boardCream/boardRed/boardGreen` are physical dartboard colors, kept as named consts
- `heatmap_board.dart` — red→amber→green→teal heat gradient is a data visualization. Keep its hex constants but extract them to a named `_HeatmapPalette` const block at the top of the file
- Avatar palette (introduced in Phase 4) — defined in code, intentionally separate

### Phase 3 — Semantic disambiguation

Resolve every remaining `0xFFE53935` per intent, plus other red-misuse:

| Use site | New role |
|----------|----------|
| Quit-game button (every game screen) | `cs.error` |
| Remove player dialog button | `cs.error` |
| Bust button + bust state highlight (X01) | `cs.error` for fg, `cs.errorContainer` for bg |
| Brand logo on home screen | `cs.secondary` (red is intentional brand) |
| Shanghai "Triple" action button | `cs.tertiary` |
| Shanghai "Double" action button | `cs.secondary` |
| Shanghai "Single" (target) action button | `cs.primary` |
| Stats screen "game-mode" label | `cs.primary` |
| Rating-up arrow in post-game | `cs.primary` (green = positive trend), pair with `Icons.arrow_upward` |
| Rating-down arrow in post-game | `cs.error` (red = negative trend), pair with `Icons.arrow_downward` |

After this phase, red is used **only** for:
- Brand logo on home screen (1 site)
- `cs.error` semantics (danger / bust / negative trend)

No red action buttons. No red triples.

### Phase 4 — Drop per-player color from gameplay UI

User decision: "I want to move away from each player having their own color. It is enough to show whose turn it is."

Per-player color is **kept only on avatars** (so different players are still visually distinguishable in scoreboards and the avatar-circle on screens). Everywhere else `playerColor(i)` is removed.

Concretely:

**Removed uses of `playerColor(i)`:**
- `cricket_game_screen.dart` mark buttons (filled state recolors per turn) → all filled marks use `cs.primary` regardless of who is throwing
- `cricket_scoreboard.dart` player name color → all player names `cs.onSurface`; active player uses the unified active-player highlight (Phase 5) instead
- `halve_it_scoreboard.dart` any per-player coloring → unified
- Any `Text` / `Container` decoration that derives from `playerColor(i)` for non-avatar UI

**Kept uses of `playerColor(i)`:**
- `widgets/player_avatar.dart` background → still uses palette
- `mid_game_player_sheet.dart` avatar in the row → still uses palette

**New `_AvatarPalette` constant** in `lib/utils/player_colors.dart` — 8 hand-tuned hues that:
- Do not match `cs.primary` (no greens), `cs.secondary` / `cs.error` (no pure reds), `cs.tertiary` (avoid the seed-derived tertiary hue) or amber/gold
- Are distinct from each other (≥30° hue separation, similar saturation/lightness)
- Pass WCAG 4.5:1 contrast against `cs.onSurface` text overlay

Suggested initial palette (tune visually): `#7E57C2` (purple), `#EC407A` (pink), `#26A69A` (teal), `#FFA726` (orange), `#5C6BC0` (indigo), `#8D6E63` (brown), `#42A5F5` (light blue), `#9E9D24` (olive). Renamed from `playerColors` to `avatarColors` and the function from `playerColor(i)` to `avatarColor(i)` so usage sites are unmistakable.

`PlayerAvatar` widget now defaults `backgroundColor` to `avatarColor(playerIndex)` and exposes `playerIndex` as a parameter. Any caller passing `backgroundColor: cs.primary` for the active-player highlight stops doing so — Phase 5 owns highlighting via a wrapper, not via avatar bg color.

### Phase 5 — Unified active-player highlight + Cricket closed-target dimming

#### 5a. Unified active-player highlight

Pull the Shanghai pattern (green border + tinted background container) into a reusable widget `ActivePlayerHighlight` in `lib/widgets/active_player_highlight.dart`:

```dart
class ActivePlayerHighlight extends StatelessWidget {
  final bool isActive;
  final Widget child;
  // ...
}
```

Renders the child wrapped in a `Container` with `Border.all(color: cs.primary, width: 3)` + `cs.primary.withValues(alpha: 0.08)` background when `isActive`, and a transparent same-shape container when not (so layout doesn't shift).

Replace per-screen ad hoc highlighting:
- Cricket scoreboard's underline → wrap player column in `ActivePlayerHighlight`
- X01 / ATC / Killer / Halve It current-player banners → wrap whatever the current "active player" anchor is
- Shanghai already has the pattern → swap to the new shared widget

The existing scoreboard data widgets (`CricketScoreboard`, `HalveItScoreboard`, ATC clock progress) get a `currentPlayerIndex` parameter and apply `ActivePlayerHighlight` internally on the right cell/column.

#### 5b. Cricket closed-target dimming

In Cricket, when *every* player has 3+ marks on a target, that target is dead — no points can be scored on it.

Engine helper: `cricket_game_screen.dart` already has `_isClosedByAll(target)` private method. Expose its information to scoreboard and mark-button widgets.

Scoreboard (`cricket_scoreboard.dart`):
- Take a new `Set<int> deadTargets` parameter
- Rows where `target` is in `deadTargets` render at `opacity: 0.35`, ring icons use `cs.onSurface.withValues(alpha: 0.4)` instead of green

Mark buttons grid (in `cricket_game_screen.dart`):
- For dead targets, set `onPressed: null` (Material 3 will dim automatically) and reduce opacity
- Tooltip "Closed by all players" on the disabled tile

#### 5c. Color is never the only signal

Wherever color carries meaning, pair it with shape/icon/text:

| Signal | Color | Pairing |
|--------|-------|---------|
| Mark closed | green ring | `Icons.radio_button_checked` (already an icon) ✓ |
| Mark closed by all (dead) | dim grey | strikethrough or `Icons.lock_outline` |
| Rating up | green | `Icons.arrow_upward` |
| Rating down | red | `Icons.arrow_downward` |
| Active player | green ring | bold name text + ring |
| Bust state | red bg | "BUST" text + `Icons.warning_amber` |
| Removed player (mid-game) | dim grey | "Removed from this game" caption (already there) ✓ |

Add the missing icons during Phase 5 cleanup.

## Files affected

**Phase 1:**
- `lib/main.dart`

**Phase 2 (mass migration):** all 22 files identified by grep, especially:
- `lib/screens/*.dart` (12 files)
- `lib/widgets/*.dart` (9 files)

**Phase 3 (semantic):**
- `lib/screens/game_screen.dart` (X01 — bust)
- `lib/screens/shanghai_game_screen.dart` (action buttons)
- `lib/screens/{cricket,killer,halve_it,around_the_clock,shanghai}_game_screen.dart` (Quit dialogs)
- `lib/screens/post_game_screen.dart` (rating arrows)
- `lib/screens/stats_screen.dart` (game-mode label)

**Phase 4 (per-player color removal):**
- `lib/utils/player_colors.dart` (rename + new palette)
- `lib/widgets/player_avatar.dart`
- `lib/widgets/cricket_scoreboard.dart`
- `lib/widgets/halve_it_scoreboard.dart`
- `lib/widgets/mid_game_player_sheet.dart`
- All game screens that use `playerColor(i)` for non-avatar UI

**Phase 5 (highlight + dimming):**
- New: `lib/widgets/active_player_highlight.dart`
- `lib/widgets/cricket_scoreboard.dart` (deadTargets param + ActivePlayerHighlight)
- `lib/widgets/halve_it_scoreboard.dart` (ActivePlayerHighlight)
- `lib/screens/cricket_game_screen.dart` (mark buttons disable on dead, pass deadTargets)
- `lib/screens/shanghai_game_screen.dart` (use shared widget)
- `lib/screens/{game,killer,halve_it,around_the_clock}_game_screen.dart` (apply ActivePlayerHighlight)
- `lib/screens/post_game_screen.dart` (rating arrows)

## Testing & verification

- `flutter analyze` clean after each phase
- Existing test suite (25 tests) stays green at every commit
- **Manual visual smoke-test** after each phase: open every game screen and confirm colors look intentional. Take a screenshot at start of Phase 1 and after Phase 5 for before/after comparison
- Phase 4: open a game with 3+ players in Cricket and Shanghai and confirm avatar colors are still distinct and no other UI element is colored per-player
- Phase 5: in Cricket with 3 players, close 20 with all players. Verify the 20 row dims and the 20 mark buttons disable. Confirm active-player highlight looks identical across all 6 modes
- Color-blindness sanity check: open the app with the OS color-filter set to "Deuteranomaly" (red-green) and confirm rating arrows, marks, and active-player highlight remain distinguishable (icons should carry the signal even when colors blur)
- No new automated tests required — this is presentational. Existing widget tests cover layout structure, and the active-player highlight wrapper is simple enough that a snapshot test would over-constrain

## Risk & mitigations

| Risk | Mitigation |
|------|-----------|
| M3 auto-generated greens differ from `#43A047` exactly | Override `primary` after `fromSeed` if visually unacceptable |
| Hex→role mapping is wrong for some surfaces | Visually verify per phase; refine mapping inline |
| Removing player color confuses returning users who tracked by color | Avatars retain color; only chrome stops being colored. Document in commit |
| Cricket "closed by all" disable may break unusual edge cases (e.g. instant win mid-turn) | Keep `_isClosedByAll` logic unchanged — only the *display* changes; engine still records throws normally |
| `ActivePlayerHighlight` wrapper may shift layout subtly when isActive flips | Reserve the same total size (3px transparent border when inactive) so layout is stable |
| Worktree drifts from main if main gets new commits during work | Phases are short; rebase if needed |

## Definition of done

- All 194 hardcoded hex `Color(0xFF...)` literals are gone from `lib/screens/` and `lib/widgets/` (except documented exemptions: `dart_board.dart` board colors, `heatmap_board.dart` heat gradient, `_AvatarPalette` constants)
- Red is used exclusively for: brand logo (1 site), `cs.error` semantics (danger/bust/down-trend). No red action buttons, no red triples
- Greyscale uses `cs.surface*` roles, no raw `0xFF1E1E1E`-style values
- `playerColor(i)` is renamed to `avatarColor(i)` and used **only** in avatar widgets; gameplay UI no longer recolors per player
- Cricket dead targets dim out + disable mark buttons
- All 6 game screens use the shared `ActivePlayerHighlight` for the active-player ring
- Every meaningful color signal is paired with an icon/shape so the design works for color-blind users
- `flutter analyze` clean, all 25 tests pass, app runs and all 6 game screens have been opened to visually verify on dark theme, and the color-blindness OS filter sanity check has been performed
- Branch ready to merge to `main`
