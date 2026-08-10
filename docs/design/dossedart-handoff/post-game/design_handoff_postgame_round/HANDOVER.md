# HANDOVER — Post-game screen · 2026-08-10

**From:** Claude design (DOSSEDART track)
**Responds to:** `HANDOVER-to-design-2026-08-10-post-game-brief.md` + grammar sheet 2026-07-22
**Artboard:** `DOSSEDART postgame round.html` (today → the design + zone budget → three loads → five stress states → two fasit cards)
**Scope:** `PostGameScreen` only. Stats menu and KAMPDETALJER untouched.

## Decisions (user-picked before drawing)

Spotlight winner, not a podium · **fixed label/value grid** for the per-player statistics · all placements the same size, compact · conditional fields at zero **dim in place with “—”** · **match summary at the bottom**, under standings and chart.

## Fasit — zones @ 820 × 1180

```
TOPBAR 52  ·  WINNER 196  ·  SCROLL 798  ·  ACTIONS 134     (pinned / pinned / flex / pinned)
```

Only the middle region scrolls. The action bar is a sibling of the scroll view, not its last item — it can never be pushed off. Today the chart is a list item and the buttons float above it.

- **Winner spotlight (196 px, horizontal):** 104 px avatar, yellow 3 px border + 18 px glow, 👑 overhanging the top edge · `★ WINNER ★` PS-11 · name PS 26/21/17/13 by length · headline repeated VT-19 · two right-hand plates (mode headline in yellow, ELO in green, or dimmed “—” for unrated modes). Radial yellow wash, no gradient card, no trophy emoji.
- **Standings:** one card per player, identical height within a mode. Surface `#1A0030`, 2 px border in the player accent (5-accent cycle), yellow border + glow on 1st. Header 40 px: rank plate (gold / silver `#C0C0C0` / bronze) · 40 px photo avatar · name PS 14/12/10/9 · `YOU` tag · headline label VT-15 · **headline value PS-20 in the player accent** · Elo column fixed 86 px.
- **Stat grid — the wall-of-text fix:** 3 fixed columns, cell 34 px, gap 6, label VT-15 left / value PS-10 right. Rows = `ceil(fields / 3)`.
  - **Ordering rule:** the mode’s headline never enters the grid — it sits in the row header. The rest fill left→right, top→bottom in the order §4 of the brief declares them; a new wave-2 counter is appended to its mode’s list and lands in the next free slot. No per-mode tuning.
  - **Trailing slots** in a partial last row render as empty dim tracks, so every mode is a clean rectangle.
  - **Conditional fields at zero** (Elims, Stolen, Rounds won, Shanghai!) are rendered, dimmed 0.34, value “—”. Geometry is identical between two games of the same mode (grammar rule 2).
- **Card height:** 3–4 fields → 106 px · 5–7 → 146 px · 8 → 186 px.
- **Match summary (new zone, bottom):** 3 × 2 cells — DURATION · ROUNDS · DARTS THROWN · BEST TURN (+ who / which round as a sub-line) · HIT DISTRIBUTION `T · D · B · ✗` · BIGGEST LEAD. Values in **lime**, which is reserved here and for the primary action so game-level numbers read as a different class than the per-player accents. **Degraded:** duration renders normally, the other five dim to “—”, BEST TURN carries `NOT RECORDED`, the zone keeps its size, section label gains “· partly unavailable”. Same rule for BIGGEST LEAD in 1UP and Killer.
- **Actions (134 px, two rows):** `↶ BACK` · `▶ CONTINUE` · `▶ DETAILS` on row 1, `✓ FINISH GAME` full-width lime on row 2. Today’s three stacked rows become two. Conditional buttons are rendered and dimmed 0.28, never removed, so the primary action never moves.

## Measured loads

| Case | Scroll content | Scroll needed (region 798) |
|---|---|---|
| Splitscore × 3 (light, 3 fields) | 772 px | none — fills without padding |
| X01 × 3 (typical, 7 fields) | 904 px | 106 px |
| Golf × 3 + scorecard (heavy) | 1063 px | 265 px |
| X01 × 6 (worst) | 1390 px | 592 px |

## Stress states — resolved

6 players scroll only the middle region · name curve bottoms at 9 px in standings and 13 px in the spotlight, both ellipsis at 24 chars · tie = shared placement number, shared medal colour, VT-15 `TIED` tag · roster changed shows notice + no chart + dimmed DETAILS + degraded summary on one artboard · Wildcard keeps the 86 px Elo column and renders a dimmed “—” for everyone, so column geometry is mode-independent.

## PROPOSAL — parked by default

1. Match duration mirrored in the TopBar’s right slot (where the cockpit shows the round counter).
2. BEST TURN naming the thrower — the only game-level number that credits a player; drop to a bare number if it reads as a second leaderboard.

## Reuse — untouched

`ProgressionChart` (168 px, full inner width, under `SCORE PER ROUND`) · `GolfScoreGrid` (own horizontal scroll, above the chart, under `SCORECARD`) · `DossedartCrtFrame` / `DossedartTopBar` / `DossedartPlayerAvatar` · KAMPDETALJER behind DETAILS.

## Constraints honored

820 × 1180 · DOSSEDART tokens only (incl. lime `#C6FF3C`; silver `#C0C0C0` as the one carried-over podium exception) · `Press Start 2P` / `VT323` · no border-radius · all UI strings English · new functionality PROPOSAL-only.

## Files

| File | Purpose |
|---|---|
| `DOSSEDART postgame round.html` | The round canvas |
| `postgame-round.jsx` | Screen, stat grid, match summary, all artboards |
| `postgame-round-spec.jsx` | The two fasit cards |
| `design-canvas.jsx`, `shared.jsx` | Canvas + annotation helpers |
