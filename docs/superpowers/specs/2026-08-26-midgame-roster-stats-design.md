# Mid-game roster changes count — design (2026-08-26)

**Origin:** during the first event night Bjørn noticed that adding or removing a player mid-game
throws away the whole game's statistics and rating. With people coming and going at a party that
happens often, and it makes the event table lie. His call: **joiners count fully; players who
leave vanish from that game's statistics.** Everyone else counts as normal. General rule, not
event-only — two rule sets for one action is unexplainable on a tablet at a party.

**Scope:** stats, Elo, H2H, achievements and game history for games with a roster change, in all
ten modes. No change to join-fairness (starting score/handicap on join — already done 2026-08-10),
to removal rules, to scoring, or to the post-game progression chart (still suppressed on a roster
change — its lines index by seat and would mislabel).

---

## 1. Why it is skipped today

Ten screens share one flag, `_midGamePlayerChanges`, set on join and on removal. When set,
`_updateStats` early-returns after recording only the join/leave counters
(`StatsRecorder.recordMidGameChanges`) — no `recordGame`, no Elo, no history entry.

The reason is the placement a removed seat gets:

| Family | Screens | Removed seat's placement |
|---|---|---|
| A — screen-owned `_removedPlayerIndices` | X01, ATC, Splitscore, Killer | a **real** rank (X01/ATC even add the seat to `finishedPlayers`, so it can be 1) |
| B — engine-owned `skippedIndices` | Cricket, Shanghai, Golf, Gotcha, 1UP, Wildcard | **0** |

`StatsRecorder.recordGame` takes `min(placements)` as the winner, `EloService` treats lower as
better, `awardGameEnd` and `seasonStatsFrom` do the same. A 0 wins everything and every H2H; a
real rank credits a game the player did not finish. Skipping everything was the safe answer in
May; join-fairness has since removed the *other* reason (unfair joiner), so only this remains.

## 2. The rule

- **Joiner:** counts fully — `gamesPlayed`, win/loss, streaks, H2H, mode stats, Elo, history.
  Join-fairness already gives them a fair start. `gamesJoinedMidway` still increments.
- **Removed player:** excluded from that game entirely — no `gamesPlayed`, no win/loss, no streak
  change, no H2H (neither for nor against them), no mode counters, no Elo delta, no achievements
  from that game. Nobody gains rating for "beating" someone who left. `gamesLeftMidway` still
  increments. Their throws stay in `throwHistory` (seat-indexed) and they stay in the history
  entry's `players` list **flagged `removed`**, so seat ↔ throw alignment is preserved.
- **Everyone else:** counts exactly as in a game with no roster change.
- The post-game **progression chart** stays suppressed on a roster change (seat misalignment in
  `matchSummaryFrom`); the **DETAILS** drill-down is now offered — it reads the same flagged
  history entry every other consumer reads.
- `GameResult.statsSkipped` and the orange `STATISTICS NOT RECORDED` banner go away.

## 3. One mechanism: `excludedSeats`

Index alignment is load-bearing (`DartThrow.playerIndex`, `earnedFeatsByIndex`, `modeCounters`),
so removed seats are **not dropped** from the lists — they are named and skipped:

```dart
StatsRecorder.recordGame({..., Set<int> excludedSeats = const {}})
StatsRecorder.buildEntry({..., Set<int> excludedSeats = const {}})
EloService.updateRatings({..., Set<int> excludedSeats = const {}})
AchievementService.awardGameEnd({..., Set<int> excludedSeats = const {}})
```

- `recordGame`: `bestPlacement`/`bestIsShared` computed over non-excluded seats only; the main
  loop `continue`s on excluded `i`; the H2H inner loop `continue`s on excluded `j`; rating
  snapshot skipped for excluded. `buildEntry` marks `GameHistoryPlayer(removed: true)` for them.
- `updateRatings`: excluded seats never enter `indexToSaved`; `n` = number of non-excluded seats
  (so the `1/(n-1)` scale is the real field size).
- `awardGameEnd`: `best` over non-excluded; excluded seats skipped.

Default `const {}` keeps every existing call site and test byte-for-byte equivalent.

## 4. History model

`GameHistoryPlayer` gains `final bool removed` (default `false`; JSON key `removed` written only
when true; absent → false, so every stored entry decodes unchanged). `GameHistoryEntry` gains:

```dart
List<GameHistoryPlayer> get activePlayers => players.where((p) => !p.removed).toList();
```

Consumers that rank or credit must use `activePlayers` (or check `removed`):

| Consumer | Change |
|---|---|
| `lib/stats/season_stats.dart` | best/shared over active; skip removed seats for games/wins/throws (seat index kept) |
| `lib/stats/season_replay.dart` | pass `excludedSeats` = removed seat indices, so a replay equals the live result |
| `lib/services/season_service.dart` `_qualifiedOnFinalDay` | a game counts for a player only if their row is not removed |
| `lib/stats/profile_stats.dart` form | skip entries where `me.removed`; best over active |
| `lib/screens/stats_screen.dart` streaks + checkouts | skip games where the player's row is removed; best over active |
| `lib/screens/dossedart/game_detail_screen.dart` | `ranked` and feats over active; per-seat chart/stat grid unchanged (seat data is real) |

`stats_migration.dart` is unaffected: it reads `players` and passes it through.

## 5. Screens

Every screen: drop the early return in `_updateStats`; call `recordMidGameChanges` (via the
existing counters helper) unconditionally — it no-ops on empty sets; pass `excludedSeats` to the
four calls in §3. Then per family:

- **Family A** (X01, ATC, Splitscore, Killer): every screen-side loop over players — SavedPlayer
  updates (`gamesPlayed++`, `gamesWon`, turn totals), `modeCounters`, ratings capture — gets
  `if (_removedPlayerIndices.contains(pi)) continue;`. Splitscore's winner scan skips removed. X01's
  `_showEarlyTerminationPostGame` results loop skips removed (the normal path already does).
- **Family B**: `modeCounters` loops already skip; only the four calls need `excludedSeats:
  engine.skippedIndices` (Cricket/Shanghai/Golf/Gotcha/1UP/Wildcard).
- `GameResult`: remove `statsSkipped:`; `detailEntry` no longer nulled on the flag (X01, Golf,
  Wildcard); keep `throwHistory`/`progressionMode` gating.
- Copy: remove-confirm dialog `'Statistics will not be recorded for this game.'` →
  `'They are left out of this game's statistics and rating. Everyone else still counts.'`
  Sheet `addInfoText`: delete the sentence `Rating is skipped for this game once you add or remove
  a player.` (Golf/1UP have seed-only texts — unchanged).

`_midGamePlayerChanges` survives with one job: suppress the chart. Test getters keep working.

## 6. Post-game

`GameResult.statsSkipped` removed; `_RosterNotice` deleted; `showDetails = result.detailEntry !=
null`. `post_game_dossedart_test` / `post_game_details_test` lose their `statsSkipped` cases.

## 7. Edge cases

- **Removed then only one active player left / game aborted:** unchanged — screens already
  decide whether a game "ended"; if they record, the lone active player has a valid placement.
- **Joiner who is then removed:** both counters increment (as today); excluded like any removed.
- **Removed player had the best placement (Family A):** irrelevant — excluded before ranking.
- **Draw among active players:** same rule as before (shared best → nobody wins).
- **Elo with < 2 active saved players:** `updateRatings` returns early, as it does for guests.
- **Event night:** nothing special — event games go through the same path with `eventId`.
- **Old history:** no `removed` key → `false` → identical numbers to today.

## 8. Verification (Bjørn asked for extra checks)

- Unit: `recordGame`/`updateRatings`/`awardGameEnd`/`buildEntry` with `excludedSeats` — excluded
  seat untouched, others equal to the same game without that seat, H2H excludes pairs, history
  flags `removed`, JSON round-trip.
- Unit: `seasonStatsFrom`/`replayRatings`/profile form ignore removed rows.
- Screen: one Family-A (X01) and one Family-B (Shanghai — flip the existing "writes no entry"
  test) end-to-end through `_updateStats`: removed player's `gamesPlayed`/rating unchanged, others
  incremented/rated, history entry has the flag, joiner counted.
- The 8 removed-player-wins regression tests and `midgame_roster_rules_test` must stay green
  untouched.
- Full suite + `flutter analyze`, then a tablet smoke test of one game with a join and a removal.

## 9. Out of scope

Chart alignment for changed rosters; per-mode "left mid-game" badges; retroactively counting past
skipped games (they were never written).
