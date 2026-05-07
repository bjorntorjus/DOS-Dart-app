# Handoff: DOSSEDART redesign — indigo theme + X01 / Setup / Post-game

## ⚠️ Read this first — coordination

There is **another Claude Code session** currently doing a UI audit on this codebase. To avoid merge hell:

1. **Land that audit's work first.** Get it reviewed, merged to `main`, and verify the app still runs.
2. **Then start this redesign on a fresh branch.** Use `feat/indigo-redesign` as the umbrella branch.
3. **Ship behind a feature flag.** Add a `useNewDesign` boolean (env var, build flag, or settings toggle — whatever's idiomatic) so we can flip it off in production if something goes sideways. Old screens stay in the codebase; new screens live alongside them.
4. **Recommended commit cadence:** push after each phase below. Five clean commits is much easier to roll back than one giant one.

```
feat/indigo-redesign
├── chore: add useNewDesign feature flag                     (Phase 0a)
├── feat(theme): add indigo M3 theme                         (Phase 0b)
├── feat(x01): redesigned in-game screen behind flag         (Phase 1)
├── feat(setup): grid layout + randomize order behind flag   (Phase 2)
├── feat(postgame): stadium recap + matrix behind flag       (Phase 3)
└── chore(cricket): recolor only — no layout changes         (Phase 4)
```

Once all five are merged and the flag is on for a week with no regressions, delete the old screens and the flag in a follow-up cleanup PR.

---

## Overview

Redesign of the DOSSEDART darts app focused on three high-traffic screens — **X01 in-game**, **player setup**, and **post-game recap** — plus a **theme migration** from the current red-on-cream palette to a dark **indigo + amber** scheme. Cricket gets a colour-only refresh; full Cricket redesign is **deferred to a later round**. Stats and Home are explicitly out of scope.

## About the design files

The HTML in `wireframes/` is a **design reference**, not code to copy. It's a static React mockup that shows intended layout, colour, typography, and component composition for each screen. Your job is to **recreate these designs in the existing Flutter codebase** using its established widgets, theming, and state management — not to port the HTML.

Build the new screens **alongside** the old ones, gated by `useNewDesign`. Don't delete the old screens until the flag has been on in production without issues.

## Fidelity

**Mid-to-high fidelity.** Final colour palette, typography scale, layout, and copy are locked. Iconography is placeholder (use the codebase's existing icon set). Animation specifics (durations, easings) are not specified — use Flutter Material defaults unless something feels wrong.

---

## Design tokens (Phase 0 — do this first)

Add these to the app's `ThemeData`. Use `Theme.of(context).colorScheme.X` everywhere — no hex literals in widgets.

### Colors

| Token | Hex | Used for |
|---|---|---|
| `scaffoldBackgroundColor` | `#14141A` | page background |
| `colorScheme.surface` | `#1C1C24` | cards, the "other players" strip |
| `colorScheme.surfaceContainerHigh` | `#21222B` | input chips, secondary buttons |
| `colorScheme.surfaceContainerHighest` | `#272834` | elevated cells |
| `colorScheme.primary` | `#4F5DC4` | indigo — nav, calm UI, secondary CTAs |
| `colorScheme.onPrimary` | `#DFE0FF` | text on indigo |
| `colorScheme.tertiary` | `#FFB300` | amber — winners, big scores, "selected" state |
| `colorScheme.onTertiary` | `#000000` | text on amber |
| `colorScheme.error` | `#FF6B35` | orange — primary CTAs, alerts, busts |
| `colorScheme.onError` | `#FFFFFF` | text on error |
| `colorScheme.onSurface` | `#E5E1E9` | body text |
| `colorScheme.onSurfaceVariant` | `#C7C5D0` | secondary text |
| `dividerColor` | `#44464F` | strip & cell borders |

`brightness: Brightness.dark` on the scheme.

**Semantic note:** amber (tertiary) means "this is the winner / selected / primary value". Orange (error) means "act on this / commit / alert". Indigo (primary) means "navigation / chrome". Don't mix them up.

### Typography

| Token | Family | Size / weight | Used for |
|---|---|---|---|
| `displayLarge` | display serif | 56 / 400 | hero score in `NowThrowing` |
| `displayMedium` | display serif | 38 / 400 | winner name |
| `displaySmall` | display serif | 30 / 400 | active player name |
| `headlineMedium` | display serif | 24 / 400 | other-player score in strip |
| `bodyLarge` | sans | 16 / 500 | default body |
| `bodyMedium` | sans | 14 / 500 | secondary body |
| `labelSmall` | mono | 10 / 700, letter-spacing 2px, uppercase | tiny labels ("NOW THROWING", "TURN", etc) |

### Spacing & radii

- Card radius: 10–12 px
- Pill radius: 100 px
- Button radius: 6 px
- Inner padding: 8 / 12 / 14 / 20 px scale (no arbitrary values)

---

## Phase 1 — X01 in-game

The most-used screen. **Build top-to-bottom matching the mock.**

### Widget tree

```
Scaffold
└── Column
    ├── BroadcastBar      // top: BACK · LIVE pill · meta · settings
    ├── NowThrowing       // active player block (gradient header)
    ├── OtherPlayersStrip // 3 small cells for other players
    ├── Expanded          // dartboard input takes most vertical space
    │   └── DartboardInput (existing widget — reuse)
    └── TurnActionBar     // UNDO · MISS · spacer · END TURN
```

### `BroadcastBar`
- Row, `borderBottom: dividerColor`.
- **BACK** (left): `←` glyph, mono font, weight 800. Calls `Navigator.pop`.
- **LIVE** pill: orange (`error`) bg, white text, mono, letter-spacing 2px.
- **Meta** (flex: 1): "501 · D-OUT · R7 · LEG 1" — read from game state.
- **Settings** icon (right): pushes settings sheet.

### `NowThrowing`
- Container with vertical gradient: `linear-gradient(180deg, rgba(255,179,0,0.10), transparent)`.
- Border-bottom: `dividerColor`.
- Padding: 16 / 20 / 14.
- **Top label**: "NOW THROWING" (`labelSmall`).
- **Row**: avatar (52px, amber bg, black text) · name (`displaySmall`) over 3 dart pips · score (`displayLarge`).
- **Dart pips**: 3 × 32×6 rounded rects. Filled = `tertiary`, empty = white at 10% alpha. "2/3" in mono after.
- **Bottom row** (border-top dashed): TURN · LAST · AVG · checkout suggestion (right, amber, mono).

### `OtherPlayersStrip`
- Row of 3 `Expanded` cells, each with `borderRight: dividerColor` (last cell no border).
- Background: `surface`.
- Each cell: name (mono small) · score (`headlineMedium`) · "turn +N" or "—".

### `TurnActionBar`
The new piece. **UNDO is the addition you flagged.**

```
[↶ UNDO]  [MISS]  ─── spacer ───  [END TURN]
 outline   ghost                    primary (orange)
```

#### UNDO implementation

```dart
class TurnDelta {
  final String playerId;
  final int scoreBefore;
  final List<Dart> dartsThrown;
  final int turnNumber;
  TurnDelta(this.playerId, this.scoreBefore, this.dartsThrown, this.turnNumber);
}

// In your game state:
final List<TurnDelta> _undoStack = [];

void recordDart(Dart dart) {
  // existing logic
  _undoStack.add(TurnDelta(...));
}

void undo() {
  if (_undoStack.isEmpty) return;
  final delta = _undoStack.removeLast();
  // restore player score, remove dart from current turn
  notifyListeners();
}
```

UNDO button is **disabled** when `_undoStack.isEmpty`. Persists for the whole leg, not just the current turn.

---

## Phase 2 — Player setup

Replace the current scrolling list with a 3-column grid.

### Layout

```
Scaffold
└── Column
    ├── BroadcastBar       // BACK · "NEW GAME" · settings
    ├── ModeBar            // mode chip · start chips (301/501/701) · D-OUT chip
    ├── SelectionBar       // "N SELECTED" pill · 🎲 RANDOMIZE button
    ├── Expanded
    │   └── GridView.count(crossAxisCount: 3, ...)
    │       └── PlayerCard × N
    └── FooterBar          // + NEW · CLEAR · spacer · START →
```

### `PlayerCard`

- Aspect ratio 1:1.
- Border `1.5px`, color = `tertiary` if selected else `dividerColor`.
- Background = `surfaceContainerHigh` if selected else `surface`.
- Avatar (36px, coloured per player).
- Name below.
- **Selection badge** (top-right): 24px circle, amber bg, black text — shows the **join order number** (1, 2, 3…). Hidden when not selected.

### Randomize behaviour

🎲 RANDOMIZE shuffles the **order numbers** assigned to selected players, **not the grid positions**. Spatial memory of "where Mia's tile is" is preserved; only the throw order changes. Animate with a 200ms cross-fade on the badge numbers.

---

## Phase 3 — Post-game

Make this feel like a moment, not a stats dump.

### Layout

```
Scaffold
└── Column
    ├── BroadcastBar         // FINAL pill (amber, not orange!) · meta · settings
    ├── WinnerBlock          // same gradient pattern as NowThrowing
    ├── ComparisonMatrix     // Player · Best · Avg · Darts · Δ
    ├── ScoreProgressionChart  // small line chart, fl_chart
    ├── HighlightsList       // 2-4 generated strings
    └── FooterBar            // HOME · ↶ UNDO LAST · spacer · REMATCH →
```

### `WinnerBlock`
- Avatar 60px (amber). Name in `displayMedium`.
- **Rating delta pill**: amber bg at 15% alpha, "RATING 1450 → 1474 +24" — last value bold and amber.
- Right side: "DARTS" label + big amber number (`displayLarge`).

### `ComparisonMatrix`
- Use Flutter `Table`. Cols: Player · Best · Avg · Darts · Δ.
- **Highlight winning cell in each column** with amber text (bold). Δ is amber if positive (rating gain), orange (`error`) if negative.
- Row order = finishing order (1st, 2nd, 3rd…).

### `ScoreProgressionChart`
- `fl_chart` `LineChart`.
- One line per player, coloured by the avatar colour.
- **No axes, no labels.** Just dashed gridlines at 0/125/250/375/500.
- Height: ~90 px.
- Data source: snapshot total-remaining at end of each round from your turn log.

### `HighlightsList`
- Plain list of 2–4 strings. Auto-generated from turn log:
  - **Ton+ throws**: "R4 — Andreas posts **140** (T20·T20·D10)"
  - **Busts**: "R6 — Jonas busts on 36"
  - **Winning checkout**: "R8 — Checkout **T20·D20** takes the leg"

### Footer
- **REMATCH →** is **primary** (orange). Same players, same mode, fresh leg.
- **↶ UNDO LAST** is for "wait, that wasn't actually a checkout — they busted."
- **HOME** is the escape hatch (ghost).

---

## Phase 4 — Cricket (recolor only)

**Do not touch the Cricket layout.** Just sweep the file for hardcoded colours and replace with `Theme.of(context).colorScheme.X` references. Should be a 30–60 minute job after Phase 0 lands.

Add a TODO comment at the top: `// TODO: full Cricket redesign deferred — see design_handoff_dossedart_redesign/README.md`

---

## Order of operations

1. **Phase 0a** — `chore: add useNewDesign feature flag` (5 min, unblocks everything else)
2. **Phase 0b** — `feat(theme): add indigo M3 theme` (theme is global; gate via flag at the `ThemeData` level if you want to A/B, otherwise just ship it — the old screens still look ok)
3. **Phase 1** — X01 (the big one)
4. **Phase 2** — Setup (parallelizable with 3)
5. **Phase 3** — Post-game (depends on rating-service & turn-log being queryable)
6. **Phase 4** — Cricket recolor

Push after each phase. Get a teammate (or me) to look at screenshots before merging Phase 1.

---

## Things to send back to me

Before starting Phase 1, please send:

1. **Screenshot of current X01 with the new theme applied** (after Phase 0 lands) — this is our baseline.
2. **Sample response shape from the rating service** — the post-game "+24" pill needs to know what to read.
3. **A note if the dartboard widget can't take ~55% of vertical space** — that affects the players-strip height.

---

## Files in this bundle

- `wireframes/DOSSEDART wireframes v4.html` — the latest mock canvas (open this; pan/zoom; click any frame to focus).
- `wireframes/v4.jsx` — the React source for v4.
- `wireframes/v3.jsx` — earlier exploration (cricket + stats + setup variants) — useful background only.
- `wireframes/styles.css`, `wireframes/styles-v3.css` — shared styles.
- `wireframes/design-canvas.jsx` — the canvas host component.

Open the v4 HTML to navigate the designs. The "Implementation guide" section at the bottom of that page mirrors and complements this README.
