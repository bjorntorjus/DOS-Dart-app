# Golf cockpit v2 — copy deltas at implementation (KISS pass, 2026-07-20)

Layout implemented as designed. Copy trimmed per Bjørn's KISS mandate + rules-v2 corrections
(the v2 artboards inherited some rules-v1 strings). Spec (`golf-design.md` rules v2) wins on rules.

| Artboard copy | Implemented as | Why |
|---|---|---|
| `▸ TEE OFF · 3 DARTS · LAST DART COUNTS` | `▸ TEE OFF · 3 DARTS` | "last dart counts" is rules v1 — hole ends on first hit |
| `✗ MISS = DOUBLE BOGEY · 5 strokes` | `✗ MISS = +1 STROKE` | rules v2: a miss costs +1; it is not a result |
| `▼ TAP TO SCORE` + `THROW AT <n> · REGISTERS YOUR STROKE` (two lines) | `▼ TAP TO SCORE · THROW AT <n>` (one line) | tautology trimmed |
| Handover call #2 ("miss term = DOUBLE BOGEY?") | moot | based on stale v1 rules; terms come from final stroke 1-6 as shipped |
| Handover call #1 (windowed strip vs sheet-only) | **windowed strip kept** | now legible (7 big cells); answers QA #4 |
| Playoff cells `25` / `50` | as designed, with PAR/BIRDIE term sub-labels | keeps term vocabulary from v1 input (QA'd) |

Everything else (hero ~130px hole number, standalone leaderboard, one-glowing-console hierarchy,
inline 1s hole-result readout — no overlay change, states unchanged) implemented as designed.
