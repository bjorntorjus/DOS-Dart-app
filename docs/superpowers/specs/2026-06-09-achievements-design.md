# DOSSEDART Achievements — Design Spec

**Date:** 2026-06-09
**Milestone:** DOSSEDART arcade redesign — the deferred "own job" (see
`docs/superpowers/plans/2026-06-08-dossedart-arcade-redesign-roadmap.md`).
**Candidate catalog:** `docs/superpowers/specs/2026-06-09-achievements-catalog.md` (~245 grounded candidates).
**Design source:** `docs/design/dossedart-handoff/DOSSEDART-design-2026-06-05/.../DOSSEDART achievements concept.html`.

## Goal

A full achievements (badges) system: ~245 one-time unlockable badges anchored in real play,
surfaced through a passive top-banner on unlock, a filterable gallery, and a profile section —
arcade-styled, consistent with DOSSEDART tokens.

## Scope

**Full catalog** (Bjørn, 2026-06-09): build the entire candidate set, including badges that need
new tracking across all 6 modes. The framework + storage + retro + all three UI surfaces + the
per-mode tracking additions are all in scope. Decomposed into phases (below) — but the whole
feature is the target, not a thin v1.

## Decisions (locked with Bjørn, 2026-06-09)

1. **Unique names, no parenthetical mode-dupes.** Every badge has a globally unique name, OR is a
   single cross-mode badge when the trigger is genuinely identical. Never `Name (mode)`. (See
   memory `feedback_achievement_design`.) A dedup/rename pass over the catalog is part of the work.
2. **One-time unlocks.** Each badge is binary (locked/unlocked), unlocked once, never re-fires.
   Progressive concepts (10/100/1000 marks) are separate badges, each unlocking once. This also
   neutralizes the "fires too often" concern — frequent feats (e.g. score 100+) only banner the
   first time.
3. **Hybrid retro-grant.** On launch, silently mark every badge already provable from existing
   tracked data as unlocked (no banner). The live banner fires only on genuine new unlocks going
   forward. Feats with no historical data (streaks, instant-Shanghai count) naturally start fresh.
4. **Banner = passive top dropdown.** Slides in immediately, semi-transparent, ~3s auto-dismiss,
   never blocks input, app-wide overlay above all game screens. Multiple simultaneous unlocks
   **queue** and show sequentially. Must never interrupt winscreen / next player / video / TTS —
   it only ever overlays the very top edge.
5. **Per `SavedPlayer`.** Guests (players without a `savedPlayerId`) do not earn badges.
6. **Cosmetic only.** The badge itself is the reward; no in-app effect.
7. **Glyphs: Material Icons now, custom art later.** Each badge maps to a Material `IconData` for
   v1. The medal widget accepts *either* an `IconData` *or* an asset path, so swapping to custom
   pixel-art per badge later is a data change, not a structural one.
8. **Lean toward humor.** Keep a healthy share of quirky/self-deprecating badges (NATURAL TALENT,
   ALWAYS THE BRIDESMAID, PARTICIPATION TROPHY, OWN WORST ENEMY, etc.).

## Architecture

### Achievement definition — `lib/models/achievement.dart`

```
class Achievement {
  final String id;            // stable key, e.g. 'x01_maximum'
  final String name;          // unique display name, e.g. 'MAXIMUM'
  final String description;   // how to unlock, shown in gallery
  final AchievementTier tier; // bronze | silver | gold
  final String? mode;         // GameMode key, or null for cross-cutting
  final AchievementGlyph glyph; // IconData now; asset-path-capable later
  final AchievementCategory category; // scoring | milestone | streak | social | quirky
}
enum AchievementTier { bronze, silver, gold }
```

`AchievementGlyph` is a small wrapper holding either an `IconData` or an asset path, so
`AchievementMedal` renders both and the later art swap touches only catalog data.

### Static registry — `lib/data/achievement_catalog.dart`

A `const`/lazy list of all ~245 `Achievement` definitions, built from the candidate catalog after
the dedup/rename pass. Pure data, no logic. Grouped by mode + cross-cutting. This file is the
single source of truth for *what* badges exist; evaluation logic lives in the service.

### Evaluation — `lib/services/achievement_service.dart` (singleton)

Three entry points:

- **`checkEvent(AchievementEvent event, {required SavedPlayer player})`** — called from game
  screens at notable in-game moments, reusing the *same* trigger points that already fire
  sound/meme (180, instant-Shanghai, big checkout, became-killer, multi-kill, clutch-save, 69,
  6-7, three-misses, …). If the event maps to a still-locked badge for that player → unlock it and
  emit a banner immediately. `AchievementEvent` is a typed enum/struct describing the moment.
- **`evaluateMilestones(SavedPlayer player, GameOutcome outcome)`** — called at game-end after
  `StatsRecorder` has updated the player. Evaluates all threshold/career/streak/per-game-flag
  badges against the updated `SavedPlayer` + the per-game `GameOutcome`. Newly-unlocked → queued
  banner shown on the post-game transition.
- **`retroGrantSilently(SavedPlayer player)`** — run once per player (guarded by a flag) the first
  time the feature loads: unlock everything currently provable from existing stats, **no banner**.

The service persists unlocks via `PlayerStorage` and exposes `unlockedFor(player)` /
`progressFor(player, achievement)` for the UI.

### Storage — extend `SavedPlayer`

- `Set<String> unlockedAchievementIds`
- `Map<String, DateTime> achievementUnlockedAt`
- `bool achievementsRetroGranted` (one-time retro guard)
- New tracking fields the catalog's NEW badges need: `currentWinStreak` / `bestWinStreak` /
  `currentLossStreak` (per-mode + overall), `niceCount` / `sixSevenCount`, distinct-play-day set +
  consecutive-day streak, `becameNumberOneAt` (for #1-reign duration), runner-up (2nd-place)
  streak, and per-mode counters added below. Serialized through existing PlayerStorage JSON.

### Per-mode / per-game tracking additions (the NEW data)

Per the catalog's NEW tags, decomposed as one sub-plan per mode. The recurring cheap unlocks:
- **Per-turn aggregator** (marks/triples/bulls/points-this-turn) recorded as `max:` counters at
  turn-end — powers ~20 badges (X01, Cricket, Shanghai, Splitscore).
- **Per-leg dart count + finishing-dart capture** (X01) — reconstructed from `throwHistory` in the
  game-end stats hook.
- **Per-game flags** computed at record time: no-bust, comeback/max-deficit-while-behind,
  on-one-life, instant-Shanghai, no-halving, wire-to-wire (per-round leader snapshot), etc.
- **Opponent end-state snapshot** at game-end (shutouts, win margins, regicide, dominator).
- **Meme counters** — wire the existing fire-and-forget `MemeService` triggers (69, 6-7) to
  increment counters / fire achievement events.

Each addition lands in the relevant engine/screen + `StatsRecorder`, mode by mode.

### UI surfaces

- **`AchievementBanner`** (`lib/widgets/dossedart/achievement_banner.dart`) — passive top
  dropdown per decision #4. An app-level overlay host (above the `Navigator`, e.g. in the root
  `MaterialApp` builder or a global overlay) so it survives screen transitions and never depends on
  the current game screen. Maintains a FIFO queue; shows one at a time, ~3s each, auto-dismiss,
  `IgnorePointer` so it never eats taps. Content: tier-colored medal + "`<player>` unlocked
  `<NAME>`". Uses DossedartTokens.
- **Gallery** (`lib/screens/dossedart/achievements_gallery_screen.dart`) — grid of `AchievementMedal`s,
  filters (mode / tier / locked-unlocked), progress %, locked badges shown dimmed with description.
  Reached from the stats profile and/or home.
- **PRESTASJONER profile section** — on the stats profile screen: a compact strip of recent/total
  unlocked + a "nearest to unlock" list (uses `progressFor`). Arcade-skinned.
- **`AchievementMedal`** (`lib/widgets/dossedart/achievement_medal.dart`) — shared hexagon medal,
  tier color (bronze `#D08A4A` / silver `#C9D2DA` / gold `DossedartTokens.yellow`) + glyph;
  locked = desaturated/dimmed. Accepts IconData or asset path.

## Naming dedup rule (applied when authoring the catalog file)

Resolve every recurring candidate name:
- **Promote to one cross-mode badge** when the trigger is identical (e.g. `FIRST BLOOD` = win your
  first game in any mode; `WIRE TO WIRE` = lead every round to the end).
- **Rename distinctly per mode** when the feat differs (e.g. comeback: X01 `HOUDINI`, Cricket
  `STREET FIGHTER`, Shanghai `FROM THE ASHES`).
- Drop weak duplicates (per-mode "win your first X game" superseded by `FIRST BLOOD` + per-mode
  volume badges).

## Implementation phases (decomposition — each its own plan)

1. **Framework + storage + retro** — `Achievement` model, `AchievementGlyph`, service skeleton
   (3 entry points), `SavedPlayer` storage fields + PlayerStorage serialization, retro guard. No
   badges wired yet; tested with a handful of fakes.
2. **Catalog authoring** — write `achievement_catalog.dart` with all ~245 deduped/renamed
   definitions + glyph mapping + humor pass.
3. **UI surfaces** — `AchievementMedal`, `AchievementBanner` + global overlay host, gallery
   screen, profile section. Driven by the catalog + service.
4. **Wire EXISTING badges** — connect all threshold/career/H2H/rating badges through
   `evaluateMilestones` + `retroGrantSilently`. Fully functional subset, end-to-end.
5. **Per-mode tracking (one plan each)** — X01, Cricket, ATC, Killer, Shanghai, Splitscore: add
   the NEW counters/flags/events and wire their badges (event + milestone).
6. **Cross-cutting NEW** — streaks, distinct-days, #1-reign, runner-up streak, meme counters.

## Testing

- Model/service unit tests: unlock idempotency (one-time), retro-grant marks correct set silently
  (no banner emitted), event vs milestone routing, progress calculation.
- Banner widget test: queue shows sequentially, auto-dismiss, `IgnorePointer` (never blocks taps).
- Per-mode tracking: unit tests that a known game sequence sets the expected counter/flag and
  unlocks the expected badge (e.g. a 180 turn → MAXIMUM; instant-Shanghai → its badge).
- Gallery/profile widget tests: filters, locked vs unlocked rendering.
- Full suite green; `flutter analyze` clean.

## Out of scope / deferred

- Custom pixel-art glyphs (structure is art-ready; swap later — decision #7).
- Any in-app reward beyond the badge (decision #6).
- Celebration takeover overlays (separate roadmap item; achievements use the passive banner only).
- Sharing/export of achievements.
