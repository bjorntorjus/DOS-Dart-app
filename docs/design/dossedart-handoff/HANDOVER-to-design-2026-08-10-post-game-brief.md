# Post-game screen — DOSSEDART round (2026-08-10)

**To:** Claude design (DOSSEDART track)
**From:** implementation
**Prerequisites:** the cockpit grammar sheet (`HANDOVER-to-design-2026-07-22-grammar-sheet.md`)
— for tokens, fonts, accents and the always-rendered rule. The 272 px zone budget does NOT bind
here: this is a full screen, not the cockpit overview zone.
**Scope:** `PostGameScreen` — the screen shown when a game ends. **Not** the "Stats" menu section
(`dossedart_stats_screen.dart`), and **not** the KAMPDETALJER drill-down (`game_detail_screen.dart`)
— both already ship in the arcade track and stay as they are.

**Free rein on form.** The zones and the data below are fasit; the layout is yours. This round is
deliberately loose, same as the Golf overview round.

---

## 1. The problem

Two things are wrong with this screen.

**It is the last non-arcade surface in the app.** Setup, cockpit, home, stats and KAMPDETALJER are
all DOSSEDART. Post-game is still classic Material: `AppBar`, `Card`, rounded corners,
`colorScheme` roles. You finish a CRT cockpit and land in a Material list. This round closes that.

**The per-player statistics are a wall of text.** Every mode's stats are joined into a single
string and rendered at 12 px, 70 % opacity, inside a cramped row. Golf today, verbatim:

```
Strokes: 54 (+3) | Aces: 1 | Bogeys: 4 | Best hole: 2 | 1st-dart: 7/18 | Terms: A1 B4 P9 B+4
```

Nothing is scannable, nothing is ranked, and the numbers people actually care about are buried
next to the ones they don't. This is the core design problem — the arcade reskin is the frame
around it.

## 2. What the screen shows today

In order, top to bottom:

| Zone | Today |
|---|---|
| Chrome | M3 `AppBar`, title "Game Over", no back arrow |
| Winner | tonal gradient box: trophy icon 48 px · avatar 36 px radius · name 24 px · "Winner!" |
| Golf scorecard | `GolfScoreGrid` — hole-by-hole table, own horizontal scroll (golf only) |
| Notice | "Statistics not recorded (player list changed mid-game)" (only when roster changed) |
| Placements | one `Card` per player: rank badge · avatar · name · the stat string · Elo delta |
| Chart | `ProgressionChart` under a "SCORE PER ROUND" label, as the list's last item |
| Actions | `↶ Back` + `▶ Continue` side by side · `▶ DETAILS` full width · `Finish Game` full width |

The screen is one fixed `Column` with a single `Expanded` list — the placements scroll, everything
else is pinned. Vertical budget is tight and the action buttons must never be pushed off.

## 3. Zones, prioritised

| Priority | Zone | Notes |
|---|---|---|
| P1 | **Winner moment** | The screen's loudest element. Form is your call — single winner as today, a top-3 podium, or something else. Podium metals are already defined if you go that way: gold = yellow token, silver `#C0C0C0`, bronze. |
| P1 | **Placements — every player** | Rank, name, avatar, the mode's headline number, Elo delta. Must hold 6 players. |
| P2 | **Per-player statistics** | The wall-of-text fix. See §4 for the full data spread. |
| P2 | **Match summary — NEW zone** | Numbers about the *game*, not the players. Does not exist today. See §5. |
| P3 | **Progression chart** | `ProgressionChart` exists and is good — place it, don't redesign it. |
| P3 | **Golf scorecard** | `GolfScoreGrid` exists — place it, don't redesign it. Golf only. |
| P3 | **Actions** | Four buttons, two of them conditional. Must survive the tight vertical budget. |

## 4. The data spread (design for the wave-2 set)

Statistics ship in two waves. **Design for the wave-2 column** — it is planned work, and we would
rather not redo the layout when it lands.

| Mode | Ships today | Wave 2 adds | Total |
|---|---|---|---|
| X01 | Best · Avg · Darts · Out | 100+ / 140+ / 180 counts · checkout-% · first-9 | 7 |
| Cricket | Pts · Closed | MPR · close order | 4 |
| ATC | Reached · Darts | hit-% · streaks | 4 |
| Killer | Lives | kills · deaths · self-hits | 4 |
| Splitscore | Score · Halved | halving losses | 3 |
| Gotcha | Score · Kills · Killed · Busts · Best · Darts | comeback | 7 |
| 1UP | Best · Targets · Lives lost · Turns · Last-dart saves · Rounds won · Elims | target averages | 8 |
| Golf | Strokes ±par · Aces · Bogeys · Best hole · 1st-dart · Terms | — | 6 **+ scorecard grid** |
| Shanghai | Score · Best round · Shanghai! | — | 3 |
| Wildcard | Score · Jokers · Prizes · Stolen · Best · Darts | chaos peak | 7 |

**One framework, not ten screens.** All ten modes share the same widget — the only difference is
which numbers fill the stat block. What has to be solved is the *spread*: 3 fields at the bottom,
8 plus a full scorecard at the top. Demonstrate the grammar under three loads:

- **Light — Splitscore:** 3 fields. Does the screen look empty?
- **Typical — X01 (wave-2 set):** 7 fields. The everyday case.
- **Heavy — Golf:** 6 fields *plus* the hole-by-hole scorecard *plus* the chart. The stress case.

Implementation fills the remaining seven modes into that grammar without another design round, so
the stat block needs a stated rule for ordering and for what happens at each count — not just
three hand-tuned layouts.

Some fields are conditional and hide at zero (`Elims`, `Stolen`, `Rounds won`, `Shanghai!`), so a
mode's field count varies between games. Per the grammar sheet's always-rendered rule, decide
whether these dim in place or genuinely disappear, and say which on the spec card.

## 5. Match summary (new zone)

Game-level numbers, verified as available in the data we already hold:

| Number | Source | Availability |
|---|---|---|
| Duration | `_gameStart` → `durationSeconds` | All 10 modes |
| Rounds played | `DartThrow.roundNumber` | Where `throwHistory` is passed |
| Total darts thrown | `throwHistory.length` | Where `throwHistory` is passed |
| Best turn of the match + who threw it | group by `turnId`, sum points | Where `throwHistory` is passed |
| Hit distribution (triples / doubles / bulls / misses) | `segment` + `multiplier` | Where `throwHistory` is passed |
| Biggest lead | progression series | **8 of 10 modes** — 1UP and Killer have no series yet |

**Design a degraded state for this zone.** `throwHistory` is deliberately suppressed whenever the
roster changed mid-game (the chart lines index by seat and would mislabel), so on those games only
*duration* survives. The same games also show the "statistics not recorded" notice and hide
`▶ DETAILS`. That combination — arcade winner moment, full placements, but a nearly empty match
zone and a warning — is a real state and needs to be on an artboard.

## 6. Stress states (each on an artboard)

- 6 players in the placements
- A long name (> 16 chars) in both the winner moment and the placements
- A tie — shared placement numbers (two players both ranked 2)
- Roster changed mid-game: notice shown · no chart · no `▶ DETAILS` · match zone degraded
- Wildcard: no Elo at all (the mode never rates), so the delta column is empty for every player
- Golf: 18 holes on the scorecard, one player with a 6-stroke wash

## 7. Reuse — do not redesign

- `ProgressionChart` (`lib/widgets/dossedart/progression_chart.dart`) — already arcade, already
  approved. Place it, size it, label it; leave its internals alone.
- `GolfScoreGrid` (`lib/widgets/dossedart/golf/golf_scorecard.dart`) — the same grid the in-game
  SCORECARD sheet uses. Owns its own horizontal scroll.
- `DossedartCrtFrame`, `DossedartTopBar`, `DossedartPlayerAvatar` — screen chrome, verbatim.
- Player accents from the 5-accent cycle (grammar sheet rule 7), including in demo data.
- KAMPDETALJER (`game_detail_screen.dart`) behind `▶ DETAILS` — this is where depth already lives.
  Post-game answers "who won, how did I do, do I want to press DETAILS?" It does not have to be
  exhaustive.

## 8. Division of labor

- **Design owns:** the artboards and the spec cards (fasit), including the stat-block ordering
  rule and the zone budget in px @ 820 × 1180.
- **Implementation owns:** all stat computation, the wave-2 counters, widget rewrites, Elo rules,
  tests. The wave-2 numbers do not exist yet — they are implementation work triggered by this
  design, not something the artboard needs to source.
- **New functionality is PROPOSAL-only** — mark it on the spec card, parked by default, never
  woven silently into the fasit. Same protocol as previous rounds.

## 9. Format & constraints

- Deliverable: **HTML artboards + spec cards as fasit**, JSX optional. Same bundle format as
  previous DOSSEDART handoffs.
- Target: tablet, 820 × 1180 portrait, dark arcade theme.
- **DOSSEDART tokens only** (`lib/theme/dossedart_tokens.dart`, incl. lime `#C6FF3C`). No raw hex,
  no Material `colorScheme` roles. Podium silver `#C0C0C0` is the one carried-over exception if a
  podium is designed.
- `Press Start 2P` / `VT323`. No border-radius.
- All UI strings **English** (a guard test fails the build on Norwegian strings).
