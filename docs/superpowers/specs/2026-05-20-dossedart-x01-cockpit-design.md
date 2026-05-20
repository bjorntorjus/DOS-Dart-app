# DOSSEDART X01 in-game cockpit — design

**Date:** 2026-05-20
**Target branch:** `feat/dossedart-x01-cockpit` (worktree `.worktrees/dossedart-x01-cockpit`, branched from `main`)

## Problem

DOSSEDART (the arcade-styled design variant, preview flag in Settings) currently has a home screen + 6 setup screens. When a user starts an actual match with DOSSEDART enabled, they're navigated into the classic Material `GameScreen` — splitting the experience. The user has chosen DOSSEDART as one of two main design tracks (the other being classic M3); for that choice to feel coherent, in-game must also be DOSSEDART when the flag is on.

This spec covers the **X01 in-game cockpit (default state)** + an adjoining **Player Overview** screen. The other X01 in-game states (BUST, TURN END, MENU, SUDDEN DEATH, PLAYER REMOVED, LEG WON, MATCH WON) are explicitly out of scope and will be addressed in a follow-up spec.

## Goals

- DOSSEDART X01 in-game cockpit shipping behind the existing `use_dossedart_design` preview flag.
- Player Overview screen accessible from the cockpit's MENU button — shows all players with remaining, last turn, 3-dart avg, hit%, miss%.
- Layout invariant: the dartboard's position is fixed; it must not move when the checkout-tip appears/disappears or any other dynamic content changes.
- Long-name handling: name font auto-shrinks in discrete steps, then ellipsizes; REMAINING never gets pushed out of view.
- Profile pictures used wherever an avatar appears (silhouette fallback for players without a photo).
- All existing classic X01 game logic (undo, sudden death detection, stats, TTS, sound, video, mid-game add/remove) is preserved unchanged — DOSSEDART is presentation-only.

## Non-goals

- The 6 special states (BUST, TURN END, MENU, SUDDEN DEATH, PLAYER REMOVED, LEG WON, MATCH WON) — separate spec.
- DOSSEDART Cricket / ATC / Killer / Shanghai / Splitscore in-game — separate specs (one each).
- Engine extraction — long-deferred project, NOT prerequisite for this work.
- Classic GameScreen visual changes — untouched.
- New gameplay mechanics or stats not already tracked by the existing engine.
- "Last 5 W/L pips" wiring (separate open thread).

## Reference mockups (committed in repo)

- `docs/design/dossedart-handoff/PROPOSAL-cockpit-v5.html` — cockpit (silhouette + photo variants)
- `docs/design/dossedart-handoff/PROPOSAL-player-overview-v4.html` — Player Overview (arcade scoreboard)

Both mockups served via `python -m http.server 8765` in the handoff folder.

## Deviations from original handoff (`docs/design/dossedart-handoff/README.md`)

The original handoff describes a player **carousel** with active card + prev/next peek cards. After review the user opted to **drop the carousel** in favour of a single active-player card + a separate Player Overview screen reached from MENU. Reasons:

1. The carousel mixed "browse other players" with "play your turn" in one component, which made the cockpit visually busy.
2. Player Overview as a separate screen gives more room per player and supports more stats per row.

The original handoff also illustrates a **standard dartboard color convention**. The user chose **DOSSEDART arcade colors on the board** instead, compensating for reduced muscle-memory readability with strong per-segment numeric labels in Press Start 2P.

These deviations are intentional. The original handoff README remains the source of truth for the *visual language* (tokens, type, scanline, glow, etc.); the proposal HTMLs above are the source of truth for *cockpit + overview layout* specifically.

## Architecture

### Routing & flag plumbing

`GameScreen` (`lib/screens/game_screen.dart`) gains a `final bool useDossedartDesign` constructor parameter, default `false`. `build()` becomes:

```dart
@override
Widget build(BuildContext context) {
  if (widget.useDossedartDesign) return _buildDossedartCockpit(context);
  return _buildClassicScaffold(context); // existing body, extracted unchanged
}
```

The existing build tree is moved verbatim into `_buildClassicScaffold(context)` — no semantic change. The new `_buildDossedartCockpit(context)` builds the cockpit using shared `_GameScreenState` for all logic.

`lib/screens/dossedart/dossedart_x01_setup_screen.dart`: when pushing `GameScreen` on Start, passes `useDossedartDesign: true`.

`lib/screens/player_setup_screen.dart` (classic): no change needed (defaults to `false`).

### File layout

**New files:**

```
lib/widgets/dossedart/x01/
  dossedart_x01_topbar.dart          — ◀ EXIT · title · L 1/3 · RND 7
  dossedart_x01_active_card.dart     — avatar + name + dart-dots + REMAINING + LAST + checkout-tip
  dossedart_x01_dartboard.dart       — tap-zone SVG dartboard in arcade colors
  dossedart_x01_action_bar.dart      — UNDO · MISS · MENU

lib/screens/dossedart/x01/
  dossedart_player_overview_screen.dart   — arcade scoreboard view, pushed from MENU
```

**Modified files:**

- `lib/screens/game_screen.dart` — adds `useDossedartDesign` param + `_buildDossedartCockpit()` branch; extracts existing build into `_buildClassicScaffold()`. No logic changes.
- `lib/screens/dossedart/dossedart_x01_setup_screen.dart` — passes `useDossedartDesign: true` when pushing GameScreen.

No new state, no new model fields, no engine changes.

### Layout structure (cockpit)

The cockpit is a `Stack` (not Column) so the dartboard's position is invariant:

```
Stack (fills screen)
├── Column (header + active card, flows from top — bounded by Positioned top:0)
│   ├── DossedartX01TopBar          height ~49px
│   └── DossedartX01ActiveCard      variable height (~220-260px depending on checkout-tip)
├── Positioned (bottom: 84+actionbar, centered horizontally)
│   └── DossedartX01Dartboard       fixed 320x320 (or scaled to viewport width)
└── Positioned (bottom: 0)
    └── DossedartX01ActionBar       height ~60px
```

The **active card's variable height does NOT push the dartboard** because the dartboard is a separate `Positioned` child of the same `Stack`. Critical: do NOT nest dartboard inside a `Column` with the active card.

The active card and dartboard may visually overlap in extreme edge cases (very long checkout-tip + very large remaining number); the active card's `Container` clips its own content and the dartboard remains underneath. If overlap is observed during implementation, the active card's max-height is capped via `ConstrainedBox`.

### Component contracts

**`DossedartX01TopBar`** (stateless):
- Inputs: `String mode`, `int startingScore`, `String outRule`, `int legIndex`, `int legCount`, `int roundNumber`, `VoidCallback onExit`
- Renders: `◀ EXIT` (cyan, left) · centered title `X01 · {score} · {outRule}` (yellow, glow, ellipsizes) · `L {n}/{m} · RND {r}` (right, dim)
- Magenta 2px bottom border. Always-uppercase content.

**`DossedartX01ActiveCard`** (stateless):
- Inputs: `Player player` (name, avatarPath), `Color accent` (magenta default; opens room for per-player colour later), `int remaining`, `List<DartThrow> lastTurnThrows`, `int currentDartIndex` (0-2), `String? checkoutTip` (null = no checkout possible)
- Layout: 3px magenta border, gradient bg, padding 12/14
  - Row 1: 56px square `PlayerAvatar` + name (Press Start 2P, auto-shrinks: 18/15/12/10px, ellipsizes) + dart-dots row
  - Dart-dots: 3 squares (●/○) under the name, `DART {n}/3` VT323 caption
  - Row 2: `REMAINING` label (small) + big remaining number (Press Start 2P 60px, magenta, glow + chromatic-aberration)
  - Row 3 (above dashed magenta separator): `LAST` label + 3 throws (VT323 yellow) + `= sum` (Press Start 2P yellow)
  - Row 4 (only when `checkoutTip != null`): green dashed-border strip showing the tip
- No internal state. Pure props.

**`DossedartX01Dartboard`** (stateless):
- Inputs: `void Function(DartZone zone) onTap` (zone = S/D/T per segment + Bull/D-Bull + miss)
- Renders SVG/CustomPainter: 20 segments in standard ordering (20,1,18,4,13,6,10,15,2,17,3,19,7,16,8,11,14,9,12,5), arcade colors:
  - Inner singles: alternating magenta/cyan (opacity 0.35)
  - Triple ring: solid green
  - Outer singles: alternating magenta/cyan (opacity 0.35)
  - Double ring: solid yellow
  - Outer label band: dark bg with `Press Start 2P` 11px white segment number
  - Bull outer ring: orange · Bull centre: red
- Magenta 3px border around the board with glow.
- No internal state. Hit-test geometry detailed in next section.

### Dartboard geometry — visual matches hit-test (CRITICAL)

A real dartboard's double and triple rings are very narrow (~5% of total radius each). Rendered at standard proportions on a phone-sized board (~320-370px), each ring is only ~9-17px wide — too narrow to tap reliably.

**Strategy: visual = hit-test.** What the player SEES is what the player CAN TAP. Rings are rendered thicker than a physical board so each one is a comfortable touch target, and the visible boundary IS the hit-test boundary. No "tap a single, register a double" surprises.

This sacrifices physical realism for input honesty. The board is still recognisable as a dartboard from segment ordering, colours, and the bull centre — the rings are just chunkier.

| Ring | Outer radius (% of board radius) | Width | Notes |
|---|---|---|---|
| D-Bull (inner bull) | 5% | 5% | centre circle |
| Bull (outer bull) | 12% | 7% | thin ring |
| Inner single | 47% | 35% | broad band |
| **Triple** | **58%** | **11%** | ~2× a real triple |
| Outer single | 82% | 24% | broad band |
| **Double** | **95%** | **13%** | ~2× a real double |
| Outer label band | 100% | 5% | visual chrome only — taps here count as `DartZone.miss` (it's outside the playable area on a real board too) |

Numbers in **bold** are wider than a physical board. The outer 5% is a non-tappable label band where the segment number is rendered (matches the cosmetic ring on real boards just outside the double).

On a 320px board (radius 160), this gives:
- Triple: ~18px wide ring — both visually and to tap
- Double: ~21px wide ring — both visually and to tap

**Algorithm:** convert tap (x,y) → polar (r, θ) relative to board centre. Compare `r` against the radius thresholds in the table to pick the ring. Compare `θ` against segment angles to pick the number. Tap with `r > 95% × board-radius` → `DartZone.miss`.

**Test coverage** for this is mandatory: `dossedart_x01_dartboard_test.dart` includes a fixture of (x, y) tap coordinates at the inner and outer edges of each ring, asserting the expected `DartZone` falls correctly. Particular cases:
- 1px inside double-ring outer edge → `DartZone.double(n)`
- 1px outside double-ring outer edge → `DartZone.miss`
- 1px inside triple-ring → `DartZone.triple(n)`
- Anywhere within Bull radius → `DartZone.bull` / `DartZone.dBull`

**`DossedartX01ActionBar`** (stateless):
- 3 buttons left-to-right:
  - `↶ UNDO` — flex 1, magenta border, transparent bg, white text
  - `✗ MISS` — flex 2, filled orange bg, white border, glow (primary)
  - `⋯ MENU` — flex 1, cyan border, cyan text
- Black bg, yellow 2px top border. Press Start 2P 11px.
- Inputs: `VoidCallback onUndo`, `VoidCallback onMiss`, `VoidCallback onMenu`

**`DossedartPlayerOverviewScreen`** (stateful screen — pushed by MENU; can also be reached via "Player Overview" menu entry):
- Inputs: `List<Player> players`, `int currentPlayerIndex`, `String mode`, `int startingScore`, `int currentRound`
- Renders:
  - TopBar (back, title `CAST · X01 {score}`, `RND {r}`)
  - `► SCOREBOARD ◄` magenta marquee
  - Column header: `# | (avatar) | PLAYER | REMAIN`
  - Scrollable list — one row per player:
    - Line 1: rank `01..NN` (yellow Press Start 2P) · 44px square `PlayerAvatar` · name (auto-shrinks 14/12/10px, ellipsizes) · `REMAINING` (magenta Press Start 2P 26px)
    - Line 2 (small, dim): `AVG {x.x} · HIT {y}%`
    - Line 3 (yellow-tinted box): `LAST {throws} {sum}` — fills full row width
  - Bottom marquee: `★ ★ ★ INSERT DART TO CONTINUE ★ ★ ★` (cyan, decorative)
- Hit % derived from existing throw history (`hits / totalDarts`); miss % = 100 - hit%.
- Active player is NOT highlighted (per user feedback — all rows look uniform).

### CRT visual treatment (applies to both cockpit and overview)

These are shared treatments, implemented once in a `DossedartCrtFrame` widget that wraps the screen body:

- **Background:** `DossedartTokens.bg`
- **Scanlines:** repeating 3px-period horizontal lines (rgba 0,0,0,0.40 in line)
- **Vignette:** radial gradient at 40-100% darkening to rgba 0,0,0,0.75
- **Inset shadows:** `BoxShadow(blurRadius: 60, color: black87, offset zero)` simulating CRT-glass-bulge
- **Border-radius 16** on the inner frame
- **Text glow:** all UI accent text uses `Shadows` with blur 6-16px in the colour itself plus a small +1px magenta / -1px cyan chromatic-aberration ghost on big text and titles
- **Scan-beam animation:** the existing `ArcadeFrame` widget (used by setup screens) already provides the slow scanning beam; cockpit reuses it inside `DossedartCrtFrame`. Tests use the `disableBeamForTest` flag added in PR #7.

The "CRT bezel" shown in the mockup (grey plastic surround with rounded corners + power LED) is **decorative-only in the mockup** and is NOT implemented in Flutter — it would shrink usable screen area. In Flutter the bezel-style is conveyed entirely by inset shadows + border-radius on the inner frame.

### Dart input flow

The dartboard's `onTap(DartZone)` triggers the existing private method that classic uses to register a dart hit. The exact entry point is `_GameScreenState._onDartHit(int segment, int multiplier)` (around line 278) — DOSSEDART maps `DartZone` → `(segment, multiplier)` and calls the same method. No new logic, no new state machine.

Currently classic uses a numeric keypad; DOSSEDART uses tap-zones on the dartboard. Both feed into the same `_onDartHit`. Sudden death, bust detection, checkout detection — all unchanged.

The `↶ UNDO` button calls existing `_undo()`. The `✗ MISS` button calls `_onMiss()` (already exists). The `⋯ MENU` button — for this spec — opens a temporary bottom sheet with two actions:

1. **Player Overview** — navigates to `DossedartPlayerOverviewScreen`
2. **Exit match** — same as classic's confirm-exit flow

The richer MENU sheet from the original handoff (with EDIT LAST THROW, REMOVE PLAYER, RESTART LEG, ABANDON MATCH) is **deferred to the next spec** which covers the 7 states.

### Long-name strategy

Per the cockpit V4 mockup, name font auto-shrinks in 4 discrete steps:

| Length (chars) | Active card | Overview list |
|---|---|---|
| ≤6 | 18px | 14px |
| 7-10 | 15px | 12px |
| 11-16 | 12px | 10px |
| 17+ | 10px + ellipsis | 10px + ellipsis |

REMAINING is always rendered last in its row and never shrinks — it always wins layout priority.

### Profile pictures

`DossedartX01ActiveCard` and `DossedartPlayerOverviewScreen` use the existing `PlayerAvatar` widget (`lib/widgets/player_avatar.dart`) with:
- `radius: 28` for active card (yields 56px diameter)
- `radius: 22` for overview rows (yields 44px diameter)

The current `PlayerAvatar` uses `CircleAvatar` (round). For arcade aesthetic, a **square wrapper** is needed. Two options:

1. Add a `bool square = false` param to `PlayerAvatar` — minimal invasion, but couples the avatar widget to arcade concerns.
2. Create a thin `DossedartPlayerAvatar` widget that composes `PlayerAvatar` inside a square `Container` (clipping the round avatar to a square — actually visible as a square with the circle photo inside).

**Decision: Option 2.** Keep `PlayerAvatar` unchanged. New `DossedartPlayerAvatar` wraps it in a square `Container` with player-color border and 0 border-radius. The existing setup-screen picker tiles can be migrated to this new widget in a follow-up if visual consistency matters (not in this spec's scope).

The mockup shows full square photo treatment with `border-radius: 0` (no inset round photo). For implementation, decide between:
- (a) `CircleAvatar` cropped square → photo shows as full square photo (current PlayerAvatar uses Circle)
- (b) Custom `Image.file` directly with `BoxFit.cover` inside the square container — gives true square photo.

**Decision: (b)** for `DossedartPlayerAvatar` so the photo IS the square content, no round inset. Implementation reads `avatarPath` directly with `FileImage` + fallback `Icons.person` SVG-style silhouette.

## Layout invariants (must hold in implementation)

1. **Dartboard position is fixed.** Implemented as a separate `Positioned` child of the cockpit `Stack`. Never inside a flow `Column` with the active card.
2. **Active card max-width = frame minus 14px horizontal padding on each side.**
3. **REMAINING never overflows.** Always last in its row, `flex: 0 0 auto`, font fixed at 60px.
4. **Action bar always at bottom.** `Positioned(bottom: 0)`.

## Testing

**Widget tests** (`test/widgets/dossedart/x01/`):
- `dossedart_x01_active_card_test.dart` — renders with all name-length tiers, checkout-tip present/absent, fallback silhouette vs photo
- `dossedart_x01_dartboard_test.dart` — tap-zone hit testing: tap at known coords → expect the right `DartZone` event
- `dossedart_x01_action_bar_test.dart` — button callbacks fire

**Integration test** (`integration_test/dossedart/x01_cockpit_test.dart`):
- Start a DOSSEDART X01 match with 2 seeded players → cockpit renders, name visible, REMAINING shows starting score, dartboard visible.
- Smoke: tap MENU → bottom sheet appears → tap "Player Overview" → DossedartPlayerOverviewScreen renders with both players' rows.

**Manual verification (one-time):**
- Open on actual Galaxy Tab + a phone profile, verify dartboard stays put when toggling checkout-tip visibility via test hook.
- Open with a long-name player ("BJØRN TORJUS ILESTAD") — verify ellipsis, no REMAINING shift.

## Out of scope

- The 7 game states (BUST, TURN END, MENU [full sheet], SUDDEN DEATH, PLAYER REMOVED, LEG WON, MATCH WON) — next spec
- Cricket / ATC / Killer / Shanghai / Splitscore in-game DOSSEDART
- Sound/TTS changes — existing announcer continues to work as-is
- Performance optimisations (we accept the existing GameScreen perf profile)
- Animation refinements beyond what's already in `ArcadeFrame`
- iOS/desktop-specific layout adjustments

## Commit plan

Single PR `feat/dossedart-x01-cockpit` with logical commits:

1. `feat(dossedart): DossedartCrtFrame + DossedartPlayerAvatar foundation`
2. `feat(dossedart): X01 cockpit widgets (topbar, active card, dartboard, action bar)`
3. `feat(dossedart): wire X01 setup → GameScreen with useDossedartDesign flag`
4. `feat(dossedart): Player Overview screen accessible from cockpit MENU`
5. `test(dossedart): widget tests for cockpit components`
6. `test(integration): DOSSEDART X01 cockpit + Player Overview navigation smoke test`

If any commit fails analyzer/tests, do not advance.
