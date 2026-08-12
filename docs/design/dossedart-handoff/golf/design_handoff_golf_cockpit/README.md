# Handoff: Golf cockpit + screens

## Overview
Golf plays the dartboard as a golf course: the numbers **1–18 are holes played in order**, and you want
the **lowest** stroke total. Each hole is press-your-luck — the **last dart thrown counts**, so after a
decent hit you either **LOCK IN** your strokes or risk another dart for better. This handoff covers the
**home tile, setup, in-game cockpit (states 1–7), the full scorecard sheet, and post-game (state 8 ·
winner)**.

The cockpit **skeleton is reused verbatim** from the shipped X01/ATC cockpit — Frame + scanlines,
TopBar, ActionBar chrome, leaderboard/standings pattern — and the **input is ATC's S/D/T target-zone
input** (three cells on the hole's number, not the full dartboard). **New design effort lives in the
hole context + LYING line, the LOCK IN button, the scorecard, the course selector, and the new states.**

## About the design files
The files in this bundle are **design references created in HTML/React (JSX via in-browser Babel)** —
prototypes showing intended look and behaviour, **not production code to copy directly**. The task is
to **recreate these artboards inside the DOSSEDART app** (Flutter — see `golf-design.md` §5) using its
established widgets, tokens and patterns. The HTML is the visual fasit; the `.md` specs are the **rule
fasit** (behaviour authority). If an artboard implies behaviour different from the spec, **the spec
wins.** New feature ideas are marked **PROPOSAL** in a spec card and are parked by default.

> Terminology is locked: **LOCK IN** (not "bank"), **HOLE**, **PAR**, **LYING n**, **ACE / BIRDIE /
> PAR / BOGEY**, **SUDDEN DEATH**. All UI strings are **English** (a guard test fails the build on
> Norwegian strings).

## Fidelity
**High-fidelity.** The cockpit chrome, S/D/T input, standings, player-setup chrome, home-tile chrome
and post-game podium/stat-row pattern are **existing, QA'd components** — reuse as-is. Recreate the
**new elements** (active card + LYING, LOCK IN button, scorecard strip/sheet, course chips, stat rows)
pixel-faithfully.

---

## Rules that drive the UI (spec §2–§3)
- **Course:** 18 holes = numbers 1–18 in order (setup option: 9 holes = 1–9, default 18). Round-based
  like Shanghai: everyone completes hole N before anyone starts N+1.
- **Per hole:** up to **3 darts** at the hole's number; only hits on that number count.
- **Stroke values (fasit):** Triple = **1** (ACE) · Double = **2** (BIRDIE) · Single = **3** (PAR) ·
  **Miss = 5** (BOGEY). Par is 3.
- **Last dart counts:** your stroke = whatever the **last thrown dart** scored (including a miss). After
  dart 1 or 2 you may **LOCK IN** to keep the current stroke and end the hole; after dart 3 the hole
  ends automatically. At least one dart per hole (no locking in at 0 darts).
- **Win:** lowest total after the final hole. **Tie for 1st → sudden death** on 19 → 20 → Bull
  (cycling); lowest stroke on the playoff hole wins. Sudden death resolves **only 1st place**; lower
  ties share the placement.

---

## Screen: home (3×3 mode grid)
Full-screen dark arcade (`GFHome`). 3-column grid of mode tiles; tile chrome is reused, only the grid
goes 2→3 columns. The **Golf tile is lit** (shipped variant): green border + glow + `NEW` badge, ⛳.
**WILDCARD** shows the dimmed **coming-soon** treatment (opacity 0.5, greyscale emoji, `SOON`) since it
builds last.

## Screen: setup (Golf options)
`GFSetup` — reuses `PlayerSetupScreen` (player list + remove) and adds Golf's one new control in the
existing chip pattern:
- **COURSE** chips `9 HOLES` (front nine · 1–9) / `18 HOLES` (full round · 1–18), default **18**.
- A one-line rules summary strip and a `▶ TEE OFF` START CTA (green→cyan gradient).
- Add/remove players mid-game: an added player joins at the current hole with every earlier hole
  recorded as par (3); a removed player's card is kept for the result screen.

## Screen: Golf in-game cockpit
**Frame:** 820 × 1180 px, portrait tablet. Vertical stack: TopBar (`◀ EXIT` · `⛳ GOLF` · `HOLE n/18`) ·
**active card** · **leaderboard** · **S/D/T input** · **scorecard strip** · ActionBar.

### ActionBar (`GFActionBar`) — the LOCK IN button (a FOURTH action, only in Golf)
`↶ UNDO` · `✗ MISS` · **`🔒 LOCK IN`** · `⋯ MENU`. LOCK IN is **disabled** (dim, no fill) before the
first dart; **enabled** (green fill + glow) after dart 1 and 2; irrelevant after dart 3 (hole
auto-ends). It is the widest action to read as the signature interaction.

### Active card (`GFActiveCard`) — the primary design surface
`border: 3px solid <frame>`, gradient fill, glow. `<frame>` = player colour while throwing, **GREEN**
when locked at ≤ par, **RED** on a bogey. `▶ NOW THROWING` tab top-left.
- **Header:** avatar (player colour) · name · `HOLE n · PAR 3` · dart pips (fill to darts thrown) ·
  big **STROKES** total + `vs par` on the right.
- **LYING line** (the press-your-luck heartbeat): before any dart → `TEE OFF — THROW AT THE n · LAST
  DART COUNTS`. After a dart → `LYING <n>` + golf label, then the state tail:
  `mid` → `LOCK IN OR RISK?` · `locked` → `🔒 LOCKED IN` · `bogey` → `HOLE OVER · MISS`.

### Input (`GFInput`) — ATC S/D/T target-zone
Three cells on the hole's number: `S<n>` = PAR (3) · `D<n>` = BIRDIE (2) · `T<n>` = ACE (1), coloured
by stroke term; caption reminds `MISS = BOGEY (5 STROKES)`. In sudden death the target reads `BULL`.

### Scorecard
- **Strip** (`GFScorecardStrip`) — inline, all holes, current highlighted (yellow), played holes
  coloured by term; `▸ TAP TO EXPAND`.
- **Full sheet** (`GFScoreSheet`) — holes × players grid, par row, totals, term colouring + legend.
  Two artboards: mid-game (hole 7) and a finished round. Reachable from the strip and from post-game.

### Moment overlays
`GFOverlay` — **ACE** (`✦✦✦ ACE!`, cyan, `gfPop`) and **SUDDEN DEATH** (`⛳ SUDDEN DEATH`, red). Both are
**tap-to-dismiss AND 1s auto-dismiss** (1UP QA convention — play never stalls behind an overlay).

### The 8 states (spec §4.3)
1. **Hole start** — no darts, LOCK IN disabled, `TEE OFF`.
2. **Mid-hole decision** — `LYING n` shown, LOCK IN enabled — the signature `LOCK IN OR RISK?` moment.
3. **ACE** — triple = 1 stroke → ACE! overlay.
4. **Locked in** — stroke kept, hole done, green frame + `🔒 LOCKED IN`.
5. **Bogey** — hole ends on a miss → 5 strokes, red frame, `HOLE OVER · MISS`.
6. **Between holes** — everyone done with hole N → next tee, updated leaderboard.
7. **Sudden death** — tie for 1st → playoff on 19/20/Bull, leaders only.
8. **Winner = POST-GAME.** There is **no in-cockpit winner overlay** (1UP QA lesson 2026-07-16) — the
   post-game screen is the sole winner surface.

## Screen: post-game (state 8 · winner)
`GFPostGame` — reuses `post_game_screen`. Winner banner (`<name> WINS · CLUBHOUSE LEADER · n STROKES ·
vs par`) + **placements by total strokes ascending** (lowest wins, podium metals; sudden death decides
1st on ties, lower ties share). **Mode-specific stat rows:** total strokes, vs par, aces, bogeys,
lock-ins, best hole. Link to the **full scorecard**. UNDO must work (Shanghai post-game undo protocol).
Values shown are illustrative fixtures.

---

## Brand accent (no new token)
Golf's brand is the **existing `green` token `#3DFF8E`** (brief §4 Golf accent) — ⛳ fits, and green is
the shared safe/positive colour, not another mode's brand. **No palette proposal needed.** Green is used
for the TopBar title, home-tile NEW glow, setup labels + TEE OFF CTA, and the LOCK IN / locked states.
Stroke terms keep their own semantics: cyan = ACE, green = BIRDIE, phosphor = PAR, orange/red = BOGEY.

## State management (spec §5)
- `GameMode.golf`, `GolfConfig extends GameConfig { final int holes; }` (9 or 18). Own screen on the
  Shanghai template (round structure).
- State per player: scorecard (stroke per hole), current hole, darts thrown in hole, locked-in flag.
  Undo entries cover darts, lock-ins, and hole/round transitions so undo can cross hole boundaries.

## Design tokens
- Player accents (`player_colors`): CYAN `#00E5FF`, MAGENTA `#FF00AA`, GREEN `#3DFF8E`, YELLOW `#FFD200`.
- Semantic: GREEN (Golf brand / LOCK IN / ≤par), CYAN (ACE), PHOSPHOR `#D9D2C2` (PAR), ORANGE `#FF7A00`
  (double-bogey / MISS / CTA), RED `#FF3050` (BOGEY / danger), YELLOW (highlight / winner / metals),
  MAGENTA (chrome).
- Surfaces: BG `#0a0014`, SURFACE `#1a0030`. Podium: silver `#C9D2DA`, bronze `#D08A4A`.
- Type: `"Press Start 2P"` (headings/numbers/labels), `"VT323"` (secondary/mono). No border-radius.

## Assets
No raster assets — chrome/board drawn (CSS). Emoji glyphs: ⛳ 🔒 ✦ ★ ✗ 🎯 🦗 🏙️ 💀 🕹️ ✂️ 🕐 🃏.
Sounds `assets/sounds/golf/` (ACE/BIRDIE/PAR/BOGEY, locked in, sudden death, winner) with TTS fallback
(spec §6) — implementation-owned.

## Files in this bundle
- `DOSSEDART golf cockpit.html` — entry point; loads React + Babel + the two JSX files.
- `golf-cockpit.jsx` — all cockpit / active-card / LOCK-IN / scorecard / overlay components, states
  1–7, the full scorecard sheet, the home / setup / post-game screens, and the spec fasit card.
- `design-canvas.jsx` — pan/zoom artboard shell (presentation only; not app UI).
- `new-modes-design-brief.md` — design/implementation split (read first).
- `golf-design.md` — the Golf rule spec (behaviour fasit).

Start at the fasit card rendered in the HTML (`Spec · Golf`) and `golf-cockpit.jsx`'s `GFActiveCard`,
`GFActionBar`, `GFInput`, `GFScorecardStrip` / `GFScoreSheet`, `GFSetup`, `GFHome`, `GFPostGame`.
