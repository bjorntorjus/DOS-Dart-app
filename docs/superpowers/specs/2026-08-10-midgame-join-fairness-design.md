# Mid-game join fairness — design (2026-08-10)

**Origin:** tester feedback on Cricket — joining mid-game at the table *average* feels unfair,
because it hands the newcomer a better position than the player who has been struggling all game.
The fair reference point is the player currently in last place.

**Scope:** the mid-game `_addSavedPlayerMidGame` path in all ten modes that support adding a
player during a game. No change to removal, to stats/Elo suppression, or to any scoring rule.

---

## 1. The rule

> **A mid-game joiner is seeded from the active player currently placed last in the mode's own
> ranking — never from the table average.**

Three consequences that make this one rule rather than ten:

- **No new "what is best" logic is written.** Every mode already ranks its players
  (`_computeExitPlacements`, `_buildPlacements`, `GolfEngine.placements()`), and those rankings
  already encode direction. Cricket's comparator even flips for cutthroat today:
  ```dart
  final scoreComp = widget.config.isCutthroat
      ? scores[a].compareTo(scores[b])   // lowest points is best
      : scores[b].compareTo(scores[a]);
  ```
  The join path asks the existing ranking who is last; it does not re-derive "worst".
- **"Last" means last among *active* players.** Eliminated, finished and removed seats are
  excluded. Without this, a Killer joiner would inherit 0 lives and be dead on arrival.
- **When no active player exists** (everyone finished/removed), each mode keeps its current
  default fallback — starting score, 0, or configured lives. Unchanged behaviour.

## 2. Ties: the joiner sorts last, no score is invented

A joiner seeded from last place is, by construction, tied with them. The player who actually
earned last place should not be displaced by someone who just walked up to the board.

**Resolution: seat index becomes the final tiebreaker in every mode's ranking comparator.**
Seats are appended on join, so a joiner always holds the highest index and lands behind anyone
they tie with. No score is fudged, and it works identically in modes where "one point worse" is
meaningless (Killer/1UP: one life less can be zero).

**Correction (2026-08-10, after implementation).** An earlier draft justified this by claiming
`List.sort` is not stable, so tied players would otherwise order arbitrarily. That is true of the
API contract but inert in practice here: Dart falls back to insertion sort below 32 elements, and
insertion sort is stable, so at realistic player counts seat order already survives a tie.
Verified by removing the tiebreak and re-running the tie tests — still green.

The tiebreak is kept anyway, on narrower grounds: it states the invariant explicitly at every
ranking site rather than leaving it to an implementation detail of the sort, and it holds if a
comparator is ever reordered or a list ever grows past the insertion-sort threshold. It is not a
bug fix, and the tie tests are characterization tests, not regression guards — both say so.

**Decision to confirm at review:** shared placement *numbers* on a genuine tie are kept as they
are today. A joiner who catches up over many rounds and finishes genuinely level has earned the
shared rank; only the *ordering* puts them second. At the moment of joining the joiner has thrown
zero darts, so they are listed below the player they were seeded from — which is the visible
behaviour the feedback asked for.

## 3. Per-mode seeding

| Mode | Last place is | Joiner receives | Changed from |
|---|---|---|---|
| X01 | highest remaining score | that remaining score | average remaining |
| Cricket (standard) | lowest points | see §4 | average points + average marks |
| Cricket (cutthroat) | highest points | see §4 | average points + average marks |
| Shanghai | lowest total | that total | average total |
| Gotcha | lowest total | that total | average total |
| Splitscore | lowest total | that total | average total |
| ATC | fewest segments cleared | that player's current target, copied directly | target derived from average remaining |
| Killer | fewest lives (active only) | those lives; random unused number and must-qualify unchanged | average lives |
| 1UP | fewest lives (active only) | those lives | full configured lives |
| Golf | highest stroke total | see §5 | every earlier hole backfilled as PAR |
| WILDCARD | lowest total | that total | always 0 (spec §7.2 — amended, see §6) |

## 4. Cricket: closed numbers stay closed

The joiner copies the last-placed player's **points and per-target marks exactly** — a state that
genuinely exists in the game, explainable at the board as "you start where Per is".

One guard on top. A Cricket number is dead once *every* player has closed it. If the joiner
arrived with the last-placed player's marks on a number that the last-placed player had not
closed but everyone else had, the number would come back to life and the whole table could farm
points on it again — the game's course would change for everyone.

**Guard:** for any target where the engine reports `isClosedByAll(target)` at the moment of
joining, the joiner is given 3 marks regardless of what the last-placed player holds. The number
stays dead, and the joiner is not punished for a target that is out of play anyway.

```
Per   (last):  12 p · 20:✘✘✘  19:✘    18:–
Kari:          45 p · 20:✘✘✘  19:✘✘✘  18:✘✘
             ────────────────────────────────
New player →   12 p · 20:✘✘✘  19:✘    18:–
                      ↑ 20 was closed by all → 3 marks either way
```

## 5. Golf: distribute, do not average

Golf has no single score — it has a scorecard, and earlier holes are currently backfilled as PAR
(3 strokes), which is *better* than a struggling player. The joiner should instead land on the
last-placed player's total.

Naive averaging fails: 22 strokes over 5 holes is 4.4, rounds to 4, totalling 20 — the joiner
ends up **better** than the player they were seeded from, defeating the purpose.

**Distribute the remainder instead.** With `total` strokes over `holes` played:
`base = total ÷ holes`, `remainder = total mod holes`; `remainder` holes get `base + 1`.

```
22 strokes over 5 holes  →  base 4, remainder 2  →  4 · 4 · 4 · 5 · 5 = 22 exactly
```

The total is exact, the joiner is never better than last place, and the scorecard grid shows no
duplicate row. Every distributed value is legal without clamping: a real total over `holes` holes
lies between `holes × 1` and `holes × 6`, so `base` lands in 1–6, and `base + 1` can only reach 7
when `base` is already 6 — which requires an exact `holes × 6` total, where the remainder is zero
and no hole is bumped. A test pins this rather than a runtime clamp.

## 6. WILDCARD: §7.2 amended

WILDCARD's spec currently pins joiners to 0, deliberately rejecting the table average. That rule
was written to avoid the *average*, not to reject a last-place rule that did not exist yet, and
cross-mode consistency is a standing principle. Joiners now follow the same rule as every other
mode. The WILDCARD spec's §7.2 and the code comment at
`lib/screens/wildcard_game_screen.dart:811` are updated to match.

## 7. Where the logic lives

Six modes have engines (Cricket, Shanghai, Gotcha, Golf, 1UP, WILDCARD); four hold their state in
the screen (X01, ATC, Splitscore, Killer). Follow the existing split rather than forcing a
refactor:

- **Engine-backed modes:** the engine grows a `worstActiveSeat()` (or mode-appropriate name) and
  the seeding happens in `addPlayer`, where the roster and undo-history reset already live.
- **Screen-state modes:** a private helper in the screen, next to the existing
  `_addSavedPlayerMidGame`.

Either way the seeding is a **pure function of current state** — testable without a widget, which
is what the per-mode unit tests hook into.

Unchanged in every mode: `_midGamePlayerChanges = true`, `_joinedMidGameIds`, the undo-history
reset (audit 2026-07-06 F8), and the stats/Elo suppression that follows a roster change.

## 8. Testing

- **Per-mode seeding tests** (10): a joiner added to a table with a known spread receives the
  last-placed player's state, not the average. Cricket gets two — standard and cutthroat — to pin
  the direction flip.
- **Cricket dead-number guard:** last place has 1 mark on a target every other player has closed;
  the joiner gets 3 marks and `isClosedByAll` still holds afterwards.
- **Golf distribution:** totals that divide evenly and totals that do not; assert the joiner's
  total equals the last-placed total exactly and every hole is within 1–6.
- **Tie ordering:** a joiner seeded from last place sorts behind them, and the ordering is stable
  across repeated sorts (guards the non-stable `List.sort`).
- **Empty-table fallback:** adding a player when no active players remain uses the mode default
  and does not throw.
- **Killer/1UP floor absence:** last place on 1 life yields a joiner on 1 life — asserted
  deliberately, so a future "be nice to joiners" change has to break a test on purpose.

## 9. Explicitly out of scope

- No floor on inherited lives. Joining a Killer game where everyone is nearly out *is* a bad deal,
  and the rule says so honestly.
- No change to removal, stats suppression, Elo, or any scoring rule.
- No UI work. The `addInfoText` strings shown in the add-player sheet describe the old behaviour
  in some modes and are updated to match, but nothing is redesigned.
