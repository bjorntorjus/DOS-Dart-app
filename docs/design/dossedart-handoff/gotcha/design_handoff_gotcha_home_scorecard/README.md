# Handoff: Gotcha — startside 3×3 + cockpit-scorecard (kill-help)

## Overview
Two approved DOSSEDART designs, ready for implementation:

1. **Home 3×3 grid** — today's arcade home screen, unchanged, with the "OR PICK A LEVEL"
   mode grid expanded from 2 columns to a **3×3 symbol grid** so the new **Gotcha** mode
   fits alongside placeholders for **Legs** and **Golf** (coming soon).
2. **Gotcha cockpit scorecard (v2)** — the in-game scorecard reworked so the two throwing
   aids fit without shrinking the board: a **CHECKOUT helper** (straight-out route toward the
   target) and a **KILL helper** (how to knock an opponent out this dart). The dartboard, MISS
   zone and action bar are **identical to the existing X01 cockpit** — nothing there changes.

Both belong to the "Gotcha" game mode feature described in `2026-07-07-gotcha-design.md`.

## About the Design Files
The files in this bundle are **design references created in HTML/React (Babel-in-browser JSX)**
— prototypes showing intended look and behavior, **not** production code to copy directly. The
task is to **recreate these designs in the DOSSEDART app's existing environment** (Flutter /
Dart — the cockpits, board painter and home already exist there) using its established widgets,
tokens and patterns. The JSX is only a faithful visual spec; port the values, not the React.

## Fidelity
**High-fidelity (hifi).** Final colors, typography, spacing, layout and states. Recreate
pixel-faithfully with the app's existing `DossedartTokens`, fonts and cockpit/home widgets.
The board geometry and chrome are already shipping — reuse them; do not rebuild.

---

## Design Tokens (shared arcade system — already in the app)

Colors:
- `YELLOW`   `#FFD200` — champion / highlight / score-label / target / X01 hero (501)
- `MAGENTA`  `#FF00AA` — chrome (borders, dividers, decorative), UNDO
- `CYAN`     `#00E5FF` — active player / navigation / system labels / "you"
- `GREEN`    `#3DFF8E` — checkout / win
- `RED`      `#FF3050` — kill / danger / d-bull
- `ORANGE`   `#FF7A00` — MISS button / bull stroke
- `BG`       `#0A0014` — app background
- `SURFACE`  `#1A0030` (home tiles / X01 uses `#160A2B` in some files — use existing token)
- `PHOSPHOR` / `SILVER` `#D9D2C2` — inactive content, 2nd place
- `BRONZE`   `#CD7F32` — 3rd place

Typography (Google Fonts; map to the app's existing pixel/arcade fonts):
- **Press Start 2P** — headings, scores, labels, mode names, X01 numbers
- **VT323** — secondary readouts, taglines, "TO GO", desc lines
- **Inter** (700/800) — spec-card body only (paper), not used in the arcade UI
- **JetBrains Mono / Archivo** — spec-card only

Effects (both screens):
- Scanline overlay: `repeating-linear-gradient(0deg, transparent 0-2px, rgba(0,0,0,0.3) 3px, transparent 4px)`, `zIndex 5`, `pointer-events:none`
- Vignette: `radial-gradient(ellipse at center, transparent 50-55%, rgba(0,0,0,0.6) 100%)`, `zIndex 4`
- Frame size (tablet portrait): **820 × 1180**

---

## Screen 1 — Home (3×3 mode grid)

**File:** `DOSSEDART home 3x3 gotcha.html` → `home-gotcha-3x3.jsx` (`HomeGotcha3x3Shell`)

### Purpose
App entry / game select. Player picks X01 (301/501/701) or one of the mode tiles → that mode's setup.

### What is UNCHANGED from today's home
Everything except the mode grid. Keep exactly as-is:
- **Header** (`#000`, 2px magenta bottom border): `★ ★ ★ INSERT COIN ★ ★ ★` (VT323 18, cyan, letter-spacing 4) · `DOSSE\nDART` (Press Start 2P 36, yellow, `text-shadow: 0 0 10px YELLOW, 4px 4px 0 MAGENTA`, line-height 1.3) · `©2024 OFFICE GAMES INC.` (VT323 20, phosphor).
- **Leaderboard podium** (`HIGH SCORES`, gold/silver/bronze blocks, crown on 1st, star corners, rating + W%). See note under "Only other change".
- **X01 row** (`► PLAYER 1 SELECT`): 3-col grid, tiles `301 🥉 short` / `501 🍻 classic` (hero = yellow) / `701 🏆 long`. SURFACE bg, 3px border, glow.
- **Footer** (2px yellow top border + magenta→yellow→cyan rainbow line): three cyan cabinet buttons `STATS · P-1`, `HISTORY · LOG`, `SETTINGS · CFG`.

### The ONE change — mode grid 2 cols → 3×3
Section header `► OR PICK A LEVEL` + yellow hint `NY: GOTCHA 💀`.
Grid: `grid-template-columns: 1fr 1fr 1fr`, `grid-template-rows: repeat(3, 1fr)`, `gap: 10px`,
occupying the flex-remaining area. Order (spec §4.1):

| Row | Col 1 | Col 2 | Col 3 |
|-----|-------|-------|-------|
| 1 | 🎯 Cricket (live) | 🕒 Around the Clock (live) | 🔪 Killer (live) |
| 2 | ✂️ Splitscore (live) | 🐉 Shanghai (live) | 💀 **Gotcha (NEW)** |
| 3 | 🦵 Legs (soon) | ⛳ Golf (soon) | ✨ Coming soon (soon) |

**Tile (vertical): emoji on top (28px, 24px for the generic), mode name below (Press Start 2P 9, letter-spacing .5, line-height 1.35, centered).** Three states:
- **live**: bg SURFACE, `2px solid PHOSPHOR`, `box-shadow: 0 0 8px PHOSPHOR33`. White name.
- **new** (Gotcha): bg `CYAN10`, `2px solid CYAN`, `box-shadow: 0 0 16px CYAN66, inset 0 0 14px CYAN22`, emoji `drop-shadow(0 0 6px CYAN)`, cyan name. Yellow **NEW** ribbon top-right (Press Start 2P 8, `rotate(5deg)`, `box-shadow 0 0 8px YELLOW`).
- **soon** (Legs / Golf / generic): `2px dashed MAGENTA55`, `opacity: 0.55`, no glow, extra VT323 12 line `COMING SOON` (or `SNART FLERE` for the generic tile). Not tappable.

`GameMode.gotcha` is added now. Legs / Golf / generic are **hardcoded placeholder tiles** until those modes exist — no dead enum values. They light up as each mode ships.

### Only other change
To make room for the third grid row within the same 820×1180 frame, the **podium block heights
were trimmed**: 1ST `200 → 158`, 2ND `150 → 118`, 3RD `130 → 100` (avatars `72/54/50 → 64/50/46`).
Purely spatial — no other podium changes. If your layout finds room elsewhere, the original
heights are fine to keep.

---

## Screen 2 — Gotcha cockpit scorecard v2 (kill-help)

**File:** `DOSSEDART gotcha cockpit v2.html` → `gotcha-cockpit-v2.jsx` (`Cockpit`)

### Purpose
In-game throwing screen for Gotcha. Score counts **UP** toward an exact target (default 301);
landing exactly on an opponent's total resets them (GOTCHA). The scorecard shows the active
player plus two live aids recomputed after every dart.

### What is UNCHANGED from the X01 cockpit — reuse verbatim
- **TopBar**: `◀ EXIT` (VT323 18 cyan) · center `💀 GOTCHA · 301` (Press Start 2P 11 yellow, glow) · `MÅL 301` (VT323 16). `#000`, 2px magenta bottom border.
- **Board zone**: absolutely positioned `top:330, bottom:66`, centered. Locked CRT "BALANSERT"
  board rendered at **size 760**. Behind it a 740×740 circle with `box-shadow: 0 0 70px MAGENTA3a`.
- **MISS corners**: four `✗ MISS` hints (Press Start 2P 9, magenta, `opacity 0.3`) at the board-zone corners. Whole field around the circle = tappable MISS.
- **ActionBar** (absolute bottom, `#000`, 2px yellow top border, `padding: 12px 16px 16px`):
  `↶ UNDO` (flex 1, magenta border) · `✗ MISS` (flex 2, ORANGE fill, white border, glow) · `⋯ MENU` (flex 1, cyan border). All Press Start 2P 11.

**Do not resize or reposition the board, MISS corners, or action bar.** All new space came from
the scorecard only.

### The scorecard (redesigned) — `ScoreCard`
Card container: `margin: 16px 14px 0`, `padding: 13px 16px`, `3px solid <accent>` (accent = active
player's own color, cyan here), bg `linear-gradient(180deg, accent1a, accent05)`, `box-shadow: 0 0 16px accent40`.
Ribbon top-left: `▶ NOW THROWING` (Press Start 2P 9, accent bg, BG text).

**a) Compact header row** (flex, align center, gap 13) — LAST folded inline (the old full-width LAST row is removed, ~44px reclaimed):
- Avatar box `52×52`, BG bg, `3px solid accent`, handle text (Press Start 2P 14, accent, glow).
- Middle: name (Press Start 2P 17, white, letter-spacing 2). Below it a single row: 3 dart pips
  (9×9, filled = accent up to `dartIdx`) · `DART 2/3` (VT323 14) · `·` · `LAST` · last throw
  `T19·S20·D14` (VT323 16 yellow) · `=105` (Press Start 2P 10 yellow).
- Right: `SCORE` label (Press Start 2P 9) + big number (Press Start 2P **46**, accent, glow,
  letter-spacing -2) on one baseline; below `TO GO · <remaining>` (VT323 16 yellow, number in
  Press Start 2P 11).

**b) Climb-to-target bar** — `ClimbBar` (replaces the old LAST row; ~10px tall, informative):
- Track: `height 14`, bg `#05000e`, `2px solid accent44`, `inset 0 0 8px accent22`.
- Your fill: from 0 to `score/target%`, `linear-gradient(90deg, accent55, accent)`, glow.
  Leading edge: 3px white bar with white glow at your position.
- **Opponent ticks**: one 2px vertical tick per opponent at `total/target%`.
  - dead (total ≤ 0): `rgba(255,255,255,0.18)`, initial label.
  - killable (you are exactly 1 dart from their total): **RED**, `box-shadow 0 0 6px RED`, `💀`
    label above, pulsing (`goSkullTick`, 1s, opacity 1↔.4; disabled under reduced-motion).
  - otherwise: PHOSPHOR, initial label above.
- Labels row under track: `0` … `CLIMB TO TARGET` … `<target>` (yellow).

**c) Two helper bars** — `HelperBar` (always present so layout never jumps into the board; dim when empty). Each: left tag block (icon + label, colored bg + right border) then content, `min-height 46`, `margin-top 10`. Active: `2px solid <color>`, bg `color12`, `box-shadow 0 0 14px color40`. Empty: `2px solid rgba(255,255,255,0.14)`, `opacity 0.5`, shows the empty text.
- **CHECKOUT helper** (`CheckoutHelper`): color **GREEN**, icon 🎯, tag `CHECKOUT`. Active content: route text `T20 › D15` (Press Start 2P 13, white, green glow) + right `WIN ▶` (green). Empty text: `INGEN RUTE · > 3 DART`. Uses the new **straight-out** checkout utility (≤3 darts toward the target; null → dim).
- **KILL helper** (`KillHelper`): color **RED**, icon 💀, tag `KILL`. Active content: one chip per killable opponent — `<dart> → <NAME>` (e.g. `S17 → KARI`, `D20 → PER`), chip bg `RED22`, `1px solid RED88`, dart in Press Start 2P 10 (`#ff8fa6`), name VT323 16 white; chips wrap `gap 4px 8px`. Empty text: `INGEN INNEN 1 DART`.

### Kill-help logic (from spec §3)
- **Checkout**: `remaining = target − score`. Straight-out route in ≤ (darts left) darts; prefer
  fewest darts, then conventional big targets (T20/T19/Bull) + clean finisher. Some values are
  unreachable even ≤180 (179,178,176,175,173,172,169,166,163) → null → dim. Recompute per dart.
- **Kill**: for each living opponent `diff = opponentScore − myScore`. Show only when `diff` is a
  valid **single-dart** score: 1–20 (single), even 2–40 (double), multiples of 3 ≤60 (triple),
  25, 50. `diff ≤ 0` or > one dart → not shown. Notation = simplest form (18 → `S18`, 40 → `D20`,
  57 → `T19`, 25 → `25`, 50 → `BULL`). Recompute per dart (multi-dart kills emerge naturally).
- A killable opponent's climb-bar tick = the same "danger" flag (red 💀).

### States to implement (v1–v4 designed here)
1. **Default** — both helpers dim, opponents as neutral ticks.
2. **CHECKOUT only** — green bar active, kill bar dim.
3. **KILL only** — red bar active with chips, green bar dim, killable ticks red.
4. **CHECKOUT + KILL together** — both active (win tip conceptually first / on top).

Not designed here (reuse the app's existing routines): **bust** feedback, the **GOTCHA kill
event** overlay/flash, and the **winner** moment.

---

## Interactions & Behavior
- Home tiles → open that mode's setup screen. `soon` tiles are non-interactive (dimmed). X01 tile row → X01 setup with the chosen start score.
- Cockpit: dartboard tap = score input (reuses X01 input). MISS field = miss. UNDO = standard;
  **the undo stack must capture kill side-effects** so undoing a dart restores killed players'
  scores (undo reverts everything, unlike bust which only reverts the thrower).
- Helpers + climb ticks recompute after every dart **and on undo**.
- Animations: kill ticks pulse (1s ease, opacity 1↔0.4); respect `prefers-reduced-motion`.

## State Management
- Home: active player, leaderboard top-3, mode availability (enum + hardcoded placeholders).
- Cockpit: active player {name, handle, accent, total, dartIdx, last, lastSum}, target,
  opponents [{name, total, danger}], computed `win` (route|null) and `kills` [{dart, name}].

## Assets
No image assets. Emoji are used as mode/UI glyphs on the home + top bars (existing home already
uses emoji). Board is drawn programmatically (SVG here; the app has a Flutter `_DartboardPainter`
— reuse it, do not port the SVG). Fonts: Press Start 2P, VT323 (Google Fonts) — already in app.

## Files
- `DOSSEDART home 3x3 gotcha.html` + `home-gotcha-3x3.jsx` — home 3×3 (shell `HomeGotcha3x3Shell`, spec card included on the canvas).
- `DOSSEDART gotcha cockpit v2.html` + `gotcha-cockpit-v2.jsx` — cockpit scorecard v2 (`Cockpit`, states + spec card).
- `design-canvas.jsx` — pan/zoom canvas host used by both HTML files (design tooling only; not part of the app).
- Reference: `uploads/2026-07-07-gotcha-design.md` in the main project — full approved rules, data model, integrations, edge cases, testing.
