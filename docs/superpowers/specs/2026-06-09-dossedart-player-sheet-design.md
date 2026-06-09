# DOSSEDART — Unified player sheet (SPILLER-OVERSIKT) — Design

**Date:** 2026-06-09
**Branch milestone:** DOSSEDART arcade redesign (see `docs/superpowers/plans/2026-06-08-dossedart-arcade-redesign-roadmap.md`, Phase 3)
**Source of truth:** `docs/design/dossedart-handoff/DOSSEDART-design-2026-06-05/design_handoff_dossedart_arcade/DOSSEDART ingame sheets.html`

## Problem

The arcade cockpits expose **two different** "player overview" surfaces, breaking the
cross-mode consistency rule:

| Surface | Has add/remove? | Arcade-styled? | Used by |
|---|---|---|---|
| `DossedartPlayerOverviewScreen` (full-screen route, rich stats) | No | Yes | **X01 only** |
| `MidGamePlayerSheet` (Material bottom sheet) | Yes | No (legacy Material) | Cricket, ATC, Killer, Shanghai, Splitscore |

Consequences:
- In the arcade **X01** cockpit there is **no path to add/remove players mid-game** — the only
  add/remove entry (`_openPlayerManagement`) is reachable solely from the legacy classic AppBar
  popup, not the dossedart `⋯ MENU`.
- The other 5 cockpits open an un-skinned Material sheet from `⋯ MENU → PLAYER OVERVIEW`.

The locked design (`DOSSEDART ingame sheets.html`) resolves this: **SPILLER-OVERSIKT merges
"oversikt" + "bytt spillere" into one arcade bottom-sheet** opened from `⋯ MENU` over the dimmed
match — see standings, remove a player (min. 2 active), or add from saved players, in one screen.

## Decisions (Bjørn, 2026-06-09)

1. **Follow the locked design**: one compact arcade **bottom-sheet**, replacing *both* the X01
   full-screen overview and the Material `MidGamePlayerSheet`. All 6 cockpits share it.
2. **Compact rows — primary metric only.** No secondary stat line. The rich mid-game stats
   (avg, hit%, miss%, last-turn) that the X01 full-screen showed are intentionally **dropped from
   mid-game**; they remain available in post-game and the statistics screen.

## Design

### New widget — `lib/widgets/dossedart/dossedart_player_sheet.dart`

Public entry point mirrors the existing `showDossedartCockpitMenu` pattern:

```dart
Future<void> showDossedartPlayerSheet(
  BuildContext context, {
  required List<DossedartStandingRow> rows,
  required bool gameOver,
  required void Function(SavedPlayer saved) onAdd,
  required void Function(int index) onRemove,
  String? addInfoText,
});
```

`showModalBottomSheet` with the shared arcade chrome (magenta frame, black surface, DossedartTokens),
shown over the dimmed match — same look as `showDossedartCockpitMenu`.

### Row view-model — `DossedartStandingRow`

One generic model every cockpit fills, so the sheet renders **identically** across modes:

```dart
class DossedartStandingRow {
  final int playerIndex;   // engine index — passed back to onRemove
  final String name;       // full name (never initials)
  final String? avatarPath;
  final bool isActive;     // current caster → cyan accent
  final bool isRemoved;    // already removed → dimmed, no FJERN action
  final String primary;    // mode-specific score string (see table)
}
```

Per-mode `primary` mapping (each cockpit builds the rows from its existing engine/state):

| Mode | `primary` example |
|---|---|
| X01 | `251` (remaining) |
| Cricket | points total |
| ATC | current target, e.g. `→ 14` |
| Killer | lives, e.g. `♥♥♥` |
| Shanghai | total points |
| Splitscore | current score |

Row ordering is whatever order the cockpit passes (in-game player order, matching the scoreboard).

### Sheet layout (top → bottom)

1. **Title** — `SPILLER-OVERSIKT` (Press Start 2P, yellow), arcade header.
2. **Standings list** — one row per `rows` entry:
   - avatar (photo-or-silhouette via `DossedartPlayerAvatar`) + full name + `primary`.
   - color: `isActive` → cyan; otherwise phosphor; `isRemoved` → dimmed (opacity) with a
     "REMOVED" tag and no action.
   - trailing **`FJERN`** action (red) on active rows. **Disabled** when `gameOver` or active
     count ≤ 2 (need at least 2 active). Tapping pops the sheet then calls `onRemove(playerIndex)`.
3. **LEGG TIL** — section listing `PlayerStorage` saved players not already in the match
   (loaded async, sorted by name, same filtering as today's `MidGamePlayerSheet`). Green add
   control; tapping pops the sheet then calls `onAdd(saved)`. Shows `addInfoText` (e.g. the
   "rating is skipped once you add/remove" notice) and an empty-state when none available.

"Active count ≤ 2" is derived inside the sheet from `rows.where((r) => !r.isRemoved).length`.

### Wiring (all 6 cockpits)

Each cockpit's `onPlayerOverview` callback (in its `showDossedartCockpitMenu` call) changes to:
pop the menu, then `showDossedartPlayerSheet(...)` built from that mode's live state, passing the
cockpit's **existing** `_addSavedPlayerMidGame` / `_removePlayerMidGame` handlers as `onAdd` /
`onRemove`. No engine or persistence changes — only the UI surface and the row mapping are new.

Files touched:
- `lib/screens/game_screen.dart` (X01)
- `lib/screens/cricket_game_screen.dart`
- `lib/screens/around_the_clock_game_screen.dart`
- `lib/screens/killer_game_screen.dart`
- `lib/screens/shanghai_game_screen.dart`
- `lib/screens/halve_it_game_screen.dart` (Splitscore)

### Removals (after all 6 are wired and tested)

- `lib/screens/dossedart/x01/dossedart_player_overview_screen.dart` (incl. `PlayerOverviewRow`) —
  only the arcade X01 cockpit consumed it.
- X01's `_openPlayerOverview` method (the arcade full-screen route builder).
- Associated tests for the deleted X01 overview screen; add tests for the new sheet.

### Explicitly NOT removed

`lib/widgets/mid_game_player_sheet.dart` (`showMidGamePlayerSheet`) **stays**. The classic
(non-arcade) design is a live, user-toggleable path: `main.dart` reads
`AppSettings.getUseDossedartDesign()` and builds `_buildClassicScaffold` when it is `false`. Every
mode's classic scaffold still reaches the Material sheet via `_openPlayerManagement` → keep that
method and the Material sheet untouched. This change only swaps the **arcade** surfaces
(`useDossedartDesign == true`); the classic path is out of scope.

## Testing

- **Widget test** for `DossedartPlayerSheet`:
  - renders one row per `DossedartStandingRow` with name + primary.
  - active row is cyan; removed row is dimmed and has no FJERN action.
  - FJERN disabled when active count == 2 or `gameOver`; enabled (and fires `onRemove`) when > 2.
  - LEGG TIL lists only saved players not already in the match; tapping fires `onAdd`.
- **Smoke**: each of the 6 cockpits opens the sheet from `⋯ MENU` (covered by existing cockpit
  menu tests where present; extend the X01 menu test to assert the sheet opens).
- Full suite must stay green (`flutter analyze` clean, `flutter test`).

## Out of scope / deferred

- Achievements feature (own job — roadmap "Deferred").
- Last-5 form pips (`SavedPlayer` has no recent-results field — deferred).
- Rich mid-game per-player stats (avg/hit%/miss%) — intentionally dropped from this sheet.
- Celebration takeover overlays.
