# Handoff — DOSSEDART X01 Round (arcade redesign)

## Overview
This bundle covers the **X01 game flow** of DOSSEDART in the new arcade visual language: HOME → SETUP → IN-GAME (cockpit + 7 states). Picker variant A is the locked pattern for player selection. The match Cricket is **out of scope** for this round (recolor only, deferred).

The brief was an in-app round of design exploration for the X01 flow specifically. The original handoff bundle (`/design_handoff_dossedart_redesign`) defines the broader scope; this folder is the X01 deliverable on top of that.

## About the Design Files
The HTML files in this bundle are **design references created in HTML** — interactive prototypes showing the intended look, states, and behavior. They are **not production code to copy directly**. The task is to **recreate these designs in the existing DOSSEDART Flutter codebase** using its established widgets, theming, and patterns. Layout intent, copy, color values and state transitions should be lifted from the prototypes; widget-tree mapping follows the original handoff README.

Each `.html` file is a Design Canvas — multiple artboards side-by-side (820 × 1180 phone canvas). Click an artboard to focus it fullscreen; ←/→/Esc to navigate.

## Fidelity
**High-fidelity.** Final colors, typography (Press Start 2P + VT323), spacing, and state behavior are intended to ship. Spacing/border values may need a one-pass refinement against the actual device — the canvas is 820×1180, phones run smaller. Treat exact pixel values as proportional guidance; treat colors, type, and component structure as final.

## Visual language — "Arcade"

**Type:**
- Display / numbers / labels: `Press Start 2P` (Google Fonts).
- Captions, secondary, status copy: `VT323` (Google Fonts).
- Body uses `Press Start 2P` sparingly — letter-spacing 1–4px, line-height ~1, all-caps where possible. Long copy uses `VT323`.

**Color tokens** (used throughout):
| Token       | Hex       | Role |
|-------------|-----------|------|
| `BG`        | `#0a0014` | Page background |
| `SURFACE`   | `#1a0030` | Card / panel background |
| `MAGENTA`   | `#FF00AA` | Primary accent (UI chrome, primary CTA, P1 player) |
| `CYAN`      | `#00E5FF` | Secondary accent (nav, links, P3 player) |
| `YELLOW`    | `#FFD200` | Highlight (titles, active warnings, P2 player) |
| `GREEN`     | `#3DFF8E` | Success / checkout-available |
| `RED`       | `#FF3050` | Destructive / BUST / sudden death |
| `PURPLE`    | `#7B3FFF` | Tertiary accent (rare) |
| Orange      | `#FF7A00` | MISS button / warning secondary |

**Effects:**
- Scanline overlay across every full-screen frame: `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`.
- Vignette: `radial-gradient(ellipse at center, transparent 50%, rgba(0,0,0,0.6) 100%)`.
- Neon glow on accents: `box-shadow: 0 0 14–40px <accent>aa` and matching `text-shadow: 0 0 6–18px <accent>aa`.
- Borders are **2–3px solid accent**, never gray. Square corners — `border-radius: 0` everywhere except avatars (which are square too — only player-color border).

**Iconography:** Unicode glyphs only (▶ ◀ ✓ ✗ ⚡ ★ ↶ ⋯ ⚠). No SVG icons.

---

## Screens / Views

### 1. HOME — `DOSSEDART home arcade overhaul.html`
**Out of scope per the original handoff README** — included here for completeness because the user explored a redesign in this round. The Flutter codebase keeps the existing Home untouched. Use this file as a reference for the arcade language only.

Locked direction: bordered scoreboard with magenta chrome, mode select grid (X01 / Cricket / 50K), live ticker, leaderboard module. Footer is `STATS · HISTORY · SETTINGS`.

### 2. PLAYER PICKER (locked pattern) — `DOSSEDART picker variants.html`, variant A
The picker is a **3-column grid of square (1:1) PlayerCards**. Each card has:
- 36px square avatar with player-color border, top-left.
- Player name beneath avatar, `Press Start 2P` 11–12px, all-caps.
- W/L pip row centered under the name, right of the avatar — small green / red squares (recent results, max ~8). Variant A is the **locked** pattern — see picker file.
- Selection badge top-right when picked: solid player-color square, white join-order number (`1`, `2`, …) in `Press Start 2P` ~13px.
- Last grid cell is **`+ ADD PLAYER`**: dashed cyan border, "+" glyph, opens new/guest flow.

**Dropped from earlier explorations** (do NOT include): rating, win %, head-to-head, "press to join" state.

### 3. SETUP — `DOSSEDART setup arcade refined.html`
Phase 2 widget tree per original handoff README, in arcade visual language.

**ModeBar** (top): mode-chip placeholder (left), start-score chips `301 / 501 / 701` (center), `D-OUT` toggle chip (right).

**Rules block** (3 rows, full-width):
- `OUT RULE`: `FREE / DOUBLE / MASTER` segmented control.
- `OPTIONS`: `NO-BUST` toggle · `HANDICAP` toggle · `RANDOM ORDER` toggle. When `HANDICAP` is on, each PlayerCard shows that player's per-player start score.

**SelectionBar**: `N SELECTED` pill (left) + `🎲 RANDOMIZE` button (right). Randomize **shuffles join-order numbers, not card positions** — spatial memory of "where Mia's card is" is preserved.

**PlayerCard grid**: 3-column grid, picker variant A. Last cell is `+ ADD PLAYER` (see Picker section).

**FooterBar**: `+ NEW · CLEAR · ··· spacer ··· START →` (magenta primary).

**Mode-list**: full mode list (Cricket, handicap, etc.) is **not yet defined** for this handoff — `MODE ▾` is a placeholder. Wire the real Flutter `enum GameMode` into the chip when implementing.

### 4. X01 IN-GAME — `DOSSEDART x01 ingame.html`
**Cockpit** layout (board-first), with a player carousel.

#### 4a. Cockpit (default state)
Top to bottom:
1. **TopBar** — `◀ EXIT` (cyan, left) · centered title `X01 · 501 · DOUBLE OUT` (yellow, glow) · `LEG 1/3 · RND 7` (right, dim VT323). Magenta 2px bottom border.
2. **Player Carousel** — horizontal scroll rail. Active player card centered (~86% width), prev/next peek cards (~7% each) on either side.
   - **Active card**: player-color border, faint color-tinted gradient background, 60px avatar, name (Press Start 2P 16px), 3-dot dart counter (filled = thrown, hollow = pending) + `DART N / 3` caption, big `REMAINING` number in player color (Press Start 2P 56px, glow), `LAST <code> (<score>)` row beneath, **checkout-tip strip** when finishable (green dashed border, `T20 › S16 › D-Bull`).
   - **Peek cards**: surface bg with 0.45 opacity, 28px avatar, remaining score, `◀ PREV` / `NEXT ▶` rotated label. Green `OUT` corner badge if checkout-available.
   - **Indicators row**: pagination pills above the rail — active player's pill is wider and player-colored.
3. **Dartboard** — ~640px square, centered. Visual placeholder; real touch zones (D-Bull → Bull → inner-single → triple → outer-single → double → miss) wire in during implementation.
4. **ActionBar** — black bg, yellow top border. Three buttons: `↶ UNDO` (magenta border, narrow), `✗ MISS` (filled orange, wide, primary), `⋯ MENU` (cyan border, narrow).

#### 4b. States
All states render over or replace the cockpit. Cockpit + 7 states:

| State           | Trigger                          | Behavior |
|-----------------|----------------------------------|----------|
| **BUST**        | Score < 2, ends on 1, or non-double finish | Red flash takeover, big `BUST` text, score-revert copy (`170 → 170`), filled red `CONTINUE ▶` button. Locks input until tapped. |
| **SUDDEN DEATH**| Tie-break / first-double-wins ruleset | Red→orange gradient banner pinned under TopBar (`⚡ SUDDEN DEATH · FIRST DOUBLE WINS ⚡`); cockpit otherwise unchanged. Hint label by board reads `► HIT ANY DOUBLE`. |
| **TURN END**    | 3rd dart thrown                  | Dim overlay over board. Caption `TURN COMPLETE · N SCORED`, big `NEXT UP`, magenta-bordered card with next player's avatar/name/remaining + `CHECKOUT` if applicable, hint `SWIPE LEFT OR TAP ▶`. Auto-advances. |
| **MENU**        | `⋯ MENU` tapped                  | Backdrop blur + cyan-bordered sheet, items: `RESUME` (green primary), `EDIT LAST THROW` (yellow), `REMOVE PLAYER` (orange), `RESTART LEG` (cyan), `ABANDON MATCH` (red). Each row has secondary VT323 caption and `▶` glyph. |
| **PLAYER REMOVED** | Confirm step inside MENU → REMOVE PLAYER | Red-bordered modal centered over board: `⚠ PLAYER REMOVED`, removed avatar at 0.5 opacity + line-through name, copy `STATS DROPPED · TURN ORDER RESHUFFLED`, `↶ UNDO` and red `CONFIRM ▶`. |
| **LEG WON**     | Player finishes a leg (non-final) | Full-screen takeover. `★★★★★`, `LEG N WINNER`, 200px winner avatar with player-color border + glow, big winner name, stats row (`16 DARTS · AVG 31.3 · HIGH 121`), `CHECKOUT · T20 › S16 › D8` strip, opponents' remaining as colored chips. Footer: `END MATCH` / `NEXT LEG ▶` (magenta). |
| **MATCH WON**   | Player wins last leg of best-of  | Like Leg Won but yellow `★ MATCH WON ★` header, `BEST OF N · score` subline, leg breakdown (`L1 MIA · L2 JON · L3 MIA`) instead of opponent chips. Footer: `RECAP / REMATCH / HOME ▶`. |

---

## Interactions & Behavior

**Carousel**
- Horizontal scroll-snap on the player rail. Active card snaps center.
- Swiping changes which card is "viewed" — does NOT change whose turn it is. Turn order is set by Setup.
- After the third dart of a turn, after BUST CONTINUE, or after WINNER NEXT LEG, the carousel auto-snaps to the next thrower (TURN END transition plays first).
- Indicator pills update as you scroll.

**Dartboard input**
- Tap-zones map to standard dart score regions (D-Bull, Bull, S, D, T per number, miss).
- Each tap: increments the active player's `dartIdx`, fills the next dot in the 3-dot counter, updates `LAST` label, decrements `REMAINING`, recomputes checkout-tip if remaining ≤ 170 and a valid 1–3 dart double-out path exists.
- `UNDO` reverses the last dart (also undoes BUST if last action was the bust-trigger dart).
- `MISS` registers a 0-score dart.

**Animations**
- BUST flash: red border pulse 0.4s, then settle.
- WINNER / MATCH WON: starfield + glow pulse on the winner avatar (~1.5s ease-out).
- Carousel snap: 250ms ease-out.
- Scanlines and vignette are static.

**Form validation / edge cases**
- Setup `START →` disabled when fewer than 1 player selected.
- BUST is non-dismissable except via `CONTINUE`.
- `EDIT LAST THROW` from MENU returns to cockpit with the last dart's tap-zone re-highlighted for re-entry.

---

## State management (suggested)

Match-level state:
- `mode`, `startScore`, `outRule`, `noBust`, `handicap`, `randomOrder`
- `players: PlayerInMatch[]` — `{ id, displayName, color, throwOrder, remaining, dartsThrown, lastThrow, history[] }`
- `activePlayerIdx`, `dartIdx (0..2)`, `legNumber`, `legWins[]`
- `phase: 'playing' | 'bust' | 'sudden_death' | 'turn_end' | 'menu' | 'removed_confirm' | 'leg_won' | 'match_won'`

Transitions are driven by dart-input events:
- `dart(zone)` → updates active player; if `remaining === 0 && lastDartIsDouble` → `leg_won` (or `match_won` if last leg); if invalid finish → `bust`; if `dartIdx === 3` → `turn_end` → auto-advance.

---

## Design Tokens

```
COLORS
  bg          #0a0014
  surface     #1a0030
  magenta     #FF00AA
  cyan        #00E5FF
  yellow      #FFD200
  green       #3DFF8E
  red         #FF3050
  purple      #7B3FFF
  orange      #FF7A00 (warning secondary only)

TYPE
  display     "Press Start 2P"  9, 10, 11, 12, 13, 14, 16, 18, 32, 48, 54, 56, 96 px
  caption     "VT323"           11, 13, 14, 16, 18, 22, 28 px
  letter-spacing 1–6 px

SPACING (used in mocks)
  4 6 8 10 12 14 16 18 22 24 28 30 36 40 px

BORDERS
  1 px dashed (separators)
  2 px solid  (cards, chips)
  3 px solid  (active card, modals, avatars)
  4–6 px      (BUST overlay, winner avatar)

SHADOWS / GLOWS (neon)
  0 0 6  px <c>aa   small text/icon glow
  0 0 14 px <c>aa   button glow
  0 0 18 px <c>55   active card glow
  0 0 24–40 px <c>aa  state takeovers

EFFECTS
  scanline:  repeating-linear-gradient(0deg, transparent 0 2px, rgba(0,0,0,.3) 3px, transparent 4px)
  vignette:  radial-gradient(ellipse at center, transparent 50%, rgba(0,0,0,.6) 100%)
```

---

## Assets
No image assets — everything is rendered with CSS/SVG. Fonts loaded from Google Fonts (`Press Start 2P`, `VT323`). The dartboard is a procedural SVG inside `x01-ingame.jsx`.

---

## Files in this bundle

| File | Purpose |
|------|---------|
| `DOSSEDART home arcade overhaul.html` | Home (out-of-scope reference) |
| `home-arcade-overhaul.jsx` | Home React component |
| `DOSSEDART picker variants.html` | Picker exploration; variant A is locked |
| `picker-variants.jsx` | Picker variants component |
| `DOSSEDART setup arcade refined.html` | Setup (Phase 2) — locked |
| `setup-arcade-detailed.jsx` | Setup React component |
| `DOSSEDART x01 ingame.html` | X01 cockpit + 7 states — locked |
| `x01-ingame.jsx` | Cockpit + states React component |
| `design-canvas.jsx` | Canvas/artboard helper used by every HTML file |
| `shared.jsx` | Shared atoms (player colors, fonts, scanline frame) |
| `styles.css` | Global stylesheet (font imports, base) |
| `README.md` | This file |

To open any HTML file: it loads the canvas + its component, fonts come from Google Fonts via `<link>` in the page `<head>`. No build step.

## Implementation order (suggested)
1. Tokens + theme constants in the Flutter codebase (colors, font families, scanline overlay widget, neon-glow helper).
2. Reusable atoms: `PlayerAvatar`, `PlayerCard` (picker A), `DartDots`, `Chip`, `PrimaryButton`, `Sheet`, `Frame` (scanline + vignette wrapper).
3. SETUP screen — straightforward layout, low risk.
4. X01 COCKPIT — carousel is the only non-trivial widget; build active card + peek card variants, then the snap-rail.
5. Wire dart input + state machine; add states one at a time in this order: TURN END → BUST → MENU → REMOVED → SUDDEN DEATH → LEG WON → MATCH WON.
6. Cricket recolor only — apply tokens, no layout work.
