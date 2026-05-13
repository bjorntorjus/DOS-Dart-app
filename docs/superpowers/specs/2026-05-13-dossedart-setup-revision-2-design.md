# DOSSEDART setup-screens revision 2 — design

**Date:** 2026-05-13
**Branch:** `feat/dossedart-arcade-v1` (worktree `.worktrees/dossedart-redesign`)
**Origin:** QA findings 2026-05-12 on Galaxy Tab A7

## Problem

After the DOSSEDART arcade setup screens shipped on `feat/dossedart-arcade-v1`, QA on Galaxy Tab A7 surfaced three issues:

1. `ArcadeToggleRow` uses a per-toggle accent fill that is visually too different from `ArcadeChipRow`. Specifically, "NO BUST" in its current accent-fill styling is hard to read.
2. Toggle layout per mode wastes vertical space — several modes have single-toggle rows that could combine.
3. Player picker tiles fall back to a colored circle with a player initial when `avatarPath == null`. A neutral silhouette reads better in the picker context.

## Goals

- Make `ArcadeToggleRow` visually identical to `ArcadeChipRow` (yellow fill when ON, surface when OFF) so the two primitives feel like one design language.
- Re-pack toggles into denser rows per mode where the QA notes specified.
- Default `BULL` to OFF in Cricket and Splitscore.
- Replace initial-fallback in `PlayerAvatar` with a neutral silhouette icon, globally.

## Non-goals

- Leaderboard `HANDLE` column (flagged in final review of v1, deferred to a separate spec).
- Any change to `ArcadeChipRow` — it is already correct.
- Player picker tile styling beyond the avatar fallback.
- Game-screen changes.
- New unit tests — this is a pure visual/layout revision with no new logic.

## Design

### 1. Primitive: `ArcadeToggleRow` restyle

File: `lib/widgets/dossedart/setup/rules_primitives.dart`.

Visual match to `ArcadeChipRow`:

| State | Fill | Border (2px) | Text color | Font |
|---|---|---|---|---|
| ON | `DossedartTokens.yellow` | `DossedartTokens.yellow` | `DossedartTokens.bg` | `PressStart2P` size **10** |
| OFF | `DossedartTokens.surface` | `DossedartTokens.magenta` | `Colors.white` | `PressStart2P` size 10 |

Padding `vertical: 12, horizontal: 4` (matches chip). `letterSpacing: 0.5`, `height: 1.3`.

Remove the `●`/`○` glyph from the label — the fill/no-fill state communicates ON/OFF on its own (same convention as `ArcadeChipRow`).

**API change:** the tuple shape changes from

```dart
(String label, bool value, Color accent, ValueChanged<bool> onChanged)
```

to

```dart
(String label, bool value, ValueChanged<bool> onChanged)
```

`accent` is no longer used visually, so it is dropped rather than left as a vestigial parameter. All call sites in `lib/screens/dossedart/dossedart_*_setup_screen.dart` are updated.

### 2. Per-mode layout

All edits in `lib/screens/dossedart/dossedart_*_setup_screen.dart`.

| Mode | Change |
|---|---|
| **X01** | One row: `NO BUST` + `HANDICAP` + `RANDOM ORDER` (3 toggles). |
| **Cricket** | One row: `BULL` + `RANDOM ORDER` (2 toggles). `_includeBull` default → `false`. |
| **ATC** | One row: `BULL` + `D/T = ×N` + `RANDOM ORDER` (3 toggles). Rename label `×MULT` → `D/T = ×N`. |
| **Killer** | Keep `RANDOM ORDER` as its own row (rules section is already dense). `×HITS` / `SHIELD` / `SUICIDE` adopt new chip styling automatically via primitive change. |
| **Splitscore** | One row: `BULL` + `RANDOM ORDER`. `_includeBull` default → `false`. |
| **Shanghai** | No layout change. `RANDOM ORDER` adopts new styling automatically. |

ATC rename is label-only; the underlying field is still `countMultiples` (`AroundTheClockConfig.countMultiples`). Summary string `'×MULT'` updates to `'D/T=×N'`.

Risk: `D/T = ×N` is longer than other labels. The toggle width is `Expanded` so it scales, but at size-10 PressStart2P on a 3-toggle ATC row this needs visual verification on the Galaxy Tab — if it wraps or clips, drop one space (`D/T=×N`) before reducing font size.

### 3. Avatar fallback

File: `lib/widgets/player_avatar.dart`.

When `avatarPath == null`, render `Icon(Icons.person)` centered in the same colored background circle that `PlayerColors` already assigns. The background tint stays — only the foreground content swaps from `Text(initial)` to the silhouette icon. Icon color: white (matches current initial color), size scaled to fit the avatar diameter the same way the initial currently is.

This is a global change — every screen using `PlayerAvatar` with a null path will show the silhouette (player_setup, post_game, stats, leaderboard, etc.). This is deliberate and approved.

### 4. Out-of-scope guards

- Do **not** touch `ArcadeChipRow` styling, `ArcadeStepper`, `_arcadeLabel`, or `DossedartSetupScaffold`.
- Do **not** touch leaderboard / home-screen widgets.
- Do **not** add new tests; existing test suite must still pass.

## Verification

Manual checklist on Galaxy Tab A7 emulator (Samsung Galaxy Tab A target per saved preference):

- [ ] All six setup screens render correctly at tablet width.
- [ ] Toggles flip ON/OFF visually with yellow-fill vs surface-fill.
- [ ] No `●`/`○` glyphs remain in any toggle label.
- [ ] Cricket: `BULL` is OFF when the screen first opens.
- [ ] Splitscore: `BULL` is OFF when the screen first opens.
- [ ] X01: three toggles fit on one row without wrap.
- [ ] ATC: three toggles fit on one row, `D/T = ×N` is legible.
- [ ] Killer: `×HITS` / `SHIELD` / `SUICIDE` use new chip styling; `RANDOM ORDER` stays on its own row.
- [ ] Player picker tile with no `avatarPath` shows silhouette, not initial.
- [ ] No regression in existing screens that use `PlayerAvatar` (spot-check post_game and stats).
- [ ] `flutter analyze` clean.

## Commit plan

Small logical commits on `feat/dossedart-arcade-v1`:

1. `refactor(dossedart): drop accent param + glyph from ArcadeToggleRow, restyle to chip`
2. `feat(dossedart): PlayerAvatar uses silhouette icon when avatarPath is null`
3. `refactor(dossedart): X01/Cricket/ATC/Splitscore — combine toggles into single row`
4. `fix(dossedart): Cricket + Splitscore default BULL=false`
5. `refactor(dossedart): rename ATC ×MULT → D/T = ×N`

Commit 1 will touch every setup screen because the tuple shape changes — call-site updates land in commit 1, layout changes in commit 3.
