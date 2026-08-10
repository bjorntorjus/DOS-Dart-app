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

**Fix:** bring 1UP to parity — wire `onThrow` and `onTurnEnd` following the pattern the other
eight already use. 1UP's `DartThrow.points` are real turn points, so every meme branch works.

**Golf is the exception, decided during implementation (2026-08-10).** Parity was attempted and
reverted: every path `MemeService` offers is structurally dead in Golf.

- **6-7** needs two consecutive darts on *different* numbers. Every dart in a Golf turn targets
  the same hole, and the turn ends the instant the hole is hit — so the sequence cannot occur.
- **The end-of-round stings and "nice"** both sum `DartThrow.points`, which is a placeholder in
  Golf (it scores strokes, not points — documented in the post-game v2 spec). They would fire on
  a meaningless number.

Wiring the calls anyway would add code that can never trigger while reading as a working feature.
Golf keeps `tryMissSound` only, the reason is a comment in `_onDartHit`, and a test pins the
deviation so it reads as a decision rather than an oversight. If Golf should have memes, it needs
**golf-shaped** ones — an ACE sting, a wash sting — which is new content, not this audit.

### F4 — Meme frequency default lowered 5 → 3

F3 adds meme paths, which works against the original complaint. The compensating lever is the
default frequency: 5 becomes 3.

**Correction (2026-08-10, during implementation).** This section first said "5 (1-in-3) becomes
3 (1-in-5)", copied from `MemeService.frequencyChance`'s own doc comment — which was wrong for
every slider stop except 1 and 10. The real bucketing, read off the code:

```
1 → 1/8    2-3 → 1/6    4-5 → 1/4    6-7 → 1/3    8-9 → 1/2    10 → always
```

So the change is **1-in-4 → 1-in-6**, a slightly deeper cut than promised — in the direction the
feedback asked for. The stale comment is fixed, and a test now pins the whole mapping so the next
reader gets it from an assertion rather than prose. Note also that stops 2 and 3 are identical,
which is why "lower it to 2 instead" would have changed nothing.

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
| Memes on, default frequency | 1-in-4, 8 of 10 modes | 1-in-6, 9 of 10 modes |
| Videos | meme slider × video slider | video slider only |

For a player on defaults with memes on: meaningfully fewer meme sounds per throw, and 1UP stops
being a quiet outlier. For a player with memes off: genuinely off for the first time. Videos get
slightly more frequent at the same slider position, because a gate that was never meant to be
there is gone — the video slider now means what it says.

Golf remains at one meme path by design (see F3).

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
