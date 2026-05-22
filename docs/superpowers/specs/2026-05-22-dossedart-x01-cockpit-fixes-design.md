# DOSSEDART X01 cockpit fixes — design

**Date:** 2026-05-22
**Status:** Spec
**Mockups:**
- `docs/design/dossedart-handoff/PROPOSAL-x01-brightness-v2.html`
**Related:**
- `docs/superpowers/specs/2026-05-20-dossedart-x01-cockpit-design.md` (original cockpit spec)

## Problem

QA on the v1.8.0 APK surfaced three issues in the DOSSEDART theme:

1. **"Dark cloud" in X01 cockpit.** The active player card body uses a `alpha 0.10 → 0.02` magenta gradient on the dark CRT background. The `ArcadeFrame` scanline overlay (30 % black every 4 px) blends into that low-contrast surface and makes the player info hard to read. Home and setup screens share the same overlay but use solid colors underneath, so they look fine. The dartboard itself looks fine; only the active card area reads as "muddy."
2. **In-game menu is too thin.** The current bottom-sheet only has *Player Overview* and *Exit Match*. No way to toggle sound, memes, video events, or TTS without leaving the game.
3. **Active card is sparse.** Shows REMAINING and (optionally) LAST 3 darts and a checkout tip. Missing 3-dart average — already computed for Player Overview but not surfaced in the cockpit.

A separate bug on the home screen:

4. **Hero rating wraps to two lines.** `_leaderboardRow` in `dossedart_home_screen.dart` puts the 1st-place rating in a 58-px column rendered in PressStart2P at fontSize 14. Four-digit ratings overflow.

## Goals

- Restore readability of the active card without touching the CRT atmosphere on other surfaces or the dartboard.
- Expose sound, video, memes, and TTS toggles from inside the game.
- Show 3-dart average in the active card.
- Keep 4-digit ratings on a single line on the home leaderboard.

## Non-goals

- No changes to `ArcadeFrame` (scanlines, vignette, scan beam).
- No changes to the dartboard widget — segment colors and alpha stay as today.
- No changes to the DOSSEDART palette.
- No podium / leaderboard restructuring — proposed and rejected during brainstorming.

## Design

### 1. Active-card background → solid

In `lib/widgets/dossedart/x01/dossedart_x01_active_card.dart`, replace the gradient background:

```dart
gradient: LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    accentColor.withValues(alpha: 0.10),
    accentColor.withValues(alpha: 0.02),
  ],
),
```

with a solid surface fill:

```dart
color: DossedartTokens.surface,
```

Border (`accentColor`, width 3) and box-shadow glow remain unchanged. The card stays magenta-bordered for the active player and reads as a solid pixel-art panel rather than a tinted ghost.

### 2. Active-card AVG stat

Add a `double? avg` parameter to `DossedartX01ActiveCard`. When non-null, render it in the existing LAST row area. New layout for the bottom section of the card (when there has been at least one completed turn):

```
┌─────────┬─────────────────────────────┐
│  AVG    │  LAST                       │
│  52.8   │  T20 · S20 · S20    = 80    │
└─────────┴─────────────────────────────┘
```

- AVG label: `PressStart2P` size 8, white60, letterSpacing 1.5.
- AVG value: `avg.toStringAsFixed(1)` in `PressStart2P` size 14, `DossedartTokens.cyan`, letterSpacing 1, glow shadow (cyan alpha 0.5 blur 6).
- AVG column has a fixed width (~52 px) so the LAST area still gets the rest.
- AVG hidden (column collapses) when `avg == null` or when no completed turn yet.

Wire it from `game_screen.dart`: compute `avg = total == 0 ? null : (pointsSum / total) * 3` using the same formula already used for `PlayerOverviewRow`, pass into the active card constructor.

### 3. In-game menu sheet

Restructure `_showDossedartMenu` in `game_screen.dart`. New layout (top to bottom):

| Row              | Type     | Detail                                      |
| ---------------- | -------- | ------------------------------------------- |
| SOUND            | Toggle   | `AppSettings.getSoundEffectsEnabled` / set  |
| VIDEO EVENTS     | Toggle   | `AppSettings.getVideoEventsEnabled` / set   |
| MEMES            | Toggle   | `AppSettings.getMemeEnabled` / set          |
| VOICE (TTS)      | Toggle   | `AppSettings.getTtsEnabled` / set           |
| *(divider)*      |          |                                             |
| PLAYER OVERVIEW  | Action › | Existing route                              |
| EXIT MATCH       | Action › | Existing flow, red                          |

Toggle visual: 44×22 pill with 14×14 knob. ON state = green border + 18 % green fill + green knob with glow; OFF state = white25 border + transparent fill + white50 knob. Labels in `PressStart2P` size 11. Icons in cyan (red on EXIT MATCH).

Toggle state is read once when the sheet opens and persisted via `AppSettings.set*` immediately on tap. Sheet remains open after a toggle — only Player Overview and Exit Match dismiss it.

The sheet stays a `showModalBottomSheet` on `DossedartTokens.surface`. Top grab handle (40×4 white30 pill) added so the rounded sheet reads as a sheet.

### 4. Home leaderboard hero rating fits one line

In `_leaderboardRow` in `dossedart_home_screen.dart`, the RATING column header and the per-row rating cell both have `width: 58`. Change to `width: 72` (both header and row). Font and letterSpacing unchanged. This eats 14 px from the `Expanded` PLAYER column — long names get ellipsised slightly sooner, which is acceptable.

## Tests

- Widget: `dossedart_x01_active_card_test.dart` — add a test that the card renders with `avg = 52.8` and that the AVG label is shown; another that with `avg = null` no AVG label is rendered.
- Widget: `dossedart_x01_active_card_test.dart` — assert the background is solid `DossedartTokens.surface` (no gradient).
- Widget: new test for the menu sheet (or extension of an existing game-screen test) — sheet contains four toggles plus Player Overview + Exit Match. Toggling SOUND off calls `AppSettings.setSoundEffectsEnabled(false)`.
- Manual: open the X01 cockpit, confirm the active card is readable and the dartboard is unchanged. Open the menu, toggle each setting, close and reopen — toggle state persists.

## Out of scope (already considered)

- **Podium on home.** Proposed during brainstorming and rejected — keep the tight list.
- **Dartboard segment alpha bump.** Considered but rejected — segments stay at `alpha 0.35`, user reports they look fine once the active-card "dark cloud" is gone.
- **Reducing `ArcadeFrame` overlay strength.** Same overlay works on home and setup; the problem was specific to the X01 cockpit's transparent foreground content.
