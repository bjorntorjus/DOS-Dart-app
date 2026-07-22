# Achievement Memes — Design Spec

**Date:** 2026-07-01
**Status:** Draft for review
**Author:** Bjørn + Claude

## Goal

Attach short meme clips (video/GIF) or images to a curated set of achievements,
so that unlocking a marquee achievement plays a fitting meme. Content is a mix of
well-known internet memes (base) and AI-generated "bad low-poly bowling" clips for
the app-specific dart moments that no generic meme covers.

## Non-goals

- Memes on all 85 achievements. Only a curated subset (12 in wave 1).
- New settings UI beyond reusing the existing meme toggle + frequency slider.
- Changing how achievements are detected/unlocked. We only *react* to unlocks.
- Replacing the existing event-videos (bust / low_round / high_round / winner).

## Background — what already exists

The plumbing is largely in place:

- **`VideoService`** (`lib/services/video_service.dart`) plays fullscreen MP4/GIF
  overlays from `assets/videos/<folder>/` via `showRandomFromFolder()`. Gated by the
  **`video_events_enabled`** setting (default **on**).
- **`MemeService`** (`lib/services/meme_service.dart`) plays *audio* memes (6-7, 69,
  round-sounds). Gated by **`meme_enabled`** (default **off**) + a **frequency slider**
  (1–10 → 1-in-X chance via `frequencyChance`).
- **Achievement unlocks** emit on `AchievementService.instance.unlocks`, and
  `AchievementBanner` (`lib/widgets/dossedart/achievement_banner.dart`) already shows a
  non-blocking top banner with **player name + achievement name + tier**.
- Two unlock paths: **event-driven** (`checkEvent`, mid-game, e.g. 180) and
  **milestone** (`evaluateMilestones`, at game end, e.g. career thresholds).

**Key clarification for the user's question:** the videos seen "even when memes are off"
are **event-videos** controlled by the separate **"Video events"** toggle (Settings →
Sound & Video), which defaults **on**. They are unrelated to the meme toggle. This is
working as designed, not a bug.

## Decisions (locked)

| Topic | Decision |
|---|---|
| Content source | Mix: real internet memes as base; AI low-poly bowling for app-specific dart moments |
| Master gate | Achievement memes respect the **`meme_enabled`** toggle (NOT `video_events_enabled`) |
| Frequency | Pure slider-gating (1-in-X), same `frequencyChance` as other memes — applied to achievement memes too |
| Scope wave 1 | 12 curated achievements (6 event-driven + 6 milestone) |
| Collision | **Event-video always wins.** If an event-video played this turn, the achievement shows banner only (no meme). No exceptions. |
| Who/what clarity | Existing banner (player + name) covers it mid-game; result screen covers milestones |

### Consequence of the collision rule (accepted)

A 180 always triggers the `high_round` event-video (100+ is always true), so
**MAXIMUM's meme will in practice never play** — the bowling video pre-empts it and only
the banner shows. Achievement memes therefore shine on moments *without* an event-video:
the milestones, CLUTCH SAVE, KILLING SPREE, THE NINE, INSTANT SHANGHAI. This is accepted
as the intended, tidy division of labour.

## Wave 1 achievement → meme mapping

Content direction per item: **[real]** = source a known internet meme clip/GIF;
**[AI]** = generate an app-specific low-poly bowling clip (prompts in the appendix).

### Event-driven (mid-game; fullscreen meme only if no event-video collided)

| id | Name | Trigger | Content |
|---|---|---|---|
| `cri_the_nine` | THE NINE | 9 marks in one turn | **[AI]** dart-specific hype |
| `sha_instant` | INSTANT SHANGHAI | single+double+treble instant win | **[AI]** dart-specific hype |
| `kil_killing_spree` | KILLING SPREE | 3+ eliminations in one turn | **[real]** "unstoppable / rampage" clip |
| `spl_clutch_save` | CLUTCH SAVE | avoid halving with final dart | **[real]** "phew / clutch" reaction |
| `x01_maximum` | MAXIMUM | 180 in one turn | **[AI]** — see note: rarely plays (collision) |
| `x01_bullseye_finish` | BULLSEYE FINISH | win a leg on the bull | **[AI]** — may collide with `winner` |

### Milestone (post-game; plays on result screen)

| id | Name | Trigger | Content |
|---|---|---|---|
| `x_natural_talent` | NATURAL TALENT | win the very first game you play | **[real]** "beginner's luck" clip |
| `x_grandmaster` | GRANDMASTER | cross 1550 rating | **[real]** "elite / crown" clip |
| `x_giant_slayer` | GIANT SLAYER | beat opponent rated 200+ above | **[real]** "David vs Goliath / upset" clip |
| `x_unstoppable` | UNSTOPPABLE | win 10 in a row | **[real]** "on fire / domination" clip |
| `x_the_floor` | THE FLOOR | bottom out at 100 rating | **[real]** self-deprecating "rock bottom" clip |
| `x_cold_streak` | COLD STREAK | lose 5 in a row | **[real]** "sad / defeat" clip |

The user may still add/remove items (candidates raised: `x01_big_fish` 170-checkout,
`x_punching_bag`, `sha_legend`). The mapping is data, not code, so edits are cheap.

## Architecture

### 1. Data — attach a meme folder to an achievement

Add one optional field to `Achievement` (`lib/models/achievement.dart`):

```dart
/// Folder under assets/videos/achievements/ holding this achievement's meme
/// clip(s). Null = no meme. When set, a random file from the folder plays on
/// unlock (subject to the meme toggle + frequency + collision rules).
final String? memeFolder;
```

Populate it in the catalog for the 12 wave-1 entries, e.g.
`memeFolder: 'the_nine'` on `cri_the_nine`.

### 2. Assets

```
assets/videos/achievements/
  the_nine/
  instant_shanghai/
  killing_spree/
  clutch_save/
  maximum/
  bullseye_finish/
  natural_talent/
  grandmaster/
  giant_slayer/
  unstoppable/
  the_floor/
  cold_streak/
```

Each folder holds 1+ `.mp4`/`.gif` files; the app picks one at random (reusing the
existing `showRandomFromFolder` file-pick logic). Declare each folder in `pubspec.yaml`
under `assets:` following the existing pattern. Empty folders are safe — playback falls
back silently, so we can wire the code before all content exists.

### 3. Playback path — a meme-gated entry point

Achievement memes are **memes**, so they must NOT go through the `video_events_enabled`
gate. Add a dedicated method to `VideoService` that gates on meme settings instead:

```dart
/// Plays a random meme clip for an unlocked achievement.
/// Gated by meme_enabled + the meme frequency slider (pure slider-gating).
/// Returns true if a clip actually played.
Future<bool> showAchievementMeme(BuildContext context, String folder);
```

Internally it reuses the folder-pick + `VideoOverlay` mechanics of
`showRandomFromFolder`, but checks `AppSettings.getMemeEnabled()` and applies
`frequencyChance` (1-in-X) rather than the `video_events` flag. The meme-enabled state
is cached the same way `VideoService._enabled` is (read in `init()`, updated when the
setting changes).

### 4. Wiring — where memes fire

**Event-driven (mid-game):** In the game-end/turn-end orchestration in
`game_screen.dart` where `checkEvent`/event-videos already run:

1. Evaluate event-videos as today. Track whether one played this turn
   (`showVideo`/`showRandomFromFolder` return a bool, or a local `bool eventVideoPlayed`).
2. For each newly-unlocked achievement with a `memeFolder`: if **no** event-video played
   this turn, call `showAchievementMeme(context, achievement.memeFolder!)`.
3. The banner fires independently off the unlock stream — always shown regardless.

**Milestone (post-game):** On the post-game/result screen, for each newly-unlocked
achievement (returned by `awardGameEnd()`) that has a `memeFolder`, call
`showAchievementMeme`. Milestones have no per-turn event-video, so no collision check is
needed there.

### Data flow

```
Achievement unlocked
  ├─ AchievementBanner (stream)  → always shows player + name  [unchanged]
  └─ has memeFolder?
       ├─ event-driven: event-video played this turn? → yes: skip meme (banner only)
       │                                                → no:  showAchievementMeme()
       └─ milestone: showAchievementMeme() on result screen
             └─ showAchievementMeme gates on meme_enabled + frequency (1-in-X)
```

## Error handling

- Missing folder / empty folder / unreadable asset → silent fallback (existing behaviour).
- `meme_enabled == false` → no meme (banner still shows).
- Frequency roll fails → no meme that time (accepted for one-time unlocks per decision).
- `context` unmounted mid-navigation → guarded with `context.mounted` as today.

## Testing

- Unit: `showAchievementMeme` returns false when `meme_enabled` is off; respects
  `frequencyChance`; returns false on missing folder.
- Unit: collision — given an event-video played, event-driven achievement meme is skipped.
- Widget/integration: unlocking a mapped achievement with meme on + frequency 10 (always)
  shows the overlay; banner shows regardless of meme setting.
- Catalog: every `memeFolder` string has a matching declared asset folder (guard test).

## Rollout

1. Land the code + empty asset folders (memes off by default, so no behaviour change).
2. Drop in content folder-by-folder as clips are produced — no code change per clip.
3. Announce in-app once a meaningful set has content.

## Appendix A — AI video prompts (low-poly "bad bowling" aesthetic)

Style anchor (matches existing `Mer_Bowlinganimasjon_Vibe.mp4` etc.): deliberately
cheap, early-2000s low-poly 3D, flat untextured surfaces, stiff physics, overly-shiny
plastic look, slightly-too-fast animation, no dialogue. 3–4 seconds, square or 16:9,
loops/ends cleanly, silent or minimal SFX. Keep it dart/bowling-hybrid and funny-bad.

- **THE NINE (`the_nine`):** "Low-poly 3D bowling alley, a dartboard where the pins
  should be. Nine oversized darts fire simultaneously into the bullseye, the whole board
  explodes into cheap confetti and shiny plastic pins fly everywhere. Stiff, janky
  early-2000s game-cutscene physics, over-saturated colors, 3 seconds, silent."

- **INSTANT SHANGHAI (`instant_shanghai`):** "Low-poly 3D scene, a single dart splits
  into three glowing darts that hit single, double and treble in one arc, then a giant
  flat-shaded neon 'SHANGHAI' banner drops from the top and squashes a bowling pin.
  Deliberately bad CGI, jerky motion, 3 seconds, silent."

- **MAXIMUM (`maximum`):** "Low-poly 3D dartboard, three darts thud into the treble-20
  in slow janky motion, a huge blocky '180' made of shiny plastic bursts out of the
  board and knocks over a row of low-poly bowling pins. Cheap early-2000s render, 4
  seconds, silent." *(Note: rarely plays due to high_round collision; low priority.)*

- **BULLSEYE FINISH (`bullseye_finish`):** "Low-poly 3D bowling lane that morphs into a
  giant dartboard at the end, a single dart rolls down the lane like a bowling ball and
  slams dead-center bull, screen flashes cheap gold particles. Stiff physics, 3 seconds,
  silent."

- **(Reusable) generic bad-bowling celebration / fail beds:** consider one extra
  `[AI]` "cheap victory" clip and one "cheap faceplant/gutter" clip that could back up
  KILLING SPREE / THE FLOOR / COLD STREAK if no good real meme is found.

## Appendix B — real-meme candidates (for reference when sourcing)

- **NATURAL TALENT** — "beginner's luck" / lucky-first-try clip
- **GRANDMASTER** — crown / "he's built different" / elite clip
- **GIANT SLAYER** — David vs Goliath / big upset celebration
- **UNSTOPPABLE** — "he's on fire" / domination montage
- **THE FLOOR** — rock-bottom / "this is the worst day of my life" self-deprecating clip
- **COLD STREAK** — sad walk-away / defeat / "it's over" clip
- **CLUTCH SAVE** — sweating / "that was close" relief reaction
- **KILLING SPREE** — rampage / triple-kill announcer clip

Keep clips short (≤4s), recognizable, and land the joke fast.
