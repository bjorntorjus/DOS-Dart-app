# Elo seasons — design (2026-08-11)

**Origin:** the rating had stopped doing its job. Four complaints, all from Bjørn: the luck-heavy
modes polluted the number, one player sat permanently on top, nobody cared about it, and players
who had fallen behind found it hard to climb — an early lead, earned while everyone still had a
high K-factor, had frozen into a permanent hierarchy.

**Scope:** how the rating is scoped, reset and displayed. No change to the Elo maths itself, to
achievements, or to any per-mode statistic.

---

## 1. The diagnosis

All four complaints share one cause: the rating is a **single permanent number that counts every
mode and has a frozen K**. Each symptom follows from it — luck modes pollute because everything
counts, the top is permanent because nothing ever resets, nobody cares because it never *resolves*
into anything, and those behind are stuck because K drops once a player passes 20 games.

One thing is stated plainly rather than designed around: **if a player rarely wins, no rating
model should lift them toward the top** — that would make the number lie. What is genuinely
unfair, and is fixed here, is that an early lead compounds forever.

## 2. Seasons

**Calendar quarters.** Season 1 is **Q3 2026 — 1 July to 30 September 2026**, applied
retroactively (see §5). Subsequent seasons follow the calendar: Q4 starts 1 October.

**Hard reset to 1200** at each boundary — not a partial regression. Everyone starts a quarter
level. This is a deliberate reframe: with quarterly resets the rating stops being a lifetime skill
estimate and becomes **a quarterly table**. That is the point — it gives the number something to
resolve into, which is what "nobody cares" was really about.

**Closing happens lazily at app start**, never on a timer. When the app opens and the current
quarter has ended, the season is closed then — before any game can be started. A boundary that
passes at 21:00 on a Friday closes the next time the app launches. No background job, and no
season ending in the middle of a game night.

## 3. The K-factor is deliberately left alone

The obvious move — raise K, or reset the K baseline each season — was tested against a simulation
of a realistic quarter (K=16, four-player fields, averaged over 200 runs per cell):

| Games in the quarter | Wins 60 % | Wins 40 % | Wins 20 % |
|---|---|---|---|
| 2 | 1207 | 1201 | 1195 |
| 10 | 1224 | 1202 | 1179 |
| 20 | 1247 | 1204 | 1163 |
| 40 | **1276** | 1208 | **1140** |

For the players who actually play, the current K already separates the field by ~140 points across
a quarter. **The rating is not too slow; the two-game player is too quiet.** Raising K would have
amplified that noise rather than removed it. K stays at 32 below 20 lifetime games and 16 after.

Related, and worth recording because it was the original request: **Elo already pays the underdog
more.** At K=16 in a four-player game, a player on 1000 who beats three opponents on 1300 gains
**+13.6**, an even win pays **+8.0**, and a leader on 1400 beating three on 1150 gains **+3.1**.
No underdog bonus is added — the mechanism exists, and bolting a bonus on top would mean the
number is no longer an Elo and two players with the same rating would no longer be comparable.

## 4. Rated modes

Rating counts every mode **except WILDCARD and Killer**. WILDCARD is chaos by design and already
skipped; Killer is decided in large part by who gets attacked rather than who throws best.

The exclusion moves into `EloService.updateRatings`, which gains a required mode parameter and
returns early for an unrated mode. One gate, in the place that can't be forgotten, instead of ten
call sites each remembering not to call it.

**Post-game display:** an unrated mode drops the Elo column entirely rather than rendering the
dimmed em dash the design round specified. Bjørn's call — "WILDCARD trenger ikke ELO". The
standings' column geometry then differs between rated and unrated modes, which is accepted.

## 5. Retroactive season 1

Game history holds everything the replay needs: `date`, `gameMode`, and per player
`savedPlayerId` and `placement` — exactly the inputs `updateRatings` takes.

Season 1 is therefore built by: setting every saved player to 1200, taking every history entry
dated 1 July 2026 or later in date order, skipping unrated modes, and applying `updateRatings` to
each. The result is Q3 exactly as if seasons had existed since 1 July.

Two natural exclusions need no special handling: games by guest players (no `savedPlayerId`)
contribute nothing, exactly as they do live; and games with a mid-game roster change were never
written to history at all.

**Before the replay, today's ratings are archived as an `all-time` row.** They are the product of
history that may predate what game history still holds, so they cannot be reconstructed if the
decision is ever regretted.

## 6. Qualification

**10 games within the season** to be ranked. Below that a player is listed *under* the table as
`UNQUALIFIED · 4/10` with their rating shown but no rank.

The simulation is the argument: after 2 games a 60 %-winner sits at 1207 and a 20 %-winner at
1195 — the number carries no signal at all, yet it would place them mid-table. After 10 games the
spread is at least directional. This is what every ladder does with placement games, and it is a
presentation rule, not a maths change: the unqualified player's rating still updates normally.

## 7. The archive

A season record holds one row per player who appeared in it: final rating, games, wins, win %,
hit %, and rank.

**Season figures come from game history filtered by date range, not from cumulative counters.**
That single decision is what makes §5 possible — a cumulative-diff scheme would need a snapshot
taken on 1 July, which does not exist. It also means no new live tracking is added anywhere.

**Hit % needs no new counter.** All ten modes already persist `throwHistory` with each history
entry, and a dart counts as a hit when `multiplier > 0` — a definition that holds in every mode
because every mode records real `DartThrow` multipliers. Season 1 therefore gets a real hit %
rather than a dash. *(This replaces an earlier decision to add a uniform hit counter; it was
unnecessary.)*

## 8. What a reset touches — and what it never touches

| Reset at a season boundary | Never touched by a reset |
|---|---|
| `SavedPlayer.rating` → 1200 | `unlockedAchievementIds` |
| Season number and start date | `gamesPlayed`, `gamesWon`, `modeStats` |
| | Game history |

Bjørn's constraint — a reset must not affect achievements such as "win the first game you play" —
holds by construction: unlocks live in their own field, and milestone achievements that count
lifetime games read counters a reset never writes.

One honest side effect: the achievement for beating an opponent rated 200+ above you gets
**rarer** after each reset, because a hard reset compresses every gap to zero. Nobody loses an
unlock they already have — it is a one-time award — but it becomes a harder thing to earn early in
a season.

## 9. Testing

- **Replay determinism:** a fixed history fixture replayed twice yields identical ratings, and
  replaying it produces the same ratings as applying the same games live one at a time.
- **Unrated modes:** a history containing only Killer and WILDCARD games leaves every rating at
  1200 after a replay.
- **Season boundary:** a clock at 30 September 23:59 does not close Q3; 1 October 00:00 does. A
  boundary crossed while the app was shut closes on the next launch, once, not repeatedly.
- **Reset scope:** after a close, `rating` is 1200 while `gamesPlayed`, `gamesWon`, `modeStats`
  and `unlockedAchievementIds` are byte-for-byte unchanged.
- **Qualification:** a player with 9 season games is unranked and labelled `9/10`; the tenth game
  ranks them, and their rating was updating the whole time.
- **Hit %:** derived from a known throw fixture, with bulls and misses counted per §7.
- **Archive integrity:** closing a season twice does not duplicate its record, and the `all-time`
  row is written exactly once, before season 1's replay.

## 10. Out of scope

- **Per-mode ratings.** Ten ratings in a friend group means ten numbers that all hover near 1200;
  the symptoms are addressed by seasons and rated-mode selection at a fraction of the complexity.
- Any change to the Elo formula, the K values, or the pairwise scaling.
- Season-scoped achievements. Achievements stay lifetime.
