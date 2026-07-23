# Post-game v2 — wave 1 design (2026-07-23)

**Scope:** the shared `PostGameScreen` (lib/screens/post_game_screen.dart) — richer results for every mode, Golf lifted hardest. Approved direction (Bjørn 2026-07-23): "nesten alle trenger mer info; grafen er fin i nesten alle gamemodes; vi burde presentere mye mer data." Wave 1 = the three cross-mode lifts + Golf. Wave 2 (separate spec) = per-mode stat depth for the remaining modes.

## Wave 1 contents

### 1. The progression chart everywhere (wave-1 scope: 8 of 10 modes)
`ProgressionChart` + `progressionForMode()` already support x01, cricket, aroundTheClock, shanghai, halveIt, gotcha, wildcard — but only Wildcard passes `progressionMode`/`throwHistory` into `GameResult`. Wire the remaining 6 supported call sites (pass `throwHistory` + `progressionMode`, mirroring wildcard's `_midGamePlayerChanges ? null : ...` guard), and ADD one new progression:
- `GolfProgression`: strokes per hole computed FROM throwHistory (group by `roundNumber`; strokes = 3 misses → 6, else `(4 - hitMultiplier) + misses` — `DartThrow.points` is a placeholder in golf and must NOT be used), rendered ascending-cumulative vs-par or per-hole (implementation picks per chart readability; PAR baseline visible).
**Deferred to wave 2:** 1UP and Killer charts — 1UP's lives aren't derivable from DartThrow, and Killer never stamps `roundNumber` on its throws (screen has `_roundNumber` but doesn't wire it). Wave 2 adds the stamping + engines' series.

### 2. DETAILS → KAMPDETALJER (ephemeral entry)
A `▶ DETAILS` button on the post-game screen opening `GameDetailScreen(entry: ...)`. TIMING CONSTRAINT (verified): recording is deferred until Finish (post-game Undo safety), so no `GameHistoryEntry` exists while the post-game screen shows. Solution: `GameDetailScreen` takes the entry OBJECT — build an EPHEMERAL entry in memory. Extract the entry-assembly from `StatsRecorder.recordGame` into a shared `StatsRecorder.buildEntry(...)` used by both recordGame and a new optional `GameResult.detailEntry` field; the post-game screen shows the DETAILS button when `detailEntry != null`. Wave 1 wires it for golf + x01 + wildcard (the three richest detail views); remaining modes in wave 2 (mechanical). Hidden when `statsSkipped`.

### 3. Shanghai bug + dead fields
- Add `case 'shanghai'` in `_PlayerResultTile._buildStats`: Score, Best round (max round sum from throwHistory), and a `Shanghai!` marker on the winner when `engine.isInstantShanghai` (boolean flag — a shanghai instantly ends the game, so it is 0-or-1, not a counter; screen passes `'shanghai': true` in the winner's stats).
- Render the four dead fields: Gotcha `score` ("Score: X"), 1UP `elimsDealt` ("Elims: X", hide at 0), Golf `firstDartHits` ("1st-dart: X/Y" — needs holesPlayed) and `holesPlayed` (folded into the 1st-dart row).

### 4. Golf lift (the "veldig dårlig" fix)
- **Embed the hole-by-hole scorecard grid** on the post-game screen for golf games — reuse `_GolfScoreSheet`'s grid (lib/widgets/dossedart/golf/golf_scorecard.dart): extract the grid body into a reusable widget (`GolfScoreGrid`) consumed by both the modal sheet and the post-game embed. All players, PAR row, term-colored cells, legend. Horizontal scroll inside its own container.
- **Term distribution row** per player: `A:1 B:4 P:9 B+:4` style compact counts (aces/birdies/pars/bogey-or-worse) — labels spelled per existing golf vocabulary; hide zero categories.
- Existing stats stay (Strokes ±par, Best hole); add First-dart hits (see §3).
- Golf progression chart per §1.

## Constraints
- Post-game screen is shared and classic-M3-styled; new elements follow its existing patterns (stat-row strings, card sections). No DOSSEDART-token styling here (this screen serves both tracks) — colorScheme roles per CLAUDE.md palette.
- English UI strings. No behavioral/rules changes. Elo suppression rules per mode unchanged (Wildcard stays Elo-less).
- Data must come from existing engine/screen state; new counters (e.g. Shanghai shanghais, golf term counts) are computed at game end in the screen, not stored.

## Out of scope (wave 2)
X01 turn-distribution counters (100+/140+/180), checkout-%, first-9; Cricket MPR + close-order; ATC hit-%/streaks; Splitscore halving losses; Killer kills/deaths/self-hits; Gotcha comeback; 1UP target averages; Wildcard chaos peak. Design round for a visual post-game redesign (if wanted) is separate.
