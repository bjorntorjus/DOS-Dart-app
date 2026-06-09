# DOSSEDART Achievements — Candidate Catalog (raw, for triage)

> Working artifact, **not** the spec. Generated 2026-06-09 by 5 parallel subagents that each
> read the real engines/screens/stats so every trigger is mechanically grounded. ~245 candidates.
> Decision rule (Bjørn): propose freely, then **we triage by tracking cost**. Each row is tagged:
> `EXISTING` = computable from data already tracked (cheap, ship now) · `NEW` = needs new tracking.

## Triage summary

- **~95 are `EXISTING`** — buildable with zero model/engine changes. These are the v1 "free wins".
- **~150 are `NEW`** — but they cluster around a handful of cheap additions that each unlock many:
  - **Per-turn aggregator** (marks/triples/bulls/points this turn) → unlocks ~20 across X01/Cricket/Shanghai/Splitscore.
  - **Per-leg / finishing-dart capture** in X01 (reconstructable from `throwHistory` at game-end) → ~10.
  - **Win/loss-streak fields** on `SavedPlayer` → ~10 across modes + cross-cutting.
  - **Meme-trigger counters** (69 "nice", 6-7) — currently fire-and-forget → ~3.
  - **Per-game flags** (comeback/deficit, no-bust, on-one-life, instant-Shanghai, no-halving) computed at record time → ~30.
  - **Opponent end-state snapshot** (shutouts, margins, regicide) → ~15.
  - The expensive tail (per-round leader history, revenge/last-attacker, distinct-play-days) → the rest.

---

## Cross-cutting / career / ELO / social / quirky

| Name | Tier | Trigger | Data |
|---|---|---|---|
| ROOKIE | bronze | Finish your first game (any mode) | EXISTING: gamesPlayed>=1 |
| REGULAR | bronze | Play 25 games total | EXISTING: gamesPlayed>=25 |
| GRINDER | silver | Play 100 games total | EXISTING: gamesPlayed>=100 |
| VETERAN | gold | Play 250 games total | EXISTING: gamesPlayed>=250 |
| ARCADE RAT | gold | Play 500 games total | EXISTING: gamesPlayed>=500 |
| FIRST BLOOD | bronze | Win your first game (any mode) | EXISTING: gamesWon>=1 |
| WINNER WINNER | silver | Win 25 games total | EXISTING: gamesWon>=25 |
| CENTURION | gold | Win 100 games total | EXISTING: gamesWon>=100 |
| HALF-DECENT | silver | 50% career win rate (min 20 games) | EXISTING: winRate>=0.5 & played>=20 |
| SHARK | gold | 70% career win rate (min 30 games) | EXISTING: winRate>=0.7 & played>=30 |
| DABBLER | bronze | Play 3 different modes | EXISTING: modeStats.keys>=3 |
| DECATHLETE | silver | Play every mode (all 6) | EXISTING: modeStats covers all |
| JACK OF ALL | gold | Win in every mode (all 6) | EXISTING: every mode won>=1 |
| MODE MAIN | bronze | Play 30 games in one mode | EXISTING: any ModeStats.played>=30 |
| RANKED | bronze | Cross 1250 ELO | EXISTING: rating>=1250 |
| CONTENDER | silver | Cross 1350 ELO | EXISTING: rating>=1350 |
| MASTER | gold | Cross 1450 ELO | EXISTING: rating>=1450 |
| GRANDMASTER | gold | Cross 1550 ELO | EXISTING: rating>=1550 |
| THE FLOOR | bronze | Bottom out at 100 rating (humbling) | EXISTING: rating<=100 |
| BIG JUMP | silver | Gain 20+ rating in one game | EXISTING: GameHistory ratingAfter-ratingBefore |
| GIANT SLAYER | gold | Beat opponent rated 200+ higher | NEW: compare ratingsBefore at record |
| TOP DOG | silver | Reach rank #1 among saved players | EXISTING: RatingSnapshot.placement==1 |
| DETHRONER | gold | Take #1 from previous holder | NEW: track previous #1 id |
| HOT START | bronze | Win 3 in a row (any mode) | NEW: currentWinStreak |
| ON FIRE | silver | Win 5 in a row | NEW: currentWinStreak>=5 |
| UNSTOPPABLE | gold | Win 10 in a row | NEW: currentWinStreak>=10 |
| COLD STREAK | bronze | Lose 5 in a row (loser badge) | NEW: currentLossStreak>=5 |
| PHOENIX | silver | Win right after a 5+ losing streak | NEW: lossStreak>=5 then win |
| RIVALRY | bronze | Beat same opponent 5 times | EXISTING: H2H.wins>=5 |
| NEMESIS | silver | Beat same opponent 15 times | EXISTING: H2H.wins>=15 |
| PUNCHING BAG | bronze | Lose to same opponent 10 times | EXISTING: H2H.losses>=10 |
| SOCIAL BUTTERFLY | silver | Beat 5+ different opponents | EXISTING: H2H entries with wins>=1 |
| PARTY HOST | silver | Finish a game with 4+ players | EXISTING: GameHistory players.length |
| DEDICATED | bronze | Play on 5 different days | NEW: distinct play-dates |
| COMMITTED | silver | Play on 20 different days | NEW: distinct play-dates>=20 |
| DAILY DOUBLE | bronze | Play 3 consecutive days | NEW: consecutive-day streak |
| NIGHT OWL | bronze | Finish a game 00:00–04:00 | NEW: DateTime.now().hour at record |
| NICE. | bronze | Trigger the 69 "nice" meme | NEW: niceCount (meme fire-and-forget today) |
| SIX SEVEN | bronze | Trigger the 6-7 meme | NEW: counter on meme fire |
| ALMOST | bronze | Finish 2nd place 10 times (loser) | NEW/EXISTING: placement==2 count from history |
| QUITTER | bronze | Leave 5 games midway (cheeky) | EXISTING: gamesLeftMidway>=5 |
| SUBSTITUTE | bronze | Join 5 games midway | EXISTING: gamesJoinedMidway>=5 |

## X01

| Name | Tier | Trigger | Data |
|---|---|---|---|
| Ton Up | bronze | Score 100+ in a 3-dart turn | EXISTING: turnsOver100 / per-game highestTurn |
| Ton-Forty | silver | Score 140+ in a turn | EXISTING: max:highestTurn>=140 |
| Maximum | gold | Score 180 in a turn | EXISTING: max:highestTurn==180 |
| Three In The Black | silver | 3 bulls in one turn | NEW: per-turn bull count |
| Treble Trouble | silver | 3 trebles in one turn | NEW: per-turn triple count |
| Low Ton | bronze | Turn total in 100–104 | NEW: per-turn total band |
| The Madhouse | silver | Check out on D1 (finish from 2) | NEW: finishing dart S1 D |
| Bullseye Finish | gold | Win leg on D-Bull | NEW: finishing dart seg25 mult2 |
| Big Fish | gold | Check out from 170 | EXISTING: max:bestCheckout==170 |
| Ton-Plus Checkout | silver | Check out from 100+ | EXISTING: max:bestCheckout>=100 |
| Double Double | silver | Checkout turn uses two doubles | NEW: checkout-turn multipliers |
| One Dart Wonder | silver | Check out with a single dart | NEW: dartsUsedInTurn==1 on finish |
| The Perfect Leg | gold | 501 in 9 darts (301 in 6) | NEW: per-leg winner dart count |
| Speed Demon | silver | Win a 501 leg in <=15 darts | NEW: per-leg dart count<=15 |
| Surgeon | silver | Win a game without busting | NEW: per-game bust count==0 |
| Bust Magnet | bronze | Bust 3 times in a game (self-deprecating) | NEW: per-game bust count>=3 |
| No Mercy | gold | Win w/ opponent never below 100 | NEW: opponents' min score |
| Comeback Kid | silver | Win after trailing leader by 150+ | NEW: deficit-while-behind |
| Houdini | gold | Win after trailing by 250+ | NEW: max deficit |
| Sniper | silver | 5+ trebles in a game | EXISTING: per-game triplesHit>=5 |
| Eagle Eye | silver | 5+ bulls in a game | EXISTING: per-game bullsHit>=5 |
| Robin Hood | gold | T20 ten times in a game | EXISTING: per-game seg_20_t>=10 |
| Iceman | silver | Win a sudden-death tiebreak | NEW: flag sudden-death win |
| Nice | bronze | Leave exactly 69 | EXISTING: detected in MemeService |
| Whiff | bronze | 3 misses in a turn | EXISTING: three_misses detected |
| Sub-Ten Club | bronze | Finish a turn with <10 total | EXISTING: low_round fires |
| The Grinder | bronze | Play 10 X01 games | EXISTING: x01.played>=10 |
| Centurion (X01) | silver | Play 100 X01 games | EXISTING: x01.played>=100 |
| Ton of Tons | silver | 100+ turn 100 times (career) | EXISTING: career turnsOver100>=100 |
| Maximum Overdrive | gold | 10 career 180s | NEW: career 180 counter |
| Checkout Artist | silver | 50 career checkouts | EXISTING: career checkouts>=50 |
| Double Trouble | silver | 100 career doubles | EXISTING: career doublesHit>=100 |
| Treble Tycoon | gold | 500 career trebles | EXISTING: career triplesHit>=500 |
| Marksman | silver | Career 3-dart avg>=60 (>=20 games) | EXISTING: totalTurnScore/totalTurns |
| Pro Tour | gold | Career 3-dart avg>=80 (>=50 games) | EXISTING: totalTurnScore/totalTurns |
| Hat Trick | bronze | Win 3 X01 in a row | NEW: x01 win streak |
| Dynasty | gold | Win 10 X01 in a row | NEW: x01 win streak |
| Triple Crown | silver | Win 701, 501 & 301 at least once | NEW: per-startingScore win flags |
| Mr. Consistent | silver | 100+ in 3 consecutive turns | NEW: consecutive turn totals |
| Heatwave | gold | 140+ in 3 consecutive turns | NEW: consecutive turn totals |
| Lights Out | gold | 180 then check out next turn | NEW: 180-then-finish detection |
| Perfectionist | gold | Win a game with zero misses | EXISTING: per-game misses==0 |

## Cricket

| Name | Tier | Trigger | Data |
|---|---|---|---|
| First Blood (Cri) | bronze | Close your first-ever number | EXISTING: career closedTargets>0 |
| Hat Trick (Cri) | bronze | 3 marks in a turn | NEW: per-turn marks |
| Six Shooter | silver | 6 marks in a turn | NEW: per-turn marks>=6 |
| The Nine | gold | 9 marks in a turn (3 triples) | NEW: per-turn marks==9 |
| Trip Trip | bronze | 2 triples in a turn | NEW: per-turn triple count |
| One And Done | silver | Close a number 0→3 in one turn | NEW: per-turn target 0→3 |
| Triple Threat (Cri) | bronze | Close a number with one triple | NEW: per-dart prior-marks 0 + mult3 |
| Sweep The Board | gold | Close 3 numbers in one turn | NEW: per-turn closes==3 |
| Bull Rush | bronze | Close the Bull | NEW: per-game Bull closed |
| Double Bull Snap | silver | Close Bull with one D-Bull | NEW: per-dart seg25 mult2 prior0 |
| Eye Of The Storm | silver | 3 bulls in one turn | NEW: per-turn seg25 count==3 |
| Closer | bronze | Win a standard Cricket game | EXISTING: cricket.won |
| Throat Cutter | bronze | Win a Cutthroat game | EXISTING: cricket_cutthroat.won |
| Clean Sheet | silver | Win standard conceding 0 points | NEW: per-game winner score==0 |
| Shutout | gold | Win w/ an opponent closing zero numbers | NEW: opponent closedTargets==0 |
| Land Grab | silver | Close all before any opponent opens one | NEW: end-state compare |
| Point Dumper | bronze | Cutthroat: dump 40+ in a turn | NEW: per-turn cutthroat points dealt |
| Mass Casualty | silver | Cutthroat: dump 100+ in a turn | NEW: per-turn dealt>=100 |
| Backstabber | gold | Cutthroat win, all opp >=50 pts, 3+ players | NEW: end-state compare |
| Efficient | bronze | Game MPR>=2.0 | NEW: per-game MPR |
| Sharp Shooter | silver | Game MPR>=3.0 | NEW: per-game MPR |
| Machine | gold | Game MPR>=4.0 | NEW: per-game MPR |
| No Wasted Darts | silver | Game with 0 misses (min 18 darts) | EXISTING: per-game misses==0 |
| Speed Closer | gold | Win 2p standard in <=8 rounds | NEW: winner round count |
| Marksman (Cri) | bronze | 50 career marks | EXISTING: career marksScored>=50 |
| Mark Hunter | silver | 500 career marks | EXISTING: marksScored>=500 |
| Mark Lord | gold | 2000 career marks | EXISTING: marksScored>=2000 |
| Demolition Crew | bronze | Close 50 career numbers | EXISTING: closedTargets>=50 |
| Wrecking Ball | silver | Close 250 career numbers | EXISTING: closedTargets>=250 |
| Total Domination | gold | Close 1000 career numbers | EXISTING: closedTargets>=1000 |
| Veteran Closer | silver | Win 25 Cricket games (both variants) | EXISTING: cricket+cutthroat won>=25 |
| Comeback Kid (Cri) | gold | Win after trailing 40+ at final turn | NEW: deficit flag |
| Goose Egg | bronze | Full turn, 0 marks 0 points | NEW: per-turn marks0 points0 |
| Iron Wall | silver | Close your last number on the winning turn | NEW: per-game flag |
| Perfectionist (Cri) | gold | Win with MPR>=3 and 0 misses | NEW: per-game combine |

## Around the Clock (ATC)

| Name | Tier | Trigger | Data |
|---|---|---|---|
| First Tick | bronze | Finish the full sequence once | EXISTING: finished>=1 |
| Clockwork | bronze | Win your first ATC game | EXISTING: aroundTheClock.won>=1 |
| Half Time | bronze | Reach target >=11 in one game | EXISTING: per-game reached>=11 |
| Sharpshooter (ATC) | silver | Finish w/ hit-rate>=70% | EXISTING: totalHits/totalDarts |
| No Wasted Darts (ATC) | silver | Finish with zero misses | EXISTING: misses==0 & finished |
| Speed Run | silver | Finish in <=30 darts | EXISTING: totalDarts when finished |
| Lightning Round | gold | Finish 20-seg in <=24 darts | EXISTING: totalDarts |
| Triple Threat (ATC) | silver | Advance 3 segments with one dart | NEW: per-game tripleJump flag |
| Double Step | bronze | Advance 2 segments with one dart | NEW: doubleJump flag |
| Leapfrog | gold | Finish via multi-jumps in <=12 darts | NEW: multiJumpFinish + totalDarts |
| Hot Streak (ATC) | silver | 5+ consecutive on-target darts | NEW: max:hitStreak |
| Flawless Run | gold | Finish hitting target on every dart | EXISTING: totalDarts/misses/finished |
| Photo Finish (ATC) | silver | Win via sudden death | NEW: wonInSuddenDeath flag |
| Backwards Brain | bronze | Win a reverse game | NEW: wonReverse flag |
| Dominator | silver | Win w/ runner-up >=5 segments left | NEW: opponents' remaining at win |
| Clean Sweep (ATC) | gold | Finish before any opponent finishes one | NEW: opponents' finished state |
| Clock Veteran | bronze | Play 10 ATC games | EXISTING: played>=10 |
| Clock Master | silver | Win 25 ATC games | EXISTING: won>=25 |
| Timelord | gold | Win 100 ATC games | EXISTING: won>=100 |
| Marathon Darts | silver | 1000 career ATC darts | EXISTING: career totalDarts>=1000 |
| Bricklayer (ATC) | bronze | 3 consecutive misses in a game | EXISTING: _consecutiveMisses>=3 → flag |
| Bull Whisperer | silver | Finish Bull game on a D-Bull | NEW: finishedOnDoubleBull |

## Killer

| Name | Tier | Trigger | Data |
|---|---|---|---|
| Armed and Dangerous | bronze | Become Killer for the first time | NEW: becameKiller flag |
| First Blood (Kil) | bronze | First career kill | EXISTING: career kills>=1 |
| Survivor | bronze | Win your first Killer game | EXISTING: killer.won>=1 |
| Quick Draw | silver | Become Killer on your first turn | NEW: dartsToArm |
| One-Dart Wonder | silver | Become Killer with first dart | NEW: dartsToArm==1 |
| Double Kill | silver | Eliminate 2 in one turn | NEW: max:killsInTurn |
| Killing Spree | gold | Eliminate 3+ in one turn | NEW: max:killsInTurn>=3 |
| Triple Tap | silver | Deal a 3-damage hit (treble, multiplyHits) | NEW: tripleDamageHit flag |
| On The Brink | silver | Win after dropping to exactly 1 life | NEW: wasOnOneLife flag |
| Phoenix (Kil) | gold | Win from 1 life w/ all opponents alive | NEW: flag |
| Untouchable | silver | Win without losing a life | EXISTING: attacksReceived/selfHits/livesLeft |
| Wall of Shields | bronze | Hold 3+ shields at once | NEW: max:maxShieldsHeld |
| Bulletproof | silver | Shield absorbs a kill at 1 life | NEW: shieldSavedLife flag |
| Regicide | gold | Land the eliminating dart on the leader | NEW: leader-at-kill tracking |
| Revenge | silver | Eliminate the player who last hit you | NEW: last-attacker tracking |
| Giant Slayer (Kil) | gold | Eliminate a player rated 150+ above you | NEW: rating compare at kill |
| Self-Destruct | bronze | Self-eliminate as Killer (quirky) | NEW: selfEliminated flag |
| Friendly Fire | bronze | Lose a life to your own number | EXISTING: per-game selfHits>=1 |
| Pacifist Win | gold | Win with 0 kills credited | EXISTING: per-game kills==0 + won |
| Sniper (Kil) | silver | 50 career attacksDealt | EXISTING: attacksDealt>=50 |
| Executioner | gold | 50 career kills | EXISTING: kills>=50 |
| Shield Hoarder | silver | 30 career shieldsGained | EXISTING: shieldsGained>=30 |
| Killer Veteran | bronze | Play 10 Killer games | EXISTING: played>=10 |
| Reaper | gold | Win 50 Killer games | EXISTING: won>=50 |
| Rampage | gold | Win 5 Killer in a row | NEW: win streak |

## Shanghai

| Name | Tier | Trigger | Data |
|---|---|---|---|
| First Blood (Sha) | bronze | Win your first Shanghai game | EXISTING: shanghai.won>=1 |
| Hat Trick (Sha) | bronze | Hit S+D+T target in one turn (full Shanghai turn) | NEW: per-turn S/D/T completion |
| Clean Sweep (Sha) | bronze | A turn with all 3 darts on target | NEW: no-miss turn |
| INSTANT SHANGHAI! | gold | Win via instant Shanghai | NEW: persist isInstantShanghai win |
| Ton of Bricks | silver | 100+ total points in a game | EXISTING: max:bestScore>=100 |
| Double Century | gold | 200+ total points in a game | EXISTING: max:bestScore>=200 |
| Round Raider | silver | 60+ points in one round | NEW: max:bestTurnScore |
| Flawless Run (Sha) | silver | Win hitting target in every round | NEW: per-game flag |
| Untouchable (Sha) | gold | Win with zero misses all game | NEW: per-game miss count==0 |
| Landslide | silver | Win by 50+ points | NEW: winner margin |
| Blowout | gold | Win by 100+ points | NEW: winner margin |
| Photo Finish (Sha) | silver | Win non-instant by <=3 points | NEW: winner margin |
| Comeback Kid (Sha) | silver | Win after last entering final round | NEW: rank at final round |
| From the Ashes | gold | Win after trailing 40+ at final round | NEW: gap at final round |
| Shut Out | gold | Win w/ all opponents < half your total | NEW: end-state compare |
| Zero Hero | bronze | A full turn with 3 misses (quirky) | NEW: all-miss turn |
| Veteran (Sha) | silver | Play 25 Shanghai games | EXISTING: played>=25 |
| Shanghai Legend | gold | Play 100 Shanghai games | EXISTING: played>=100 |
| Serial Winner (Sha) | gold | Win 50 Shanghai games | EXISTING: won>=50 |
| Treble Addict | silver | 50 career trebles-of-round | NEW: career counter |
| Lucky Number | bronze | Instant Shanghai on number 7 (quirky) | NEW: record instant target |

## Splitscore (Halve It)

| Name | Tier | Trigger | Data |
|---|---|---|---|
| First Win (Spl) | bronze | Win your first Splitscore game | EXISTING: halveIt.won>=1 |
| Survivor (Spl) | bronze | Finish a game without being halved | NEW: per-game halvings==0 flag |
| Untouched | gold | WIN with zero halvings | NEW: per-game halvings==0 & won |
| Perfect Card | gold | Hit target in every round | NEW: per-game roundsHit==totalRounds |
| Clutch Save | bronze | Hit on 3rd dart after 2 misses (avoid halve) | NEW: detect last-dart save |
| Last-Dart Hero | silver | Clutch save in a double/triple round | NEW: clutch-save + round type |
| High Roller | silver | 60+ points in one round | EXISTING: max:bestRound>=60 |
| Triple Threat (Spl) | gold | 120+ points in one round | EXISTING: max:bestRound>=120 |
| Triple Sweep | gold | 3 triples in an "any triple" round | NEW: per-turn type tracking |
| Double Down | silver | 3 doubles in an "any double" round | NEW: per-turn type tracking |
| Bullseye Bonanza | silver | 3 bulls in a bull round | NEW: per-turn type tracking |
| Phoenix (Spl) | silver | Win after being halved once | NEW: won & halvings>=1 |
| Rise from Ruin | gold | Win after being halved 2+ times | NEW: won & halvings>=2 |
| Heartbreaker | bronze | Halved from 80+ in one round | EXISTING: max:biggestHalving>=40 |
| Total Collapse | silver | Halved in 3+ rounds (quirky) | NEW: per-game halvings>=3 |
| Ice Cold | gold | Win, never halved, hit every target | NEW: per-game combine |
| Sniper (Spl) | silver | Hit rate>=80% in a game | NEW: per-game roundsHit/totalRounds |
| Veteran (Spl) | silver | Play 25 Splitscore games | EXISTING: played>=25 |
| Splitscore Legend | gold | Play 100 Splitscore games | EXISTING: played>=100 |
| Hit Machine | silver | 200 career target rounds | EXISTING: career roundsHit>=200 |
| Serial Winner (Spl) | gold | Win 50 Splitscore games | EXISTING: won>=50 |

---

## Open questions for the spec (to decide with Bjørn)

1. **v1 scope** — ship all `EXISTING` now and stage `NEW` later, or pick a curated set across both?
2. **Retro-counting** — do existing career stats count toward unlocks on day 1 (e.g. someone with 1200 rating instantly gets RANKED), or only count from feature launch forward?
3. **Per-player** — achievements are per `SavedPlayer` (guests don't earn). Confirm.
4. **Reward** — cosmetic only, or any in-app effect? (design left open)
5. **Tier visual** — bronze/silver/gold hex medal confirmed; glyph source per badge?
