# Handoff: WILDCARD cockpit — scorecard revision

## Overview
WILDCARD is DOSSEDART's chaos game mode: a points race sabotaged by random events, driven by a
visible **CHAOS METER (0–10)**. This handoff covers the **in-game cockpit** and — specifically —
the **revised scorecard** that now prioritises *what the active player must throw this turn* over
the other players' running scores.

The dartboard is deliberately **untouched** (full 760 px, identical to X01/Gotcha). All new and
changed UI lives in the scorecard block above the board.

## About the design files
The files in this bundle are **design references created in HTML/React (JSX via in-browser Babel)** —
prototypes showing intended look and behaviour, **not production code to copy directly**. The task is
to **recreate these artboards inside the DOSSEDART app** (Flutter — see `wildcard-design.md` §8) using
its established widgets, tokens and patterns. The HTML is the visual fasit; the two `.md` specs are
the **rule fasit** (behaviour authority).

> Terminology is locked by the spec: **CHAOS METER, THE WINDOW, WINDOW PRIZE, HOLY TRINITY, joker,
> CUT!, REWIND, LOCK IN**. All UI strings are **English** (a guard test fails the build on Norwegian
> strings).

## Fidelity
**High-fidelity.** Final colours, typography, spacing and layout. The cockpit chrome (Frame +
scanlines, TopBar, ActionBar) and the CRT dartboard are **existing, QA'd components** — reuse as-is.
Recreate the **scorecard** pixel-faithfully; everything else carries over from the shipped X01 cockpit.

---

## What changed in this revision (the point of the handoff)

The scorecard was re-ordered around a single priority: **the active player's throwing objective is the
dominant element**, the other players' scores are secondary.

Top-to-bottom the scorecard now reads:

1. **Active-player detail** — avatar, name, **per-dart breakdown**, TURN total, GAME total + rank/to-lead.
2. **THIS TURN directive band** — the *dominant* element. States exactly what this player must throw
   (restriction / THE WINDOW / open throw). Big icon + bold headline + sub-line.
3. **Standings strip** — *demoted* to a compact, dimmed single-line-per-player row (👑 leader / ▽ last).

Rationale: the chaos events target "leader"/"last place", so standings must stay visible — but a
player mid-turn cares first about their own restriction. The frame was grown from 820×1180 → **820×1300**
(~16:10 tablet) purely to give the scorecard room; **the board stays 760 px**.

---

## Screen: WILDCARD in-game cockpit

**Frame:** 820 × 1300 px, portrait tablet (Samsung Galaxy Tab class).
Background `#0a0014`. CRT scanline overlay + radial vignette. When chaos ≥ 9 a red danger vignette pulses.
Global font `"Press Start 2P"` (headings/labels) with `"VT323"` for secondary/mono text.

Vertical stack (flex column):

| Band | Height (approx) | Notes |
|---|---|---|
| TopBar | ~48 px | `◀ EXIT` (cyan) · centred `🃏 WILDCARD` (yellow) · `ROUND n/10` (right). Black, 2px magenta bottom border. |
| CHAOS METER | ~92 px | Existing centerpiece — unchanged this revision (see below). |
| **Scorecard** | ~250 px | **The revised block.** See breakdown below. |
| Board zone | flex fill (~840 px) | 760 px CRT dartboard, centred. Untouched. Dim states on segments during restrictions. |
| ActionBar | ~70 px | `↶ UNDO` / `✗ MISS` (orange, primary) / `⋯ MENU`. Black, 2px yellow top border. |

### Scorecard — component breakdown

Outer container: `margin: 12px 16px 0`, `padding: 13px 16px 14px`, `border: 3px solid <themed>`,
`background: linear-gradient(180deg, <themed>16 0%, <themed>05 100%)`, `box-shadow: 0 0 18px <themed>45`.
`<themed>` = `PURPLE #B15CFF` when a modifier/window is active, else the active player's colour.
Tab label (top-left, overlapping border): `▶ SCORECARD · R<round>/<rounds>`, 9px Press Start, bg `<themed>`, text `#0a0014`.

**1. Active-player detail row** (flex, `gap:13`, align center):
- **Avatar**: 46×46, bg `#0a0014`, 3px solid player colour, glow `0 0 12px <c>55`. 3-letter handle (JON/KAR/PER), 12px Press Start in player colour.
- **Name + darts** (flex:1): name 15px Press Start `#fff` letter-spacing 2; below it the **per-dart breakdown**.
- **TURN** (right): label 9px Press Start `rgba(255,255,255,0.5)`; value 30px Press Start player colour, glow.
- **GAME** (right, `border-left:2px solid rgba(255,255,255,0.12)`, `padding-left:14`): label 9px yellow; value 32px Press Start `#fff` (yellow glow); below, 14px VT323 `#rank · <-n TO LEAD | LEADER>`.

**Per-dart breakdown** (`DartSlots`): three boxes, each `min-width:44 height:32`.
- Thrown dart: 2px solid player colour, bg `<c>1e`, glow `0 0 8px <c>55`, value (e.g. `T19`, `20`, `DBL`) 19px VT323 `#fff`.
- Miss (`—`): 2px solid `rgba(255,255,255,0.28)`, no fill, value `rgba(255,255,255,0.45)`.
- Current (next to throw): 2px solid player colour, glow `0 0 10px <c>66`, `▸` glyph, pulses (`wcSegPulse 0.9s infinite`).
- Empty: 2px dashed `rgba(255,255,255,0.16)`, `·` glyph.
- Trailing counter: `DART n/3`, 14px VT323 `rgba(255,255,255,0.5)`.

**2. THIS TURN directive band** (`ThrowDirective`) — **dominant element**:
- `margin-top:13`, `padding:14px 16px`, `border: 3px solid <d.color>`,
  `background: linear-gradient(180deg, <d.color>26 0%, <d.color>0b 100%)`,
  `box-shadow: 0 0 20px <d.color>66, inset 0 0 22px <d.color>18`.
- Tab label (top-left): `THIS TURN`, 8px Press Start, bg `<d.color>`, text `#0a0014`.
- Row (flex, `gap:14`): icon 34px; then headline 18px Press Start `#fff` (double glow in `<d.color>`) + sub-line 19px VT323 `rgba(255,255,255,0.78)`.
- Directive content (`wcDirective(player, mod, window)`):
  - **Window active** → color PURPLE, icon `🎯`, head `LAND TOTAL <lo>–<hi>`, sub `ALL 3 DARTS MUST SCORE · INSIDE → +100 PRIZE`.
  - **Modifier active** → color PURPLE, icon = modifier icon, head = modifier name, sub = modifier description.
  - **No restriction** → color = player colour, icon `▶`, head `OPEN THROW · SCORE MAX`, sub `No restriction this turn — pile on points`.

**3. Standings strip** (`Standings`) — **demoted / secondary**:
- Caption row: `STANDINGS` 7px Press Start `rgba(255,255,255,0.35)` + 1px hairline divider.
- Players sorted by total desc; one compact cell each (flex, `gap:8`), cell `padding:6px 9px`, `border:1px solid`.
  Active player: border = player colour, bg `<c>12`, full opacity. Others: border `rgba(255,255,255,0.12)`, opacity 0.72.
- Cell contents (single line): rank digit (8px Press Start; yellow if leader) · 7×7 colour dot · name (8px Press Start) ·
  total (right-aligned, 20px VT323 player colour, glow) · then either an **event flag tag** (7px Press Start, green/red bordered — e.g. `+50 STEAL`, `−50 ROBBED`) **or** `👑` (leader) / `▽` (last place).

### CHAOS METER (unchanged — reference)
`margin:12px 16px 0`, border/glow in the level's heat colour. Left: `CHAOS` label + big level number `n` (42px) `/10`.
Right: **10 heat segments** (filled up to level, lead segment brighter) + level word (`DORMANT/MILD/BUBBLING/SPICY/WILD/TOTAL CHAOS`)
+ event-chance readout. At 9–10: danger pulse (`wcMaxPulse`), plus the frame-level red vignette.
Heat colour by level: 1–2 CYAN · 3–4 GREEN · 5–6 YELLOW · 7–8 ORANGE · 9–10 RED.

---

## The 11 cockpit states (design artboards)
Each is a variant of the same cockpit; the difference is scorecard content + any centred dialog overlay.

1. **Default** — no modifier, meter idle. THIS TURN = `OPEN THROW · SCORE MAX`.
2. **Modifier announcement** — pre-turn dialog overlay (purple), modifier name + `<player>'S TURN ONLY`.
3. **Active restriction** — modifier badge in THIS TURN + **dimmed board** (non-scoring segments darkened).
4. **THE WINDOW** — THIS TURN shows `LAND TOTAL <lo>–<hi>` + all-darts-must-score.
5. **Bull choice** — centred dialog: ±1 (single bull) / ±3 (double bull); IGNITE (red, +) vs CALM (cyan, −).
6. **Joker reveal** — signature dialog (green `🃏`): hidden number detonates, `METER +2` + `INSTANT EVENT ▶`.
7. **Instant event** — dialog (orange) resolving swap/steal/freeze; ROBIN HOOD shown, with steal/robbed flags in standings.
8. **CUT!** — dialog (red `✂️`): round ends now, players yet to throw lose their turn.
9. **REWIND** — dialog (cyan `⟲`, spinning): round scores wiped, restart from first player.
10. **Meter at max (9–10)** — persistent red danger styling (frame vignette pulse + meter danger).
11. **Winner** — dialog (yellow ★★★): highest total after final round.

Overlays are centred popups over a blurred dark scrim (`WCOverlay` / `WCDialog` / `BullDialog`).

---

## Interactions & behaviour
- **Manual entry** — a turn is 3 darts entered after throwing; the per-dart boxes fill left→right, current box pulses.
- **Board is always tappable** — a dart on a dimmed segment scores 0 but is fully alive (jokers / cursed numbers / bull dialog still trigger; it is **not** a meter-miss).
- **Chaos meter animates** as it moves (segments light up; lead segment pulses at max).
- **REWIND** deserves a real animation (spinning glyph shown; scores struck through).
- **Reduced motion**: all `wc*` animations disabled under `prefers-reduced-motion: reduce`.
- Rules, scoring, event randomness, undo, TTS, stats are **implementation-owned** — see `wildcard-design.md` §2, §8–§11. The artboards never override the spec.

## State management (per spec §8)
- `WildcardConfig extends GameConfig { int rounds; int startingChaos; }`.
- Pure `WildcardGameEngine` with **injected seeded RNG**; UI renders engine state. Meter changes, swaps, CUT!, REWIND are event-sourced entries on the undo stack (undo restores meter, re-hides jokers, restores swapped/rewound scores).
- Cockpit reads: current round/total rounds, chaos level, roster with per-player totals + active flag + optional event flag, active player's turn total + per-dart values, active modifier / window bounds, and the current overlay/dialog (if any).

## Design tokens
Colours (exact hex):
- Player / accent: CYAN `#00E5FF`, MAGENTA `#FF00AA`, GREEN `#3DFF8E`.
- Semantic: PURPLE `#B15CFF` (chaos / modifier / directive), YELLOW `#FFD200` (bull + labels + leader), ORANGE `#FF7A00` (MISS + events), RED `#FF3050` (danger / CUT! / max).
- Surfaces: BG `#0a0014`, SURFACE `#1a0030`, PHOSPHOR `#D9D2C2`.
- Use the DOSSEDART `player_colors` palette for real player accents — the three above are placeholders.

Typography: `"Press Start 2P"` (headings, numbers, labels), `"VT323"` (secondary/mono readouts).
Sizes used in the scorecard: 32 (GAME) · 30 (TURN) · 23→20 (standings totals) · 18 (directive head) · 19 (per-dart / directive sub) · 15 (name) · 8–10 (labels).

Spacing: outer scorecard margin `16` horizontal; internal gaps `8–14`; band `margin-top` `12–13`.
Borders: 3px on scorecard + directive; 1–2px on standings cells / dart boxes. No border-radius (square arcade aesthetic).

## Assets
No raster assets. Board and chrome are drawn (SVG / CSS). Emoji glyphs used as icons: 🃏 🎯 🏹 ✂️ ⟲ ★ 👑 ▽ ▸.
Sounds: `assets/sounds/wildcard/` with TTS fallback (spec §9) — implementation-owned.

## Files in this bundle
- `DOSSEDART wildcard cockpit.html` — entry point; loads React + Babel + the two JSX files, renders the DesignCanvas.
- `wildcard-cockpit.jsx` — all cockpit + scorecard + overlay components, the 11 state fixtures, and the fasit spec card.
- `design-canvas.jsx` — the pan/zoom artboard shell used to present the states (presentation only; not part of the app UI).
- `new-modes-design-brief.md` — the design/implementation split (read first).
- `wildcard-design.md` — the WILDCARD rule spec (behaviour fasit).

Start at the **spec card** rendered in the HTML (`WILDCARD — fasit`) and `wildcard-cockpit.jsx`'s
`WCScoreCard`, `ThrowDirective`, `DartSlots` and `Standings` components for the revised scorecard.
