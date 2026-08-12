# HANDOVER — 1UP overview (mode round 2/5) · 2026-07-22

**From:** Claude design (DOSSEDART track)
**Responds to:** `HANDOVER-to-design-2026-07-22-one-up-overview-brief.md` + grammar sheet 2026-07-22
**Artboard:** `DOSSEDART 1up overview round.html` (canvas: today's card, 3 proposals, A+ KISS-iteration, stress states, full cockpit, fasit)
**Skeleton:** the approved X01 reference (proposal B) — same 272px zone, 250px card, frame, header, 300px rail.

## Decision

**Proposal A+ — status plate carries the state, KISS-refined** (user-picked after iteration).
A (plate) beat B (glow flips) and C (primary number flips): the plate is a dedicated,
oche-legible status channel; frame + glow keep the player accent so identity and state
never share a channel.

## Fasit

```
OVERVIEW ZONE: h=272 px @ 820×1180 — all states fit, no growth
```

- Inherited verbatim from X01-B: card **250px fixed** + margins 14/12/14/10 · surface fill,
  3px **player-accent** border (never flips), 14px accent glow · header rule 4 (photo avatar 56px,
  name curve 18/15/12/10, pips + `DART n/3`) · 300px right rail · everything always rendered (rule 2).
- **Primary (rule 6):** `BEAT <target>` 60px PS in player accent. Free throw (game start /
  SURVIVOR round start): same slot shows **SET THE TARGET** in lime (1UP brand) — no growth.
- **Header extras (A+):** lives (♥ pips, accent; 1 life = red hearts + `LAST LIFE` outline tag —
  persistent danger, independent of plate) sit next to the name.
- **Left column (A+, two elements):** `THIS TURN` **total / target** (`71 / 118`, VT-38/28,
  dims 0.34 before first dart) top-aligned to the shared hairline · **status plate** (min 52px,
  always rendered) bottom-aligned with the rail's TARGET BY row.
- **Status plate states:** neutral `NEED n MORE ▶ T16 +` (yellow + green HIT suggestion) ·
  **green filled `SAFE ✓ · NEW TARGET n`** (SURVIVOR: `ROUND SURVIVED`) ·
  **red filled `CAN'T BEAT · MAX n LEFT`** · free throw: lime-bordered cyan hint line.
- **Shared hairline** spans the full card between header and columns; carries the
  `SURVIVOR · RND n` label (lime) only — BEAT THE LAST shows no label (KISS).
- **Rail:** sorted by **throw order** (design call per brief — the target chain follows throw
  order, lives ties make a ladder meaningless, rows stay put through eliminations).
  Row = order nr + accent dot + name + ♥ pips (1 life = red heart). **ROUND OUT** (SURVIVOR):
  dot/name dimmed 0.3 + red outline tag. **Eliminated:** `💀 OUT`, row dim.
  Bottom row: **TARGET BY <name>** (yellow); `—` dimmed on free throw.
- Long names: header curve bottoms at 10px >16 chars; rail middle-truncates to 16 chars
  (tested: "Alexander the boss bitch", 24 chars).

## PROPOSAL (needs sign-off, standard protocol)

- **HIT suggestion** in the plate (`NEED 47 MORE ▶ T16 +`) — new data not in the brief (user ask).
  Suggested definition: lowest single segment that beats the target; `+`-suffixed next segment up
  when no exact hit exists; hidden in free/SAFE/CAN'T-BEAT. Implementation owns the algorithm.

## Implementation owns

Variant behaviour (BEAT THE LAST / SURVIVOR) · tie logic (≥ = SAFE) · HIT-suggestion algorithm ·
`DossedartOneUpActiveCard` rewrite · fixed-height regression test pinning 272px.

## Constraints honored

820×1180 · TopBar/board/glow/ActionBar untouched (approved chrome) · tokens only · player accents
from the 5-accent cycle (rule 7) · lime = 1UP brand only, never a player accent · green SAFE /
red danger kept as approved mode-semantic deviations · Press Start 2P / VT323 · no border-radius ·
English UI strings.

## Round order

Next: Gotcha → Wildcard → Killer.
