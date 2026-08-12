# Handoff: 1UP cockpit + screens (rev. 2026-07-16)

## Overview
1UP is DOSSEDART's lives / beat-the-target game mode: each turn you must **match or beat a target**
(one-up the competition) or lose a life; run out of lives and you're eliminated, last player standing
wins. This handoff covers the **home tile, setup, in-game cockpit (8 states), post-game**, and a
**palette-extension proposal**.

The cockpit **skeleton is reused verbatim** from the shipped X01/Gotcha cockpit — Frame + scanlines,
TopBar, the locked CRT board (760 px), MISS corners, ActionBar, and the player carousel pattern
(active card + peek cards + pills). **New design effort lives in the active-card content, life pips,
setup option controls, home tile, post-game stats, and the palette token.**

> **Revision 2026-07-16** (this is the rule authority — `one-up-design.md`): two variants
> (**BEAT THE LAST** / **BEAT THE BEST**), **tie = success** (was tie = fail), lives **1 / 3 / 5**,
> and a **random-order** toggle. Round events are explicitly **v2 — not designed here.**

## About the design files
The files in this bundle are **design references created in HTML/React (JSX via in-browser Babel)** —
prototypes showing intended look and behaviour, **not production code to copy directly**. The task is
to **recreate these artboards inside the DOSSEDART app** (Flutter — see `one-up-design.md` §5) using
its established widgets, tokens and patterns. The HTML is the visual fasit; the `.md` specs are the
**rule fasit** (behaviour authority). If an artboard implies behaviour different from the spec, **the
spec wins.** New feature ideas are marked **PROPOSAL** in a spec card and are parked by default.

> Terminology is locked: **1UP** (not "Legs"), **BEAT**, **NEED n MORE**, **SAFE**, **CAN'T BEAT**,
> **BEAT THE LAST / BEAT THE BEST**, **LIFE**, **ELIMINATED**, **1UP!**. All UI strings are **English**
> (a guard test fails the build on Norwegian strings).

## Fidelity
**High-fidelity.** The cockpit chrome, CRT dartboard, carousel, player-setup chrome, home-tile chrome
and post-game podium/stat-row pattern are **existing, QA'd components** — reuse as-is. Recreate the
**new elements** (active card, life pips, option chips, home grid, stat rows, palette token) pixel-faithfully.

---

## Rules that drive the UI (spec §2–§3)
- **Tie = success:** `turnTotal >= target` is safe; only a strictly lower total costs a life.
- `NEED = target − turnTotal` (no +1 — a tie counts). `CAN'T BEAT` triggers when `NEED > 60 × dartsLeft`.
- A turn is always **3 darts** (remaining darts pad your total, which can become the next target).
- **BEAT THE LAST** (default): target = the last actual 3-dart total thrown, continuous through the game.
  First player throws free. Match/beat → your total is the new target (tie leaves it unchanged). Fail →
  lose a life **and your lower total still becomes the target** (self-correcting; can't deadlock).
- **BEAT THE BEST:** round-based. Target resets each round; first thrower of the round throws free.
  Everyone must match/beat the round's running max. Fail → lose a life; the round max **never drops**.
  One big throw can cost several players a life in the same round, but dies with the round.
- **Random order** (toggle, default off): shuffles alive-player rotation each round.
- **0 lives → eliminated**; placements by elimination order. Undo restores lives / target / round-max /
  eliminations / rotation order.

---

## Screen: home (3×3 mode grid)
Full-screen dark arcade (`OUHome`). 3-column grid of mode tiles; tile chrome is reused, only the grid
goes 2→3 columns. The **1UP tile is lit** (shipped variant): lime border + glow + `NEW` badge.
**Golf** and **WILDCARD** show the dimmed **coming-soon** treatment (opacity 0.5, greyscale emoji, `SOON`).

## Screen: setup (1UP options)
`OUSetup` — reuses `PlayerSetupScreen` (player list + remove) and adds three option controls in the
existing chip/toggle pattern:
- **LIVES** chips `1 / 3 / 5` (1 = sudden death), default **3** selected.
- **VARIANT** chips `BEAT THE LAST` / `BEAT THE BEST`, default **LAST** selected (each with a one-line descriptor).
- **RANDOM ORDER** on/off toggle, default **off**.
- START CTA (lime→green gradient).

## Screen: 1UP in-game cockpit
**Frame:** 820 × 1180 px, portrait tablet. Vertical stack: TopBar (`◀ EXIT` · `🕹️ 1UP` · `n ALIVE`) ·
**carousel** · 720 px CRT board (locked, untouched) · ActionBar (`↶ UNDO` / `✗ MISS` / `⋯ MENU`).

### Active card (`OUActiveCard`) — the primary design surface
`border: 3px solid <frame>`, gradient fill, glow. `<frame>` = **GREEN** when SAFE, **RED** when
`cant`/`lastlife`, else the player's colour. `▶ NOW THROWING` tab top-left; **variant chip** top-right
(`BEAT THE LAST` or `BEAT THE BEST · R<n>`, lime).
- **Header:** avatar (player colour) · name · **life pips** · `LAST / LIFE` tag in last-life mode.
- **Primary line by mode:**
  - `open` → `FREE THROW · NO TARGET` (or `FIRST THROW · NEW ROUND` in BEST) + `SET THE TARGET` /
    `SET THE ROUND TARGET` (lime).
  - `safe` → `SAFE ✓` (green) + `NEW TARGET · <turnTotal> · building…`.
  - `default`/`cant`/`lastlife` → `BEAT` over the **target** (62px; red in danger).
  - Right block: `THIS TURN` + `turnTotal` (38px) + three dart pips (fill to `dartIdx`).
- **Status line:** `open` → sets-the-bar note · `default` → `NEED <n> MORE` + darts left ·
  `safe` → `... REMAINING DARTS PAD THE NEW TARGET` · `cant` → `CAN'T BEAT · LIFE AT RISK · need <n>, max <60×left>` ·
  `lastlife` → `NEED <n> MORE · MISS = ELIMINATED`.

### Life pips (`LifePips`) — new persistent element on every card
Hearts, one per max-life (1/3/5). Live `♥` in player colour + glow; spent `♡` at 18% white; **cracking**
`💔` red with `ouCrack` anim (the life-lost moment). Also on peek cards and in overlays.

### Peek cards / overlays
Compact neighbour cards (mini avatar + name + pips; eliminated = dimmed, `💀`, `OUT`). Full-frame
moment overlays (`OUOverlay`): **life lost** (`💔` + `−1 LIFE`), **elimination** (`💀 ELIMINATED` +
placement), **winner** (`★★★ 1UP! · <name> WINS · LAST PLAYER STANDING`).

### The 8 cockpit states (+ a BEAT THE BEST free-throw variant)
1. **Free throw** — `SET THE TARGET`. Game start (LAST) / every round start (BEST). No fail possible.
   *(1b artboard shows the BEAT THE BEST round free-throw with the variant chip.)*
2. **Default** — `BEAT 87` + `NEED n MORE`.
3. **SAFE** — `turnTotal >= target` (tie is safe): green card, building the new target.
4. **CAN'T BEAT** — `NEED` exceeds max possible → red, `LIFE AT RISK`. Player still throws out the turn.
5. **Life lost** — pip cracks (💔), `−1 LIFE` overlay.
6. **Last life** — persistent danger styling (red pulse, `LAST LIFE`, red pips).
7. **Elimination** — 0 lives → `ELIMINATED` overlay + placement; peek card → 💀, pill → grey.
8. **Winner** — last alive → `1UP!` overlay.

## Screen: post-game
`OUPostGame` — reuses `post_game_screen`. Winner banner + **placements by elimination order**
(winner first, podium metals). **Mode-specific stat rows:** highest turn, targets set, lives lost,
turns survived, saved on last dart. UNDO must work (Shanghai post-game undo protocol). Values shown are
illustrative fixtures.

---

## Palette extension (PROPOSAL — `OUPaletteCard`)
The 7 DOSSEDART accent tokens are all taken (magenta, cyan, yellow, green, red, purple, orange —
purple already shared by WILDCARD + Halve It), so 1UP needs its own brand accent.

**Proposed new token: `lime` = `#C6FF3C`** — role: *1UP / extra-life accent* (mode brand + free-throw
`SET THE TARGET` highlight). It fills the only open hue gap in the neon palette (~60–100°, between
yellow `#FFD200` and mint-green `#3DFF8E`), reads immediately as retro "1UP / extra life", and doesn't
collide with any of the 7 semantic roles. **Never used as a player colour** — player cards keep
`player_colors`. Danger/SAFE keep red/green; lime is mode identity only.

Used in the artboards: home-tile NEW glow, setup section labels + selected chip + START CTA, cockpit
variant chip + free-throw headline. **Implementation** adds `lime = Color(0xFFC6FF3C)` to
`DossedartTokens`; no other tokens change. Parked until approved.

## State management (spec §5)
- `GameMode.oneUp`, `OneUpConfig extends GameConfig { final int lives; final OneUpVariant variant; final bool randomOrder; }`,
  `enum OneUpVariant { beatTheLast, beatTheBest }`. Own screen on the Shanghai template.
- State per player: lives, alive/eliminated, current target (LAST) / round max + starter index (BEST),
  who set it, rotation order. Undo captures life loss, target/round-max changes, eliminations, rotation.

## Design tokens
- Player accents (from `player_colors`): CYAN `#00E5FF`, MAGENTA `#FF00AA`, GREEN `#3DFF8E`, YELLOW `#FFD200`.
- Semantic: GREEN (SAFE), RED `#FF3050` (danger / life lost / elimination), ORANGE `#FF7A00` (MISS/CTA),
  YELLOW (target labels / winner / metals), MAGENTA (chrome).
- **NEW (proposed):** LIME `#C6FF3C` (1UP brand).
- Surfaces: BG `#0a0014`, SURFACE `#1a0030`, PHOSPHOR `#D9D2C2`. Podium: silver `#C9D2DA`, bronze `#D08A4A`.
- Type: `"Press Start 2P"` (headings/numbers/labels), `"VT323"` (secondary/mono). No border-radius except pills/toggle.

## Assets
No raster assets — board/chrome drawn (SVG/CSS). Emoji glyphs: 🕹️ ♥ ♡ 💔 💀 ★ ✓ ✗ 🎯 🃏 ⛳ 🦗 🏙️ ✂️ 🕐.
Sounds `assets/sounds/one_up/` with TTS fallback (spec §6) — implementation-owned.

## Files in this bundle
- `DOSSEDART 1up cockpit.html` — entry point; loads React + Babel + the two JSX files.
- `one-up-cockpit.jsx` — all cockpit / active-card / life-pips / overlay components, the 8 states +
  BEAT THE BEST free-throw, the home / setup / post-game screens, the spec + palette fasit cards.
- `design-canvas.jsx` — pan/zoom artboard shell (presentation only; not app UI).
- `new-modes-design-brief.md` — design/implementation split (read first; rev. incl. the 1UP palette exception).
- `one-up-design.md` — the 1UP rule spec, **revised 2026-07-16** (behaviour fasit).

Start at the two fasit cards rendered in the HTML (`Spec · 1UP`, `Palette · PROPOSAL`) and
`one-up-cockpit.jsx`'s `OUActiveCard`, `LifePips`, `OUSetup`, `OUHome`, `OUPostGame`, `OUPaletteCard`.
