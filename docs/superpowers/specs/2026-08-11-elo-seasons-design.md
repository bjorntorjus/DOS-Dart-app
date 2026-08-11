# Elo seasons — design (2026-08-11)

**Origin:** the rating had stopped doing its job. Four complaints, all from Bjørn: the luck-heavy
modes polluted the number, one player sat permanently on top, nobody cared about it, and players
who had fallen behind found it hard to climb — an early lead, earned while everyone still had a
high K-factor, had frozen into a permanent hierarchy.

**Scope:** how the rating is scoped, reset, displayed and archived, plus the achievements that
follow from it (§10). **No change to the Elo maths itself** — not the formula, not the K values,
not the pairwise scaling — and no change to any per-mode statistic.

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

**Season 1 is everything played so far** — from the oldest surviving game up to **30 June 2026**.
The app computes its start date at migration and labels it with the real range, e.g.
`SEASON 1 · 12 MAR – 30 JUN 2026`.

**Season 2 is Q3 2026** (1 July – 30 September), also built retroactively. From Q4 onward seasons
are plain calendar quarters, closing on 1 January, 1 April, 1 July and 1 October.

**Storage caps bound what season 1 can contain** (§13). Game history keeps the newest 200 entries
and nothing older, so "the oldest surviving game" is not necessarily the group's first ever game.
The UI says *from the oldest recorded game*, never *since you started playing* — the difference is
real and the app has no way to know the latter.

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

## 5. The migration — retroactive seasons 1 and 2

Game history holds everything the replay needs: `date`, `gameMode`, and per player
`savedPlayerId` and `placement` — exactly the inputs `updateRatings` takes.

The migration runs once, in this order:

1. **Refuse to start until a backup has been exported** (§6). This is the only destructive step in
   the app, and it rewrites every player's rating.
2. **Archive today's ratings as an `all-time` row.** They are the product of history that may
   predate what game history still holds, so they cannot be reconstructed afterwards.
3. **Season 1:** set every saved player to 1200, replay every rated history entry dated on or
   before 30 June 2026 in date order, then close the season and store its table.
4. **Season 2:** reset to 1200 again, replay every rated entry from 1 July 2026 onward. This
   season stays open — it is the current quarter — so the live rating after migration is each
   player's Q3 standing.

Two exclusions need no special handling: games by guest players (no `savedPlayerId`) contribute
nothing, exactly as they do live; and games with a mid-game roster change were never written to
history at all.

**The migration is idempotent.** It records that it has run, and re-running it is a no-op rather
than a second reset — a half-applied migration after a crash resumes rather than doubling.

## 6. Backup — a prerequisite, not a nicety

Before the migration may run, the app exports **one JSON file containing saved players, game
history and settings** through the system share sheet, so the copy leaves the device. `share_plus`
is already a dependency and already used this way for log sharing in Settings, so the mechanism
exists.

The migration is gated on it: until an export has completed, the migration screen offers only
"Export backup". This is deliberate friction on the one operation that rewrites every rating.

**The backup matters beyond this migration.** Game history is already capped at 200 entries, so
games are being discarded on an ordinary evening, migration or not. An export is the only way to
keep anything older. Import (restoring from the file) is **out of scope here** — it is the natural
follow-up, and without it the file is insurance you can read but not yet apply.

## 7. Qualification

**10 games within the season** to be ranked. Below that a player is listed *under* the table as
`UNQUALIFIED · 4/10` with their rating shown but no rank.

The simulation is the argument: after 2 games a 60 %-winner sits at 1207 and a 20 %-winner at
1195 — the number carries no signal at all, yet it would place them mid-table. After 10 games the
spread is at least directional. This is what every ladder does with placement games, and it is a
presentation rule, not a maths change: the unqualified player's rating still updates normally.

## 8. The archive

A season record holds one row per player who appeared in it: final rating, games, wins, win %,
hit %, and rank.

**Season figures come from game history filtered by date range, not from cumulative counters.**
That single decision is what makes §5 possible — a cumulative-diff scheme would need snapshots
taken on 30 June and 1 July, which do not exist. It also means no new live tracking is added for
games, wins or rating.

### Hit % does need a stored counter — a correction

An earlier draft of this spec dropped the uniform hit counter, reasoning that every mode already
persists `throwHistory` with its history entry so hit % could be derived retroactively. **That was
wrong**, and the reason is `GameHistoryService`:

```dart
static const _maxEntries = 200;        // older games are dropped for good
static const _maxThrowHistory = 100;   // throws are stripped from entry 101 onward
```

Throws survive for only the newest 100 games. Deriving hit % from them would give a partial figure
for season 1 today, and the same partial figure for any future season busy enough to push games
past the 100 mark before it closes.

**Therefore:** `dartsThrown` and `dartsHit` are computed at record time and stored in
`GameHistoryPlayer.stats`, which the pruning does not touch. A dart is a hit when `multiplier > 0`
— a definition that holds in every mode, since every mode records real `DartThrow` multipliers.

**Season 1 and 2 are retroactive, so their hit % is partial by nature.** They are computed from
whatever throws still survive, and the archive marks the figure as covering *n of m games* rather
than presenting it as complete. From the first game recorded after this ships, hit % is exact.

## 9. Viewing past seasons

A fifth **SEASONS** tab in the DOSSEDART stats screen, which already carries four. It lists
seasons newest first with their date range and winner; opening one shows the table — rank, player,
rating, games, win %, hit % — with unqualified players beneath it per §7.

The current season appears at the top, marked as running, with its closing date.

## 10. Achievements

### Season achievements — twelve, all lifetime unlocks

Season achievements need **no new state model**. Each is a permanent unlock like every other; only
the trigger is new — a hook that runs once per player when a season closes, reading that player's
archive row plus their earlier rows.

| Name | Trigger | Tier |
|---|---|---|
| `SEASON CHAMPION` | Win a season | gold |
| `DYNASTY` | Win two seasons in a row | gold |
| `UNTOUCHABLE` | End a season 100+ points clear of second place | gold |
| `PODIUM REGULAR` | Finish top 3 in three different seasons | silver |
| `THE CLIMB` | Improve your rank by 3+ places from one season to the next | silver |
| `ROOKIE SEASON` | Qualify in your very first season | bronze |
| `IRON ARM` | Play 40+ games in one season | silver |
| `JUST IN TIME` | Qualify with your 10th game on the season's final day | silver |
| `NINE AND OUT` | End a season on exactly 9 games — one short | bronze |
| `ALMOST FAMOUS` | Finish second in a season | bronze |
| `PARTICIPATION TROPHY` | Finish last among the qualified players | bronze |
| `GHOST` | Get through a whole season without qualifying | bronze |

Names are globally unique with no parenthetical mode suffixes, and the bottom four are deliberately
self-deprecating — both standing rules for this catalogue.

**Retroactive unlocks:** the migration closes seasons 1 and 2, so these evaluate against them and
players may unlock several at once. That is intended — the seasons genuinely happened.

**Not included: a hit-% badge.** There is no honest threshold to pick yet. X01 scores on nearly
every dart while ATC misses far more often, so a cross-mode hit % has no established range. It is
worth adding once one real season of data exists.

### Recalibrating the rating achievements

Quarterly hard resets make the existing rating thresholds unreachable. Measured in clean wins from
1200 at K=16 in four-player games:

| Achievement | Today | Wins needed | New threshold | Wins needed |
|---|---|---|---|---|
| `RANKED` | 1250 | 8 | **unchanged** | 8 |
| `CONTENDER` | 1350 | 25 | **unchanged** | 25 |
| `MASTER` | 1450 | 51 | **1400** | 36 |
| `GRANDMASTER` | 1550 | **92** | **1450** | 51 |
| `THE FLOOR` | ≤ 100 | never | **below 1100 at season close** | reachable |

`GRANDMASTER` at 1550 would need 92 clean wins inside a single quarter — it would have become a
badge nobody could ever earn. `THE FLOOR` had the same problem inverted: the 100 floor is now
unreachable, so it retargets to ending a season under 1100, which a rough quarter genuinely
produces (the simulation puts a 20 %-winner over 40 games at ~1140).

Players who already hold these keep them; unlocks are never revoked.

## 11. What a reset touches — and what it never touches

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

## 12. Testing

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
- **Hit %:** `dartsThrown`/`dartsHit` recorded from a known throw fixture per §8, and a season
  figure summed across several games. A game whose throws were pruned still contributes its
  stored counters — that is the whole reason they are stored.
- **Archive integrity:** closing a season twice does not duplicate its record, and the `all-time`
  row is written exactly once, before season 1's replay.
- **Migration split:** a fixture spanning both sides of 30 June produces two seasons, with the
  June games in season 1 and the July games in season 2, and no game counted in both.
- **Migration idempotency:** running the migration twice leaves exactly the same ratings, seasons
  and archive as running it once. Interrupting it after season 1 and re-running completes season 2
  rather than resetting season 1 again.
- **Backup gate:** the migration refuses to run until an export has completed, and the export
  round-trips — the written JSON decodes back into the same players and history it was built from.
- **Empty history:** migrating with no recorded games produces an empty season 1 rather than
  throwing, and leaves every rating at 1200.
- **Season achievements:** each of the twelve fires on the season row that should trigger it and
  on no other. `NINE AND OUT` fires at exactly 9 games and not at 8 or 10; `DYNASTY` needs the two
  wins to be consecutive; `THE CLIMB` reads the previous season's rank, and does not fire for a
  player who has no previous season.
- **Achievements survive the reset:** a player holding `GRANDMASTER` under the old 1550 threshold
  still holds it after migration and recalibration — unlocks are never revoked.

## 13. Storage caps — a standing constraint

`GameHistoryService` keeps the newest **200** entries and strips throws beyond the newest **100**.
Nothing in this design changes that, and two consequences are load-bearing rather than incidental:

- Season 1 reaches back only as far as history survives (§2).
- Retroactive hit % is partial (§8).

Raising the caps is not part of this work. If it is ever wanted, the export from §6 is the thing
that makes it safe to try.

## 14. Out of scope

- **Per-mode ratings.** Ten ratings in a friend group means ten numbers that all hover near 1200;
  the symptoms are addressed by seasons and rated-mode selection at a fraction of the complexity.
- Any change to the Elo formula, the K values, or the pairwise scaling.
- Season-scoped achievement STATE. The twelve new badges in §10 are triggered by a season
  close but unlock permanently, exactly like every other achievement — no per-season unlock
  table exists.
- **Importing a backup.** The export in §6 is written and shareable; reading one back is the
  obvious next step and deserves its own spec, since a restore has to reconcile ids, seasons and
  achievements rather than blindly overwrite.
- Raising the storage caps (§13).
