# WILDCARD QA-round-5 polish — design

**Date:** 2026-07-13
**Branch:** `feat/wildcard-qa3` (current WILDCARD QA branch; release-train — push on Bjørn's signal)
**Status:** design for review

## Goal

Four coordinated changes on the WILDCARD QA branch, driven by playtest + log review of `game_log_2026-07-13.txt`:

1. **Event reveal dialogs** — make every event that moves points *or* changes turn order legible (who was involved, and what changed).
2. **HEAVY CROWN** — a rare, leader-only catch-up mechanic.
3. **Chaos tuning** — break the runaway feedback loop *and* make the current level readable.
4. **Logging pass (all 6 modes)** — a full-standings snapshot plus supporting lines, so score discrepancies are diagnosable from the log alone.

## Background — what the log showed

- Over ~22 turns of one 10-round 2-player game, **~65 % of turns carried chaos** (6 instant events + 9 modifiers): SCORE SWAP ×3, REWIND ×2, FREEZE ×1.
- The chaos meter is a **positive feedback loop**: a joker hit is +2, which pushes the level up; at level ≥7 there are **2 jokers on the board and a 65–90 % modifier chance**, unlocking the wild events (REWIND/CUT/DOUBLE JEOPARDY). More jokers → more +2 hits → the meter ratchets to 9–10 and stays there. The only downward pressure is a true miss (−1) or a "calm" bull choice — far too weak to counteract it.
- **No scoring bug found.** The line that looked wrong (a frozen player "banking" 76→107) was a SCORE SWAP firing inside the same dart — the log correctly showed the thrower's post-swap total, but with no visible cause. This is a *legibility* problem, not a correctness one.
- The log could **not** be fully reconstructed because it records only the active thrower's total and never the chaos level. That blind spot motivates parts 1 and 4.
- Battery: ~1.4 %/min during this game (~55 % above the app's ~0.9 %/min baseline), because the game sat pinned at chaos 9–10, where the meter-pulse and red danger-vignette animations run continuously. Taming chaos (part 3) is expected to reduce this as a side effect — not a separate perf project.

---

## Part 1 — Event reveal dialogs

**Problem:** SCORE SWAP, ROBIN HOOD, GIFT and CURSED NUMBER move points between players invisibly; FREEZE, REWIND and CUT! change *who throws* with no clear statement of who is affected. The player sees a total jump or a skipped turn with no explanation.

**Approach:** enrich the existing `WildcardDialog` / dedicated dialogs (no new overlay machinery). Same tap-to-continue flow already in place for events.

### Score-moving events — show `name  before → after` per involved player

Only the players actually affected are shown (so 3+ player games stay clear about who was involved).

- **SCORE SWAP** — two rows: joker-hitter + the swapped player.
  ```
        🔄 SCORE SWAP
     AA      123 → 100
     AAA     100 → 123
  ```
- **ROBIN HOOD** — victim (the robbed leader) and the hitter:
  ```
        🏹 ROBIN HOOD
     AA (leader)  288 → 238
     AAA          150 → 200
  ```
- **GIFT** — the last-place recipient (`before → after`, gaining the current + remaining darts); sub-line notes the hitter's darts were redirected.
- **CURSED NUMBER** — two moments:
  - When the curse is *placed* (event fires): announce a curse is loose. The number is hidden by design, so no before/after here.
  - When the curse is *hit*: reveal the thrower's own `before → after` (the negative applied).

Optional polish: colour the losing delta red and the gaining delta green (uses `DossedartTokens`, still tokens-only).

### Turn-flow events — state who is affected

- **FREEZE** — name the frozen player: `AAA FROZEN · skipped next turn (scores 0)`.
- **REWIND** — `ROUND <n> RESTARTS`, the restored totals per player (`before → after` of the wipe), and who throws first.
- **CUT!** — `ROUND <n> CUT`, and which players lose their remaining turn this round. *(Added by the same legibility logic as REWIND; confirm or drop in review.)*

Events left as-is (no consequence to track): CHAOS SURGE, DOUBLE JEOPARDY.

---

## Part 2 — HEAVY CROWN (rare leader catch-up)

A new conditional turn-modifier (`heavyCrown`) that is **not** in the random modifier pool — the engine applies it via a bespoke trigger.

- **Gate:** from round 4 onward (checked at the leader's turn start), only for a player who leads the field by **≥ 120 points** (`kHeavyCrownLeadThreshold`, tunable constant).
- **Trigger:** when a qualifying leader starts their turn, a small chance (`kHeavyCrownChance`, ~25 %, tunable) that the crown falls on them that turn. May recur across a game, but the high lead-gate keeps it rare (target ~1 in 5 games sees it at all — calibrated on tablet QA).
- **Effect (true miss only — MISS button / off-board, not a dimmed 0):** escalating penalty by miss count in the turn — **1 miss = −20, 2 = −40, 3 = −80** — **subtracted from the player's game total** (floor 0), applied at turn end from the final miss count. Subtracting from the *total* (not just capping the turn at 0) is what forces the leader to play safe and aim low rather than chase triples.
- **Independence:** overrides the normal modifier roll for that turn (no double modifier); independent of the chaos meter, so it can fire even at low chaos.
- **Meter:** a true miss still moves the meter −1 as today; the HEAVY CROWN penalty is a separate score effect.
- **Announcement:** reuses the modifier announce overlay, sub-line ~`Misses are brutal — play it safe`.

---

## Part 3 — Chaos tuning (tame the loop *and* make it readable)

**Tame the runaway loop:**
- Joker hit meter gain **+2 → +1** (halves the dominant upward pressure).
- **−1 meter decay at each round start** (breaks the ratchet; the meter can now come back down between rounds).
- Starting-chaos config unchanged (Mild 2 / Spicy 5 / Total chaos 8).

*(Exact values are the proposed defaults; recalibrate after tablet QA. Goal: chaos should feel like spice, not a constant state.)*

**Make it readable:**
- The event reveal dialogs (part 1).
- Chaos level + standings in the log (part 4).
- The on-screen chaos meter already shows the current level — no change needed there.

---

## Part 4 — Logging pass (all 6 modes)

The logger's general lines are gated behind `isGeneralAllowed` (full mode) — battery already has its own gate. All additions respect that.

**Generic (all modes):**
- **`STANDINGS` snapshot** — one line listing *every* player's total, emitted at each turn end / round complete. Diffing consecutive snapshots localises any wrong score to the exact turn. This is the core "find the discrepancy" tool.
- **Turn-start line** — standardise `R# TURN P#(name) score=…` across all modes (WILDCARD currently logs no turn start at all), so rotation bugs — wrong player up, skipped seat, double turn — are visible.
- **Roster mutations** — log ADD/REMOVE mid-game with the resulting roster + a standings snapshot. Historically the most bug-prone area (removed-player-wins was fixed across all 5 modes).
- **Build stamp** — app version (+ device if cheap) on the `GAME #` line, so a logged bug is pinned to a build.

**WILDCARD-specific:**
- Chaos level on the turn-start line, and on every change (joker +1, bull choice, chaos surge, round-start decay).
- The joker number(s) currently on the board / the number hit (`joker=18`).
- THE WINDOW bounds when it activates.
- The cursed-number value when set.
- REWIND restore totals.
- Numbers on the SCORE SWAP event detail (parity with ROBIN HOOD, which already logs them).

**Already covered — no change:** global exception capture (`FlutterError.onError` + `PlatformDispatcher.instance.onError` → `GameLogger.logError` in `main.dart`) already writes uncaught errors + stack traces to the log.

---

## Out of scope

- No new events or modifiers beyond HEAVY CROWN — the playtest problem is frequency/legibility, not lack of variety.
- No reveal/"what happened" screens in non-WILDCARD modes (Splitscore halving, Gotcha steal) — a separate design track if wanted later.
- No standalone battery/perf refactor (the chaos-tuning side effect is enough for now).
- No Elo (unchanged from WILDCARD v1).

## Testing notes

- Engine tests (seeded `math.Random`) for: HEAVY CROWN gate + chance + escalating penalty + floor 0 + total-not-turn; joker +1 meter gain; round-start −1 decay + clamp; event resolution details carrying before/after totals.
- Widget tests for each reveal dialog variant (swap / robin hood / gift / cursed / freeze / rewind / cut) rendering the right names + before→after rows.
- Logger tests: `STANDINGS` line format, turn-start line, roster-mutation lines, build stamp; all suppressed when log mode ≠ full.
- Cross-mode: the generic logging additions must not break the existing screen-test harnesses in the other 5 modes.
- Manual tablet pass: forced HEAVY CROWN via dev override; a swap/robin/gift/freeze/rewind/cut reveal each; chaos no longer pinned at 9–10 across a full game; a log with standings diffable by hand.

## Tunable constants (calibrate on tablet QA)

| Constant | Proposed default | Purpose |
|---|---|---|
| `kHeavyCrownLeadThreshold` | 120 | Minimum lead to qualify |
| `kHeavyCrownChance` | ~0.25 | Per-qualifying-turn trigger chance |
| Joker meter gain | +1 (was +2) | Tame the loop |
| Round-start meter decay | −1 | Break the ratchet |
