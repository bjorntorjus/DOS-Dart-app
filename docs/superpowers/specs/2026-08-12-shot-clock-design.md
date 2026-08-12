# Shot clock — design (2026-08-12)

**Origin:** players stand at the board talking instead of stepping up to throw, and the evening
drags. Bjørn: "noen blir stående og prate og prate."

**Scope:** a nudge while it is happening, and a count of it afterwards. No rule changes — nobody
loses a turn or a point for being slow.

---

## 1. What is actually measured

**From the moment a turn changes to the moment that player's first dart is registered.**

That is the only window the app can see, and it is exactly the one described: the turn has moved
on, and nobody has thrown yet. It includes walking to the oche, which is fair — walking is part of
taking your turn.

Deliberately **not** measured: the time between darts within a turn. Someone working out a
checkout is doing the game a service, and folding that into the same number would punish thinking
and talking alike.

All ten cockpits already call `GameAnnouncer.announceNextPlayer` on a turn change, so a single
hook covers every mode with no per-mode work.

## 2. Two thresholds, on purpose

| | Value | Why |
|---|---|---|
| **The nudge** | 60 s, adjustable in Settings, **off by default** | Your evening, your setting. An app that nags uninvited is worse than the problem. |
| **The counter** | **fixed 60 s, not adjustable** | A comparable number. If the bar moved with each device's setting, two players' counts would mean different things and the stat would be worthless. |

**The counter runs even when the nudge is off.** That is the one genuinely uncomfortable decision
here and it is made deliberately: turning off the noise should not turn off the scoreboard, or the
number stops being trustworthy the moment anyone wants to look good. It is recorded, not hidden —
the profile shows it plainly.

## 3. The escalation

```
 60 s   TTS speaks the player's name — the same voice that already announces the next player
 90 s   a sting from assets/sounds/slow/
        nothing after that; the point has been made
```

Name first, joke second. A voice saying your name reads as a reminder; leading with a comedy sound
reads as mockery, and the first thing a slow player deserves is a reminder.

The sting reuses the existing meme plumbing (`SoundService.playRandom`), so an empty
`assets/sounds/slow/` folder degrades to silence rather than an error — the feature ships working
before anybody records a sound.

## 4. Edge cases, all of which matter

- **The game's first turn never counts.** People are finding darts, fetching a beer and agreeing
  who starts. Nagging then is unfair, and the number would be polluted by setup on every game.
- **The clock stops** on the turn's first dart, on game end, on undo, when the screen is disposed,
  and while a dialog or overlay is open. Without that last one, an app left on the table collects
  slow turns all night.
- **A turn that never gets a dart** — the player is removed mid-game, or the game ends on someone
  else's checkout — records nothing. There is no turn to be slow in.

## 5. Storage: none is added

A slow turn increments `slowTurns` in the mode's existing `modeCounters` map, which
`StatsRecorder.recordGame` already merges into `SavedPlayer.modeStats`. The profile sums it across
modes.

This is the whole storage design, and it buys three things: no new field on `SavedPlayer`, no
migration, and automatic survival of a season reset — a season boundary writes `rating` and
nothing else, so a counter living in `modeStats` is untouched by construction.

## 6. What the player sees afterwards

`SLOW TURNS` in the PROFILE tab beside the career records, and **`FILIBUSTER`** at 10 slow turns
lifetime — a one-time unlock like every other badge, and a self-deprecating one, which the
catalogue's standing rule asks for.

No match-summary cell and no per-player post-game field. Naming a slowest player on the result
screen every single game would turn a light joke into a nightly verdict.

## 7. Testing

- **The window:** a turn that gets its first dart at 59 s counts nothing; at 61 s it counts one.
  The boundary is asserted on both sides because a fixed threshold is the entire basis of the stat.
- **First turn:** the opening turn of a game records nothing however long it takes.
- **Nudge gating:** with the setting off, no sound and no TTS fire — and the counter still
  increments. That combination is the design's most surprising claim, so it gets its own test.
- **Escalation:** the name fires once at the threshold and the sting once at threshold + 30 s;
  neither repeats if the player keeps stalling.
- **Cancellation:** a dart, a game end, an undo and a dispose each stop the clock, and no timer
  survives the screen. `flutter_test_config.dart` already fails a test that leaves one pending,
  which is the enforcement.
- **Counter plumbing:** a game with two slow turns for one player lands `slowTurns: 2` in that
  player's `modeStats`, and the profile sums two modes into one figure.
- **Achievement:** `FILIBUSTER` fires at 10 and not at 9.

## 8. Out of scope

- Any penalty. No lost turns, no lost points — this is a social game, and a rule that hands out
  punishments would be enforced by an app that cannot see the room.
- A visible countdown in the cockpit. A clock ticking down in front of a thrower is pressure, and
  the request was to stop dawdling, not to add nerves.
- Per-mode slow-turn breakdowns, and any leaderboard of slowness. One number in the profile is
  enough to make the point.
