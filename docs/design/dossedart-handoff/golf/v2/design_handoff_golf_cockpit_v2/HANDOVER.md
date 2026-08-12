# Golf cockpit v2 — design → implementation handover (2026-07-20)

**From:** Claude design (DOSSEDART track)
**To:** implementation (feat/golf)
**Re:** the cockpit-layout round requested in `HANDOVER-to-design-2026-07-20-cockpit-v2.md`
**Deliverable:** `DOSSEDART golf cockpit v2.html` + `golf-cockpit-v2.jsx` (visual fasit).
`golf-design.md` rules v2 remain the behaviour fasit; nothing below changes a rule.

---

## The one idea

**Only the three S/D/T cells register score. Everything else informs.** So the design gives
scoring exactly one treatment — a single glowing, bordered, `▼ TAP TO SCORE` console — and every
other surface (hero, leaderboard, scorecard) is a flat, glow-free readout. If it glows green and is
bordered, you tap it; if it doesn't, it's just telling you what's going on. Keep that split intact.

## Vertical layout (top → bottom)

1. **TopBar** — `◀ EXIT · ⛳ GOLF · HOLE n/18` (→ `PLAYOFF`, red, in sudden death). Reused verbatim.
2. **Hero target** (`V2Hero`) — the "what do I throw at + what's happening" readout.
3. **Leaderboard** (`V2Leaderboard`) — full-width standalone.
4. **Scorecard strip** (`V2ScoreStrip`) — windowed.
5. **spacer** — the freed middle band; the scoring console is pushed to the bottom (`marginTop:auto`).
6. **Input console** (`V2Input`) — pinned directly above the ActionBar (per the "scoring nedover" note:
   it sits over the thumb/button row).
7. **ActionBar** — standard 3 actions `↶ UNDO · ✗ MISS · ⋯ MENU`. **No LOCK IN.**

## Component notes

- **Hero.** Hole number is the aim signal: `~130px`, GREEN, glowing, drop-shadowed — legible from the
  oche. `PAR 3`, dart pips (fill = darts thrown), running `TOTAL n · ±p` top-right, and a status line:
  - tee-off → `▸ TEE OFF · 3 DARTS · LAST DART COUNTS`
  - mid-hole → `LYING n · <term>` + `m DART(S) LEFT` (yellow)
  - hole-result → term-coloured frame + glow, `LYING n · <term>`, finishing player named, `NEXT ▸ X`,
    and a 1s progress bar along the bottom. Inline state — **no overlay**.
- **Leaderboard.** Rows: rank · NAME · this-hole status · TOTAL (big) · ±par. Leader rank is yellow;
  active row gets an accent left-bar + tint. This-hole status = `▶ THROWING` / a term-coloured stroke
  chip (`H7 [2]`) if played / `· TO PLAY`. No glow — it's a readout.
- **Input console.** Header names it (`▼ TAP TO SCORE … REGISTERS YOUR STROKE`). Three cells
  `S/D/T<n>` coloured by term, each showing term + stroke count. Caption reminds `✗ MISS = DOUBLE
  BOGEY · 5 strokes`. In **playoff** the target is `BULL` and the console is **two cells** (`25` /
  `50`); the strip is hidden and the leaderboard shows tied leaders only.
- **Scorecard strip.** Windowed to 7 holes (current −3 … clamped), bigger cells, current highlighted
  yellow with `▶`; `SCORECARD ▸` opens the full sheet. Replaces the always-on 1–18 strip (QA #4).

## States delivered (shipped set, unchanged)

tee-off · mid-hole (`LYING n — m DARTS LEFT`) · hole-result (1s, finishing player) · between-holes
(✓ done banner → new tee) · sudden-death (red overlay on start, tap / 1s auto) · playoff (BULL = two
cells). **Winner = post-game only** — no in-cockpit winner surface. Full scorecard sheet carried across.

## Tokens / rules (unchanged, for reference)

- Stroke → term: T=1 **ACE** (cyan) · D=2 **BIRDIE** (green) · S=3 **PAR** (phosphor) · +1 **BOGEY**
  (orange) · miss=5 **DOUBLE BOGEY** (red) · +3 **TRIPLE BOGEY** (red). Term is derived from vs-par.
- Brand = existing `green #3DFF8E`. Fonts `Press Start 2P` / `VT323`. No border-radius. English strings.
- Frame 820×1180. CrtFrame + scanlines, TopBar, 3-action ActionBar, ATC S/D/T input, the scorecard
  sheet, and home/setup/post-game are all **reused/approved as built** — only the cockpit layout is new.

## Two calls for you to confirm

1. **Windowed strip vs. sheet-only.** I kept a readable windowed strip (QA gave free rein to drop it).
   If you'd rather go sheet-only, delete `V2ScoreStrip` and lean on the `SCORECARD ▸` affordance.
2. **miss = DOUBLE BOGEY.** `golf-design.md §6` calls miss (stroke 5) "BOGEY"; the v2 term palette adds
   `DBL/TRPL BOGEY red`, so I label the +2 result DOUBLE BOGEY (red) for consistency. Trivial string
   flip if you want "BOGEY" back — no colour or layout impact.

Component APIs are golf-only and free to rewrite (`DossedartGolfActiveCard` → hero, `GolfInputCells`,
`GolfScorecardStrip`). Spec card in the deliverable (`Spec · Golf v2`) is the visual fasit.
