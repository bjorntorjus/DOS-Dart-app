# Color & Design System (M3 — Round 2)

**Status:** Adopted (rev 2026-07-07 — two-track model)
**Date:** 2026-04-30
**Branch:** `feature/material3-migration`

## Goal

Establish a single, written contract for color usage across the app. Replaces the implicit conventions accumulated in round 1 of the M3 migration. Every future component decision is checked against this document — no ad-hoc color choices.

## Palette

Four roles, four colors. No more.

| Role        | Hex       | Name         | When                                                  |
| ----------- | --------- | ------------ | ----------------------------------------------------- |
| `primary`   | `#43A047` | Green        | Brand, primary action, active player, positive change |
| `secondary` | `#FFA726` | Orange       | Secondary action, finished/out state, "warning-not-error" |
| `tertiary`  | `#FFD54F` | Amber        | Informational highlights, achievements, tips          |
| `error`     | `#E53935` | Red          | Bust, destructive action, negative change             |

Surface and on-* colors are derived from `ColorScheme.fromSeed(seedColor: #43A047, brightness: dark)` with the four roles above overridden.

## Usage rules

### Primary (green)

Use when the user's *intended forward path* is the obvious next step.

- The dominant CTA on a screen (Continue, Save, Start)
- Active player highlight (border, current-turn badge)
- Rating delta when positive (+12 ▲)
- Achievement counters trending up

Never use for: destructive actions, neutral information, "out" states.

### Secondary (orange)

Use for actions and states that are valid but *not* the dominant path.

- Alternative action when primary already holds the dominant CTA (New Game next to Continue)
- Player who has finished/checked out (post-finish score, finished-list entries)
- Soft warnings that are *not* errors: overshoot value (-2), nearly-out battery, missing config that's recoverable
- Mid-game actions that change state without ending the game (Add Player, Skip Turn)

Never use for: dominant CTA on a screen, errors, hover/disabled tints.

### Tertiary (amber)

Use sparingly for information that *deserves to be noticed* but is not actionable.

- Checkout suggestion ("Checkout: T20 T20 Bull")
- Winner label / podium gold tint
- Achievement highlights (180!, hat trick, high finish)
- Stats callouts (best leg, highest turn)

Never use for: actions/buttons (use primary or secondary), errors.

### Error (red)

Reserved. Single semantic: *something has gone wrong or is destructive.*

- Bust state (border, badge, "BUST" label)
- Destructive action buttons (Quit, Delete Player, Reset)
- Rating delta when negative (-8 ▼)
- Form validation failures

Never use for: secondary actions, accent variety, "danger lite" states (use orange instead).

## Surface hierarchy

Five tiers in dark mode (M3 default). Pick by *elevation intent*, not by ad-hoc preference.

| Surface                     | Hex         | Use                                          |
| --------------------------- | ----------- | -------------------------------------------- |
| `surface`                   | `#121212`   | App background                               |
| `surfaceContainerLow`       | `#1e1e1e`   | Inactive cards (player rows, list items)     |
| `surfaceContainer`          | `#232323`   | Default container (settings sections, dialogs) |
| `surfaceContainerHigh`      | `#2a2a2a`   | Elevated container (modal, bottom sheet)     |
| `surfaceContainerHighest`   | `#363636`   | Floating panels, snackbars                   |

### Surface rules

- Cards at rest use `surfaceContainerLow`.
- Active player card stays on `surfaceContainerLow` and gets a 2px `primary` border — *don't* elevate the surface to mark active state.
- Disabled/finished player rows use `surfaceContainerLow` with `opacity: 0.7`.
- Within a card, nested information uses no further surface — use only typography weight and `onSurfaceVariant` color for hierarchy.

## Player avatar colors

`avatarColor` palette is **separate** from the role palette. Avatar colors only appear:

- On the avatar circle itself
- On the avatar's name when avatars are not visible (e.g., compact player list)

Avatar colors **never** appear on backgrounds, borders, or buttons. Active state and finished state are conveyed by the role palette (primary border, orange "out" label) — not by manipulating the avatar color.

## DOSSEDART / Arcade track

The DOSSEDART redesign is a second, deliberate design track that lives beside
the classic four-role palette (decision 2026-07-06). It never uses
`colorScheme` roles; every color comes from `lib/theme/dossedart_tokens.dart`:

| Token | Hex | Use |
| --- | --- | --- |
| `bg` | `#0A0014` | app background |
| `surface` | `#1A0030` | cards, sheets |
| `surfaceRaised` | `#2A0050` | avatar chips, raised fills |
| `magenta` | `#FF00AA` | chrome, dividers, brand accent |
| `cyan` | `#00E5FF` | active player, focus |
| `yellow` | `#FFD200` | hero/highlight tints |
| `green` | `#3DFF8E` | positive |
| `red` | `#FF3050` | negative, destructive |
| `purple` | `#7B3FFF` | secondary accent |
| `orange` | `#FF7A00` | warm accent (start CTA gradient) |
| `phosphor` | `#D9D2C2` | body text |
| `silver` / `bronze` | `#C9D2DA` / `#D08A4A` | podium metals |
| `disabledFill/Border/Fg` | white @ 12/24/38% | disabled states |

Border widths: `borderThin` 1, `border` 2, `borderActive` 3, `borderTakeover` 5.
Dividers: major chrome = full `magenta` at 2px; subtle row dividers =
`magenta` at 40% alpha, 1px.
Alpha variants are expressed as `token.withValues(alpha: …)`, never as a new
raw hex of the same hue.

## Documented exceptions

- `lib/utils/player_colors.dart` — avatar palette (both tracks).
- `lib/widgets/heatmap_board.dart` — data-viz gradient.
- `lib/widgets/dart_board.dart` — physical bristle-board palette (its red
  `#E53935` coincidentally equals the error role; do not "fix" it).
- `lib/widgets/dossedart/x01/dossedart_x01_dartboard.dart` — neon twilight
  board palette, deliberately tuned near-neighbors of magenta/cyan.
- D-buttons `Colors.orange[800]` in halve_it/atc score input.
- Podium metals (classic): gold = `tertiary`, silver = `#C0C0C0`,
  bronze = `Colors.brown[300]`.
- CRT effects in `arcade_frame.dart` (black scanline/vignette) and the
  white-alpha text ramp in `game_detail_screen.dart` — pure black/white
  effect layers, not palette colors.

## State signaling

Common UI states and the role each maps to:

| State           | Role               | Treatment                                     |
| --------------- | ------------------ | --------------------------------------------- |
| Active          | `primary`          | 2px border, optional small "▶ ACTIVE" label   |
| Inactive        | `onSurfaceVariant` | Lower opacity, no border                      |
| Finished/Out    | `secondary`        | Score value tinted orange, "finished" label   |
| Bust            | `error`            | Border + label inside card                    |
| Achievement     | `tertiary`         | Amber label or icon overlay                   |
| Disabled        | `onSurface @ 38%`  | M3 default opacity, no color manipulation     |

## Migration notes

This spec is the contract. The Flutter implementation in this branch already migrated to `ColorScheme.fromSeed`, so the work needed is:

1. Add `tertiary: #FFD54F` to the `ColorScheme.fromSeed` override in `main.dart`.
2. Change `secondary` from `#E53935` to `#FFA726`.
3. Audit usages where `cs.secondary` was used for destructive intent and switch to `cs.error`.
4. Audit usages where amber/yellow appeared as a hex literal and replace with `cs.tertiary`.
5. Document in CLAUDE.md that the palette is fixed and any future component must pick from these four roles.

The implementation plan (next document) will break this into reviewable steps.

## Out of scope

- "To-win" indicator alongside checkout (tracked separately in memory, not part of color system).
- Light-mode palette — app is dark-mode-only for now.
- Animation/motion design — only color is in scope here.
