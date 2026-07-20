# Golf rules v2 — deltas vs. the 2026-07-20 artboards

The artboards in `design_handoff_golf_cockpit/` (from `DOSSEDART (9).zip`) were built against **rules
v1** (last-dart-counts + LOCK IN). On 2026-07-20 the rules were revised to **v2 (darts-are-strokes)** —
see `docs/superpowers/specs/2026-07-07-golf-design.md` (§2, updated in place). Per the handoff README:
*"If an artboard implies behaviour different from the spec, the spec wins."* This file catalogues every
place the artboards are superseded, so no artboard element is implemented by mistake.

## Rules v2 in one line

Hole ends on the **first hit** (max 3 darts). **Strokes = hit value (T=1 / D=2 / S=3) + 1 per miss
before the hit**; all three miss = **6**. Full outcome table and golf terms (ACE → TRIPLE BOGEY) in the
spec §2.

## Superseded artboard elements — do NOT implement

| Artboard element | v2 replacement |
|---|---|
| **LOCK IN button** in `GFActionBar` (4th action) | Standard 3-action bar `UNDO · MISS · MENU`, identical to other cockpits |
| **State 2 "mid-hole decision"** (`LOCK IN OR RISK?`) | Mid-hole = misses only: `LYING n — m DARTS LEFT` |
| **State 4 "locked in"** (`🔒 LOCKED IN`, green frame) | Hole ends on the hit itself; green frame applies when hole finishes ≤ par |
| **ACE overlay** (`✦✦✦ ACE!` in `GFOverlay`) | No overlay — sound/TTS carries the ACE. **SUDDEN DEATH overlay stays** as designed |
| `LAST DART COUNTS` copy on the tee-off line | `TEE OFF — THROW AT THE n` |
| `MISS = BOGEY (5 STROKES)` caption under `GFInput` | Miss costs +1 stroke; three misses = TRIPLE BOGEY (6) |
| Post-game stat row **lock-ins** | **first-dart hit rate** |
| Setup rules-summary strip (v1 wording) | Reword to v2 (one line, English) |

## Term / colour additions

The v1 artboards score only 1/2/3/5; v2 scores the full 1–6 range. Extend the scorecard term colouring
with the tokens already in the handoff's palette:

- **BOGEY (4)** — orange `#FF7A00` (the handoff already reserves orange for "double-bogey / MISS")
- **DOUBLE BOGEY (5)** — red `#FF3050`
- **TRIPLE BOGEY (6)** — red, strongest treatment (e.g. filled cell) — worst outcome must read at a glance
- ACE (1) cyan · BIRDIE (2) green · PAR (3) phosphor — unchanged from the artboards

## Unchanged — implement as designed

Home tile (⛳ lit + NEW), setup course chips (9/18, default 18), TopBar, active card layout (header,
dart pips, big STROKES + vs par), leaderboard/standings, ATC S/D/T input cells (S=PAR / D=BIRDIE /
T=ACE colouring still correct — those are the first-dart values), scorecard strip + full sheet layout,
sudden death flow (19 → 20 → Bull, leaders only), post-game podium/banner, all typography/tokens/chrome.
