# Golf cockpit v2 — dev handoff bundle

Self-contained bundle for building the v2 Golf cockpit on `feat/golf`. The HTML/JSX are the **visual
fasit** (a React/Babel prototype — reference, not production code). `golf-design.md` is the **behaviour
fasit**; if an artboard implies different behaviour, the spec wins. `HANDOVER.md` is the design note.

## What's in here
- `DOSSEDART golf cockpit v2.html` — entry point; open in a browser to see the artboards.
- `golf-cockpit-v2.jsx` — all v2 cockpit components + states + the full scorecard sheet + spec card.
- `design-canvas.jsx` — pan/zoom artboard shell (presentation only; **not** app UI).
- `golf-design.md` — Golf rules (behaviour fasit).
- `HANDOVER.md` — the v2 design → implementation note (read this first).

## The scope of v2
Pure **cockpit-layout** round on the Galaxy Tab QA feedback. **No rule/state/flow changes.** Home,
setup, post-game and the scorecard sheet are approved as built and reused; only the in-game cockpit
layout is new.

## The one rule that drives the layout
**Only the three S/D/T cells register score — everything else informs.** Scoring gets exactly one
treatment (the glowing, bordered `▼ TAP TO SCORE` console, pinned bottom above the ActionBar); every
other surface is a flat, glow-free readout. Preserve that split.

## Cockpit stack (top → bottom)
TopBar · Hero target (giant hole number = aim signal) · Leaderboard (full-width) · windowed Scorecard
strip · **[spacer]** · Input console (bottom, over UNDO·MISS·MENU) · ActionBar (3 actions, **no LOCK IN**).

## States
tee-off · mid-hole (`LYING n — m DARTS LEFT`) · hole-result (1s, finishing player) · between-holes ·
sudden-death (red overlay) · playoff (`BULL` = two cells). Winner = **post-game only**.

## Build order (per golf-design.md §10)
Own screen on the Shanghai round template. Reuse the shipped cockpit chrome, ATC S/D/T input, standings,
and the scorecard sheet widget. New widgets: hero/active card, the windowed strip. Tokens only; brand =
existing `green #3DFF8E`; `Press Start 2P` / `VT323`; no border-radius; English strings (guard test).

## Two open calls (in HANDOVER.md)
1. Windowed strip vs. sheet-only.
2. `miss = DOUBLE BOGEY` label (trivial flip back to `BOGEY` if preferred).

## Running the prototype
Open `DOSSEDART golf cockpit v2.html` directly — it loads React + Babel from a CDN and the two JSX
files next to it. No build step.
