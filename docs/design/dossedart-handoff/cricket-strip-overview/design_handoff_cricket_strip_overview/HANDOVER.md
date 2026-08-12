# HANDOVER — Cricket / strip-family overview (mode round 3) · 2026-07-22

**From:** Claude design (DOSSEDART track)
**Responds to:** `HANDOVER-to-design-2026-07-22-cricket-strip-overview-brief.md` + grammar sheet 2026-07-21
**Artboard:** `DOSSEDART cricket strip overview round.html` (canvas: today's design 4/6 players, chosen A+, 175% zoom on the marks-variants, stress states, sibling thumbnails, fasit)
**Scope:** the shared `DossedartActiveStrip` + Cricket's marks grid. Input S/D/T tap cells, TopBar, ActionBar: approved chrome, untouched.

## Decision

**A+ with SEGMENTS** (user-picked after three iterations):
- A (score in strip + points in grid headers) beat B (slim strip — starves the siblings' score block) and C (standings footer — duplicates identity, steals 44px from the grid).
- KISS round 1: **diff plate (`▲ n VS LEAD`) dropped** — score block shows POINTS only; 👑 in the grid header carries the leader.
- KISS round 2: active player's own marks integrated **inside the existing tap cells** (a separate marks column was rejected — geometry that comes/goes with turn change; a background FILL was rejected — 0/1/2 too similar). **SEGMENTS won:** three-part meter at the bottom of the active cell, one filled glowing segment per mark, empty slots as dark outlined tracks. At 3 marks the ⊗ overlay takes over. CLOSES hint dropped (implied by the meter).

## Fasit

```
FAMILY STRIP: h=132 px @ 820×1180 — identical in Cricket · ATC · Shanghai · Splitscore
```

- **Strip zone:** card 110px fixed + margins 14/12/14/10. Never grows (rule 2): LAST TURN always rendered, dimmed 0.34 with placeholder on first dart.
- **Strip anatomy (one component):** `[Header rule 4]` 56px photo avatar + name curve 18/15/12/10 + 9px pips + `DART n/3` · `[MODE SLOT]` mode's data · `[SCORE BLOCK]` number PS-30 in player accent (+ diff plate only where a mode needs one — Cricket does not).
- **Card frame (rule 5):** surface `#1A0030` · 3px border in player accent (5-accent cycle, rule 7) · 14px glow. Today's gradient + `▶` prefix dropped.
- **Cricket slots:** MODE SLOT = `LAST TURN  T18 · 18 · ✗  = 4 MARKS` (P3, yellow VT-26) · SCORE BLOCK = `POINTS` PS-30. PS-30, not 60: the grid is the card's primary element (rule 6).
- **Marks grid:** chrome frame (magenta hairlines) — the strip is the card, the grid is the standings. Header cell: 26px avatar + handle + points **PS-17 w/ glow** in player accent, 👑 on unique points leader. Opponent marks as `/ X ⊗` glyphs in player accent. Active column 2.6fr: accent bg + 3px top line, S/D/T tap cells (approved input, unchanged) with the **3-segment marks meter** at the cell bottom.
- **Grid states:** closed-by-all → row dim 0.3 + `DEAD` tag under the target. Closed for active → cells lock, big ⊗ in accent. First dart → LAST TURN dimmed, no 👑. Always 7 rows — the grid never changes height (rule 2).
- **Long names:** strip name curve bottoms at 10px >16 chars (tested 24 chars); grid headers use the 3-char handle — immune. 6 players: opponent columns ~103px, 20px glyphs.
- **Not shown, by decision:** cumulative dart count, MPR/stats (post-game/player sheet), any diff-vs-leader element.

## Sibling inheritance (proven on thumbnails)

Same component, same 132px — only slot contents swap:
- **ATC:** MODE SLOT = `TARGET 7` + `THEN 8 › 9 › 10` · SCORE = `PROGRESS 6/21` + behind plate.
- **Shanghai:** MODE SLOT = `ROUND 4 · TARGET 4` + `S4 · D8 · T12` · SCORE = `POINTS` + diff plate.
- **Splitscore:** MODE SLOT = `TARGET D19` + red `MISS HALVES 240 › 120` · SCORE = `POINTS`.
Sibling plates/sub-lines are illustrative — each inherits the restyled strip without its own round per the brief; exact copy is implementation's call against real data.

## Implementation owns

All rules/scoring · `DossedartActiveStrip` + Cricket grid rewrite · leader math (flips in Cutthroat: lowest leads) · fixed-height regression tests pinning 132px in all four strip modes.

## Constraints honored

820×1180 · TopBar/ActionBar/input cells untouched (approved chrome) · tokens only · player accents from the 5-accent cycle (rule 7) · Press Start 2P / VT323 · no border-radius · English UI strings.

## Files

| File | Purpose |
|---|---|
| `DOSSEDART cricket strip overview round.html` | The round canvas (today → chosen A+ → zoom variants → stress → siblings → fasit) |
| `cricket-strip-overview-round.jsx` | React source for all artboards incl. the fasit spec card |
| `design-canvas.jsx` | Canvas/artboard helper |
