# New Game Modes — Design Brief (for Claude design)

**Date:** 2026-07-07
**Applies to:** the four mode specs dated 2026-07-07 — Gotcha, 1UP, Golf, WILDCARD — plus the home screen 3×3 grid.

This brief defines the split between **design** (you) and **implementation** (Claude Code). Read it before the specs. The core message: **most of the UI already exists** — these modes are assembled from built, QA'd DOSSEDART components. Design the NEW elements and states; do not redesign what already ships.

---

## 1. Division of labor

**Design owns (this is the deliverable):**
- Artboards for the numbered states in each spec's "Screens & states" section — one artboard per state.
- The genuinely new visual elements (per-mode list in §3 below).
- The home screen 3×3 grid: proportions for 3-column tiles + the dimmed "coming soon" tile treatment.
- Motion/transition intent for the signature moments (kill event, life lost, joker reveal, REWIND) — described in spec cards; implementation animates.

**Implementation owns (do NOT design or spec this):**
- All rules, scoring, tips computation, chaos randomness, engines, undo, stats/Elo, sounds/TTS, tests.
- The **spec .md files are the rule authority.** If an artboard implies different behavior than the spec (extra buttons, different flow, new mechanics), the spec wins and the artboard element is dropped.
- New feature ideas are welcome but must be marked **PROPOSAL** in the spec card — they are parked by default, never silently woven into the fasit (same protocol as the arcade-redesign handoff: reskin is fasit, new functionality is parked).

## 2. Reuse these existing components as-is (do not reinvent)

All four modes are built on the DOSSEDART arcade system. The following exist, are QA'd on tablet, and carry over unchanged unless a spec explicitly says otherwise:

- **Cockpit skeleton** (from the X01 in-game screen): TopBar (EXIT · centered title · round info), **player carousel** (active card ~86% width + peek cards + indicator pills), **ActionBar** (UNDO / MISS / MENU). New modes change the *content* of the active card, not the skeleton.
- **DOSSEDART dartboard** (X01 cockpit board) — reused by Gotcha and WILDCARD. WILDCARD adds only **dim states on segments** (design the dimmed look; the board itself is done).
- **Number-target input with S/D/T zones** (ATC/Splitscore style) — reused by Golf.
- **Checkout-tip strip** (green dashed, from X01) — Gotcha restyles its *content* (win tip + kill tips), not the strip pattern.
- **Player setup screen** — chrome, player list, chip-styled toggles all exist. Each mode only adds its own option chips (target score, lives, holes, rounds/chaos).
- **Post-game screen** — podium, placements, stat-row pattern exist. Modes only add stat-row content.
- **Home screen** — X01 row (301/501/701) and mode-tile chrome exist. Only the grid goes 2 → 3 columns; tiles keep their chrome.
- **Avatars/silhouettes, player colors** (`player_colors` palette), **arcade frame/CRT effects**, fonts.

## 3. What is genuinely NEW per mode (design effort goes here)

**Home:** 3-column tile proportions; dimmed disabled "coming soon" tile variant (1UP, Golf, WILDCARD until they ship); tile emoji/branding for the four modes.

**Gotcha:** score-counting-UP active card (`total` big + `TO GO`), kill-tip content in the tip strip (`💀 T19 → KARI`), skull/danger marker on threatened peek cards, the **kill event** moment ("GOTCHA!", score dropping to 0), win+kill tips shown together.

**1UP:** `BEAT <target>` as primary number + `NEED n MORE`, **life pips** on all player cards, SAFE and CAN'T-BEAT states, free-opening-throw state (`SET THE TARGET`), **life lost** moment, last-life persistent danger styling.

**Golf:** hole context (`HOLE 7 · PAR 3` + `LYING n`), the **LOCK IN** button in the ActionBar (new interaction — only mode with a fourth action), **scorecard** (hole-by-hole grid, inline/sheet — design decides), ACE celebration, sudden-death state.

**WILDCARD:** the **chaos meter** (0–10, always visible, the mode's centerpiece — idle/rising/max looks), **modifier announcement** pre-turn overlay, modifier badge + dimmed-board states, THE WINDOW display (`WINDOW: 3–9 · ALL DARTS MUST SCORE`), **bull choice dialog** (chaos ±1/±3), **joker reveal** moment, CUT! and REWIND treatments, instant-event feedback (swap/steal/freeze).

## 4. Format & constraints

- Deliverable: **HTML artboards with spec cards**, same convention as previous DOSSEDART handoffs — spec cards are fasit.
- Target: **tablet** (Samsung Galaxy Tab class), dark arcade theme.
- Colors: **DOSSEDART tokens only** (the arcade track palette) — no new hex values, no Material colorScheme roles.
- All UI strings **English** (a guard test fails the build on Norwegian strings).
- Terminology is locked in the specs: LOCK IN (not "bank"), 1UP (not "Legs"), HOLY TRINITY (exactly 26), WINDOW PRIZE, CHAOS METER.
