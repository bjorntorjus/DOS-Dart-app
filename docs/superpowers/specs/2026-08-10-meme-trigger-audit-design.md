# Meme trigger audit — design (2026-08-10)

**Origin:** feedback that there were "too many memes" in the last session, plus a request to verify
that every game mode is actually governed by the meme trigger.

**Scope:** the meme/video gating paths in all ten game screens, `MemeService`, `VideoService` and
the two frequency defaults. No new meme content, no sound assets, no settings-screen redesign.

---

## 1. Audit result: the trigger itself is sound

All ten modes construct a `MemeService` and call `init()`, which reads `meme_enabled` from
`AppSettings`. Both toggle surfaces — the six legacy in-game menus (X01, Cricket, ATC, Killer,
Splitscore, Shanghai) and the shared DOSSEDART cockpit menu (Golf, 1UP, Gotcha, WILDCARD) — write
the same key and call `setEnabled` on the live service. **No mode is outside the trigger.**

Memes default to OFF (`getMemeEnabled() ?? false`). Everything below is about what happens once a
player turns them on, plus two paths that ignore the switch entirely.

## 2. Findings and fixes

### F1 — Two X01 sounds bypass the meme switch

`lib/screens/game_screen.dart:551-557`. A triple on 18/19/20 plays a random `triple` sound, and a
bull plays `bull`, regardless of whether memes are enabled. The bull path uses `play()` rather
than `playRandomMaybe()`, so it has no frequency gate at all — the only sound in the app with no
gate whatsoever.

**Fix:** both are treated as memes. Guard them behind the meme switch and the meme frequency dice,
exactly like every other meme path, and route the bull sound through the same chance gate.

### F2 — Meme frequency secretly drives the video rate

X01, Cricket, ATC and Splitscore pre-roll their video events off the *meme* slider:

```dart
final vc = _meme.frequencyChance;                       // meme slider
final videoRoll = vc <= 1 || Random().nextInt(vc) == 0;
```

`VideoService.shouldPlay` then rolls the real *video* slider on top. Videos are therefore
double-gated, with the meme slider as one of the gates — so turning memes up produces more videos.
The Settings screen presents two independent sliders and implies nothing of the sort.

This is a leftover. The 2026-07-22 video-damping introduced `shouldPlay` as, in its own words,
"the decision seam for every video"; the screen-level pre-roll predates it and was never removed.

**Fix:** delete the meme pre-roll in all four screens. `VideoService.shouldPlay` becomes the only
gate. **Note the direction:** removing a gate layer makes videos slightly *more* frequent than
today at the same slider positions — the video slider now means what it says. The video default
stays at 5; if the next tablet session says videos are too frequent, that slider is the lever.

### F3 — Golf and 1UP reach only one of three meme paths

Both call `tryMissSound()` only. No 6-7 sequence, no "nice" at 69, no end-of-round sounds. Eight
modes have three meme paths; these two have one.

**Fix:** bring both to parity — wire `onThrow` and `onTurnEnd` following the pattern the other
eight already use. Cross-mode consistency is a standing project principle.

Golf needs care: `DartThrow.points` is a placeholder in Golf (documented in the post-game v2
spec), so any meme path that reads points must not be fed Golf's throws as if they were scores.
`onThrow`'s 6-7 check reads `segment`/`multiplier` only and is safe; the `remainingScore` argument
must be left unset, and `onTurnEnd`'s round-score sounds are driven by summed `points` — for Golf,
pass nothing that implies a score total, or skip the round-sound path for that mode. Decide during
implementation and record it in a comment; do not silently feed it garbage.

### F4 — Meme frequency default lowered 5 → 3

F3 adds meme paths, which works against the original complaint. The compensating lever is the
default frequency: 5 (1-in-3 throws) becomes 3 (1-in-5).

```
frequency 5 (today):  1-in-3      frequency 3 (new default):  1-in-5
```

**Only new installations are affected.** `getMemeFrequency()` returns
`prefs.getInt(_memeFrequencyKey) ?? 5` — an existing player who has ever touched the slider has a
stored value and keeps it. A player who never touched it also has no stored value and will drop to
1-in-5, which is the intended outcome.

`frequencyChance` itself is not retuned — the 1..10 → chance mapping stays as it is. Only the
default moves.

## 3. Net effect

| Setting | Before | After |
|---|---|---|
| Memes off | X01 triple + bull still fire | Silent — the switch means off |
| Memes on, default frequency | 1-in-3, 8 of 10 modes | 1-in-5, all 10 modes |
| Videos | meme slider × video slider | video slider only |

For a player on defaults with memes on: fewer meme sounds per throw, but Golf and 1UP stop being
quiet outliers. For a player with memes off: genuinely off for the first time.

## 4. Testing

- **F1:** with memes disabled, a T20 and a bull produce no `SoundService` call. With memes enabled
  at a known frequency, both go through the chance gate.
- **F2:** `VideoService.shouldPlay` is the only video gate — a screen-level test asserting that the
  meme frequency no longer changes how often a video event is raised.
- **F3:** Golf and 1UP each trigger the 6-7 meme and an end-of-turn meme path, matching an existing
  mode's test. Plus a guard that Golf's placeholder `points` never reaches a score-based meme.
- **F4:** `getMemeFrequency()` returns 3 on a clean `SharedPreferences`, and returns the stored
  value when one exists.
- The existing meme-damping behaviour (one miss roll per turn, `markSoundPlayed` suppression) is
  covered today and must keep passing untouched.

## 5. Out of scope

- No new meme sounds or assets.
- No settings-screen redesign; the sliders keep their current labels and ranges.
- The six legacy in-game meme menus are not consolidated into the DOSSEDART cockpit menu. That is
  real duplication, but it belongs to the arcade migration, not to this audit.
