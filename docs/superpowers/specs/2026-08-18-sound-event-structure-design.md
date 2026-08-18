# Sound Event Structure — Design

**Date:** 2026-08-18 · **Status:** Approved per-mode by Bjørn (option picker)

## Goal

Expand the sound-event space so Bjørn can drop in sound files for specific
game moments. Folders are silent no-ops until files exist AND the folder is
declared in pubspec.yaml (established convention — see `announceKill`'s doc
comment). This spec defines the structure and the new code hooks.

## Conventions (locked)

- Global events shared by all modes: `assets/sounds/<event>/` — miss, win,
  bust, checkout, triple, bull, slow, nice, six_seven.
- Mode-specific: `assets/sounds/<mode>/<event>/`, snake_case for all NEW
  folders. Existing `positive|negative|offensive/end of round` folders keep
  their names (no renames).
- Every new hook is gated the way its mode's existing sounds are gated
  (meme toggle / chance roll / TTS-idle layering via GameAnnouncer) — no
  ungated `play()` calls (audit 2026-08-10, F1).

## Cleanup (no new sounds, fixes the `play(bust) → failed` log noise)

1. **Move the 15 files** from `assets/sounds/x01/negative/out/` to
   `assets/sounds/bust/` (global) and update pubspec. X01's bust branch
   (`game_screen.dart` ~509) plays `['bust', if offensive 'x01/offensive/end
   of round']` instead of `['x01/negative/out', ...]`.
2. **`announceGameEvent`'s sound side effects move out**: the hardcoded
   `play('bust')` / `play('checkout')` in `game_announcer.dart:88-89` would
   double-play once `bust/` has files (X01 already plays its own gated bust
   sound in the same throw). Remove both lines; give the callers that relied
   on them (find every `announceGameEvent('Bust')` / `('Out')` call site —
   Gotcha at minimum) an explicit, gated bust/checkout sound call instead.
3. Empty hook folders are NOT declared in pubspec until files arrive
   (declaring an empty folder breaks the build). A README line in
   docs listing every hook → folder mapping is the deliverable Bjørn uses
   when adding files.

## New hooks (all code — folders stay empty until Bjørn adds files)

| Mode | Folder | Fires when | Gating |
|---|---|---|---|
| X01 | `x01/one_eighty` | turn total is exactly 180 | meme-gate + markSoundPlayed, plays over generic triple |
| X01 | `x01/sudden_death` | sudden death starts (`_startSuddenDeath`) | game-events gate, TTS-idle |
| Cricket | `cricket/closed` | a number's 3rd mark lands (own close) | meme-gate + chance roll (frequent event) |
| Cricket | `cricket/closed_all` | player closes their last open target | game-events gate, TTS-idle |
| ATC | `around_the_clock/triple_jump` | countMultiples advance of 3 steps in one dart | meme-gate + chance roll |
| ATC | `around_the_clock/final_target` | player arrives at the sequence's last target | game-events gate |
| Killer | `killer/became_killer` | player hits own double and becomes killer | game-events gate, TTS-idle |
| Killer | `killer/self_hit` | killer hits their own number (suicide rule) | game-events gate, TTS-idle |
| Splitscore | `halve_it/halved` | score is halved (round target missed) | game-events gate, TTS-idle |
| Splitscore | `halve_it/clutch` | last dart of the turn saves the halving | game-events gate, TTS-idle |
| Shanghai | `shanghai/shanghai` | instant Shanghai (S+D+T same number) | game-events gate, plays before winner sound |
| Shanghai | `shanghai/hole_cleared` | all 3 darts hit the round's number (not instant-Shanghai) | meme-gate + chance roll |
| Wildcard | `wildcard/rewind` | REWIND fires | game-events gate, layered after 'Joker!' TTS |
| Wildcard | `wildcard/cut` | CUT! fires | same |
| Wildcard | `wildcard/event` | any OTHER instant event fires (SWAP/STEAL/GIFT/…) | same; rewind/cut folders take precedence |
| 1UP | `one_up/last_life` | a player drops to their last life | via existing `announceOneUp(soundFolders:)` |
| 1UP | `one_up/target_set` | "Beat that!" high-target moment | via existing `announceOneUp(soundFolders:)` |

Already-hooked, files-only (no code): `bust/` (after the move), `checkout/`,
`bull/`, `slow/`, `gotcha/kill/`, `one_up/eliminated/`, `one_up/life_lost/`,
`golf/<term>/` (ace = hole-in-one, birdie, …), `golf/sudden_death/`.

Explicitly skipped (Bjørn's picks): `x01/high_finish`, `x01/madhouse`,
`cricket/cutthroat_hit`, `wildcard/joker`, `gotcha/near_target`.

## Testing

Per hook: a screen/service-level test asserting the SoundService call is
made with the right folder at the right event (and NOT on near-miss events),
following each screen's existing test harness. SoundService's logger seam
(`logSound`) or a test double — match whatever the mode's existing sound
tests use.

## Documentation deliverable

`docs/sound-folders.md`: one table — folder → event → status (has files /
awaiting files) — so Bjørn knows exactly where to drop files and what to
declare in pubspec.
