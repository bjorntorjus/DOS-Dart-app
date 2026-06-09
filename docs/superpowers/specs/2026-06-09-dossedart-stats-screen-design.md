# DOSSEDART Statistics Screen — Design Spec

**Date:** 2026-06-09
**Milestone:** DOSSEDART arcade redesign — Phase 4 "Statistics" (roadmap
`docs/superpowers/plans/2026-06-08-dossedart-arcade-redesign-roadmap.md`), pulled forward because
the achievements gallery needs its proper home (PRESTASJONER on the profile).
**Design source:** `docs/design/dossedart-handoff/DOSSEDART-design-2026-06-05/.../DOSSEDART statistics screen.html`.

## Problem

The DOSSEDART home's `STATS` nav (`dossedart_home_screen.dart:460`) still routes to the legacy
Material `StatsScreen` (9 tabs: Players + 5 modes + Heatmap + History). It has not been
arcade-redesigned, and the achievements gallery currently hangs off a temporary trophy `IconButton`
bolted onto that Material screen — out of place. The locked design specifies a 4-tab arcade hub
where achievements belong as a PRESTASJONER section on the profile.

## Decisions (Bjørn, 2026-06-09)

1. Build a **new `DossedartStatsScreen`** (arcade). The dossedart home routes to it. The Material
   `StatsScreen` **stays** for the classic (non-arcade, `useDossedartDesign == false`) path — same
   pattern used for the unified player sheet.
2. **PROFIL is one selected player** with a player selector (default = highest-rated). Not a list.
3. The achievements **gallery entry moves to a PRESTASJONER section on PROFIL**; the temporary
   trophy `IconButton` on the Material `StatsScreen` is removed.

## Design — 4-tab hub (`PROFIL / MODUS / HEATMAP / HISTORIKK`)

Arcade chrome throughout: `DossedartTokens`, Press Start 2P headings, color logic you = cyan,
gold = top, green/red = ELO up/down. All data from `SavedPlayer` / `ModeStats` / `GameHistory`
(no new storage). Reuses existing `HeatmapBoard` and the rating-history graph painter.

### PROFIL (landing)
- **Player selector** at top — horizontally scrollable chips of saved players (avatar + name),
  selected = cyan. Defaults to the highest-rated player. Empty state if no saved players.
- **Hero:** avatar + name + ELO rating + global ranking (#n of m by rating) + win-ring
  (gamesWon/gamesPlayed as a ring) + record (W-L, win%).
- **Rating-history graph** for the selected player (reuse the existing painter, arcade colors).
- **Per-mode win%** strip (one row per mode the player has played: played/won/win%).
- **Head-to-head** list (top opponents by games, W-L).
- **PRESTASJONER section:** count `unlocked / total`, a small row of the most-recent unlocked
  medals, a "nearest to unlock" item (highest-progress locked milestone), and a button →
  `AchievementsGalleryScreen(player: selected)`.

### MODUS
- A **mode selector** (chips: X01 / Cricket / Around the Clock / Killer / Splitscore / Shanghai).
- A **leaderboard** for the chosen mode: saved players ranked, with that mode's headline stats
  (played, won, win%, best). Reuses today's per-mode card content, arcade-skinned.

### HEATMAP
- Mode selector + up-to-two player selectors + `HeatmapBoard` (existing). Arcade-skinned chrome.

### HISTORIKK
- Reverse-chronological `GameHistory` list: mode, date, players/placements, per-player ELO Δ
  (green up / red down). Arcade-skinned rows.

## File structure

- **Create** `lib/screens/dossedart/dossedart_stats_screen.dart` — the 4-tab hub + its tab
  builders. If it grows large, split tab bodies into `lib/widgets/dossedart/stats/` widgets
  (`profile_tab.dart`, `mode_tab.dart`, `heatmap_tab.dart`, `history_tab.dart`).
- **Create** `lib/widgets/dossedart/stats/prestasjoner_section.dart` — the PROFIL achievements
  section (count + recent medals + nearest-to-unlock + gallery button). Pure widget given a
  `SavedPlayer`.
- **Modify** `lib/screens/dossedart/dossedart_home_screen.dart` — route `STATS` to
  `DossedartStatsScreen`.
- **Modify** `lib/screens/stats_screen.dart` — remove the temporary trophy `IconButton` + its
  `achievements_gallery_screen` import.
- **Reuse** `lib/widgets/heatmap_board.dart`, the rating-graph painter, `GameHistoryService`.

## "Nearest to unlock"

A locked milestone with the highest fractional progress. Since `Achievement.milestoneTest` is a
boolean predicate (no numeric progress), v1 keeps this simple: show the first N locked milestone
badges for the player as "still to unlock" (no percentage). A richer progress model is out of scope.

## Testing

- Widget test: `DossedartStatsScreen` renders 4 tabs (PROFIL/MODUS/HEATMAP/HISTORIKK).
- PROFIL: player selector switches the displayed profile (two players → tapping the second shows
  its name/rating).
- PRESTASJONER: shows `unlocked/total` for the selected player; the gallery button opens
  `AchievementsGalleryScreen`.
- MODUS: mode selector switches the leaderboard.
- Empty state: no saved players → friendly empty profile, no crash.
- Full suite green; `flutter analyze` clean.

## Out of scope / deferred

- Numeric per-achievement progress bars ("nearest to unlock" stays list-based).
- Arcade-redesigning the classic Material `StatsScreen` (kept as-is for the classic path).
- Per-mode achievement tracking (Phase 5–6 of the achievements work, separate).
