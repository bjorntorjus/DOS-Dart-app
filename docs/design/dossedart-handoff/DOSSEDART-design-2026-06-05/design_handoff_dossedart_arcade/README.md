# Handoff: DOSSEDART — Arcade Redesign

## Overview
A full visual redesign of the DOSSEDART darts-scoring app into a cohesive **retro-arcade / CRT** aesthetic. It covers every screen: the six game cockpits, the pre-game and post-game flow, the meta screens (statistics, settings), in-game sheets and celebration moments, and an achievements concept. The goal of this work was a **design refresh** — look, feel, layout and consistency — **not** changes to game logic or features.

## About the design files
The files in this bundle are **design references authored in HTML/React (Babel-in-browser)** — prototypes that show the intended look, layout, and behavior. They are **not production code to copy verbatim**.

The app itself is **Flutter/Dart** (see the existing repo: `lib/screens/...`, `lib/widgets/dossedart/...`, `lib/theme/dossedart_tokens.dart`, `lib/engines/...`). The task is to **recreate these designs in the existing Flutter codebase**, using its established widgets, theme tokens, and engines. Much of the arcade chrome already exists in `lib/widgets/dossedart/` (e.g. `arcade_frame.dart`, `dossedart_crt_frame.dart`, the X01 cockpit widgets, `DossedartSetupScaffold`, `DossedartMenuSheet`) — extend that, don't rebuild from the HTML.

Each design HTML contains, on its design canvas, a **paper "Implementasjon"-spec card** (in Norwegian) that maps the screen to exact color tokens, the data/engine it binds to, and a short list of build notes / fixes. **Those spec cards are the per-screen source of truth** — read them alongside this README.

## Fidelity
**High-fidelity.** Final colors, typography, spacing, and layout. Recreate pixel-faithfully using the codebase's existing DOSSEDART theme + widgets. Screens are designed at a **820×1180 portrait** canvas (phone); scale/adapt to real device metrics.

---

## Design system (locked, used everywhere)

### Color tokens
| Token | Hex | Role |
|---|---|---|
| YELLOW | `#FFD200` | targets / labels / 1st place / champion / "live" target zone |
| MAGENTA | `#FF00AA` | chrome — frames, borders, dividers, table lines |
| CYAN | `#00E5FF` | **active player / "you"** / navigation / primary action |
| GREEN | `#3DFF8E` | success · closed (cricket) · done (ATC) · shields (killer) · ELO ▲ · "safe" |
| RED | `#FF3050` | danger · lives/hearts · **enemies (Killer)** · bust · halved · ELO ▼ |
| ORANGE | `#FF7A00` | MISS · armed/KILLER status · chrome accent |
| PURPLE | `#7B3FFF` | X01 board felt accent · player-order (random) toggle |
| BG | `#0A0014` | screen background / board background |
| SURFACE | `#1A0030` (≈`#160A2B`) | cards / panels |
| PHOSPHOR | `#D9D2C2` | inactive content / opponents (non-active) |
| SILVER / BRONZE | `#C9D2DA` / `#D08A4A` | 2nd / 3rd place |

`dossedart_tokens.dart` already holds most of these — align names there.

### Typography
- **Press Start 2P** — headings, scores, big numbers, labels (the arcade voice)
- **VT323** — secondary labels, meta text, hints
- **Inter** (600/700) — player names & longer readable copy (names use Inter, not the pixel font, for legibility)
- **Archivo 900** — oversized display numbers (e.g. 180!, checkout total)
- **JetBrains Mono** — spec/handoff cards only

### Shared chrome
- CRT treatment: horizontal **scanline** overlay + radial **vignette** on every screen (`dossedart_crt_frame.dart` / `arcade_frame.dart`).
- **Top bar**: `◀ EXIT/HJEM` · centered mode/title (yellow) · right-side context (round/legs/credits).
- **Action bar** (in-game): `↶ UNDO` (magenta) · `✗ MISS` (orange, wide) · `⋯ MENU` (cyan).
- **One color logic** (no per-player rainbow): the active player / "you" is **cyan**; everyone else is **phosphor** — except **Killer**, where all enemies are **red** (see that screen).

### Identity rules (locked decisions)
- **Avatars** = the player's **photo** when available, else a **neutral person silhouette** in a colored ring. **Never initials/handle letters** (players can share initials).
- **Full names** everywhere, never 3-letter abbreviations.
- **No emoji** — all icons are simple inline SVG glyphs (brand is pixel/arcade).
- Entrance animations gate on reduced-motion; base/end state must be visible without animation.

---

## Screens / Views

> Each screen's design HTML carries its own detailed spec card. Summaries + codebase targets below.

### Game cockpits (820×1180)
1. **X01** — `DOSSEDART x01 cockpit final.html`. Full dartboard (TWILIGHT palette, geometry-exact to `dossedart_x01_dartboard.dart`) maximized; surrounding field = MISS. Active card shows REMAINING in the player's accent, legs/round in top bar, checkout suggestion. → `lib/screens/.../x01`, `x01_engine.dart`.
2. **Cricket** — `DOSSEDART cricket cockpit final.html`. The scoreboard **is** the input: active player's column expands to tappable S/D/T cells per target (20–15, BULL); opponents show read-only phosphor glyph marks (`/ X ⊗`). A target is only dead when ALL have closed it. → `cricket_game_screen.dart`, `cricket_scoreboard.dart`, `cricket_engine.dart`.
3. **Around the Clock** — `DOSSEDART atc cockpit final.html`. Hero **clock ring** of 1→20: done segments green, current target cyan + pulsing, big center number + progress arc; opponents = compact phosphor meters; input = S/D/T cells (D/T = ×N advances multiple steps). → `around_the_clock_game_screen.dart`, `atc_engine.dart`.
4. **Killer** — `DOSSEDART killer cockpit final.html`. Full board, ownership shown **purely by color**: your number = bright cyan, **all enemies = red**, an enemy on their last life **blinks**; a thin status-key strip maps number→full name→lives (+ armed/shield). → `killer_game_screen.dart`.
5. **Splitscore (Halve It)** — `DOSSEDART splitscore input.html`. Player scores on top, a red **jeopardy bar** ("hit or halve → N"), and an **adaptive input** (no full board): number round → `n / Dn / Tn` cells; double/triple round → a 1–20 keypad at ×2/×3 (+ D-BULL); bull round → BULL/D-BULL. A "board" alt also exists (dimmed except the live zone). → `halve_it_game_screen.dart`, `halve_it_round.dart`, `HalveItConfig.generateRounds()`.
6. **Shanghai** — `DOSSEDART shanghai cockpit final.html`. The three S/D/T cells **are** both the input and the Shanghai chase (light green as hit); gold banner counts toward the instant win; scores on top, round ladder 1→N below. → `shanghai_game_screen.dart`, `shanghai_engine.dart`.

### Pre / post game
7. **Setup** — `DOSSEDART setup final.html`. The shared `DossedartSetupScaffold` (top bar · REGLER · VELG SPILLERE · START). Picker tiles use photo-or-silhouette avatars + full names + last-5 form pips + P-slot; uniform tile size; the **TILFELDIG REKKEFØLGE** (random order) toggle lives in the player section (it's about order, not rules). Shown for X01 + ATC to prove the scaffold is shared (only REGLER differs). → `dossedart_setup_scaffold.dart`, `dossedart_player_picker.dart`, `dossedart_*_setup_screen.dart`.
8. **Post-game** — `DOSSEDART postgame screen final.html`. Winner spotlight (crown, avatar, headline stat + ELO) over a full **SLUTTSTILLING** list (placement gold/silver/bronze, per-mode stat line, ELO ▲/▼); actions ANGRE / OMKAMP / HJEM (+ FORTSETT when eligible); settings/stats entry points in the header. → `post_game_screen.dart`, `game_result.dart`.

### Meta
9. **Statistics** — `DOSSEDART statistics screen.html`. A tabbed hub: **PROFIL** is the per-player main page (KAMPER/SEIRE/TAP/SNITT, win ring, ELO rating-history graph, per-mode summary, and the **achievements** section with full cards), **MODUS** (per-mode leaderboard / detail), **HEATMAP** (throw heat on the board), **HISTORIKK** (recent matches). Achievements live on the profile — **not** a separate tab. → `stats_screen.dart`, `saved_player.dart` (`ModeStats`/`H2HRecord`/`RatingSnapshot`), `game_history.dart`, `heatmap_board.dart`.
10. **Settings** — `DOSSEDART settings screen.html`. Full preferences form, arcade-skinned: Handicap · ELO (K-factors/threshold) · Text-to-speech (+ per-event toggles) · Sound & video · Memes · Log mode · Experimental · Feedback. Controls map 1:1 to existing `AppSettings`/`TtsService`/`EloService` calls. → `settings_screen.dart`, `app_settings.dart`.

### In-game moments & sheets
11. **Celebration overlays** — `DOSSEDART celebration overlays.html`. Two end-of-match **takeovers**: **VINNER** and **SHANGHAI!** (dimmed ghost-board + ray-burst + confetti), dismiss → post-game. Mid-turn moments (180, checkout, bullseye, bust, 3-misses) are intentionally **left to the existing video/sound clips** (`video_service.dart`, `sound_service.dart`, `assets/videos/*`, `assets/sounds/*`).
12. **In-game sheets** — `DOSSEDART ingame sheets.html`. The `⋯ MENU` bottom sheet (sound/video/memes/voice toggles + SPILLER-OVERSIKT + AVSLUTT KAMP) and a merged **SPILLER-OVERSIKT** sheet that shows standings **and** lets you remove (min 2 active) / add saved players — replaces the Material `mid_game_player_sheet.dart`. → `dossedart_menu_sheet.dart`, `mid_game_player_sheet.dart`.
13. **Killer assignment** — `DOSSEDART killer assignment.html`. Pre-game "throw to claim your number": board with claimed numbers dimmed + locked, active claimer cyan, roster of who claimed what, and a red "{n} ER TATT — kast igjen" feedback state. → `killer_game_screen.dart` (`KillerPhase.assignment`).

### Entry
14. **Home** — `DOSSEDART home.html`. **Today's home design kept** (INSERT COIN marquee, DOSSEDART wordmark, HIGH SCORES podium, X01 301/501/701 row, modes grid, footer STATS/HISTORY/SETTINGS) — the only change: avatars use **photo-or-silhouette** (no initials). → `dossedart_home_screen.dart`. *(Note: an alternative fuller "game-select" home — `home-final.jsx` / older drafts — was explored and **not** adopted.)*

### Concept (not finalized for build)
15. **Achievements** — `DOSSEDART achievements concept.html`. Badges earned from real stats (180s, checkouts, Shanghai, Killer kills, ELO milestones…), shown on the statistics profile + a "se alle" gallery + unlock popup/toast. Hexagon medals, tier color (bronze/silver/gold), rarity shown as **"X% har denne"** where the **text color** encodes rarity. Decided defaults: integrated in statistics (no own tab), one-time, local rarity, ~18 badges + hidden, popup both mid-game + match-end, prestige-only at launch. Read the concept card before building; no `Achievement` model exists yet.

---

## Interactions & behavior
- **Input → engine**: every tap maps to the mode's existing engine call — `engine.applyHit(segment, multiplier)` / `recordThrow(type)` / `round.isHit/pointsFor(...)`. **No new game logic** is introduced by this redesign.
- **Active turn**: the throwing player is highlighted cyan across all cockpits; dart-dots show dart 1–3/3.
- **MISS / UNDO / MENU**: consistent action bar in all cockpits.
- **Celebration**: takeover waits for tap → post-game; reduced-motion shows end-state.
- **Setup**: START disabled until min players (Killer ≥ 2, others ≥ 1); random-order shuffles play order at start.

## State / data sources
All from existing models — `SavedPlayer` (rating, gamesPlayed/Won, `modeStats`, `headToHead`, `ratingHistory`), `GameResult`/`GameHistory`, per-mode engine state, `AppSettings`. Avatars from `SavedPlayer.avatarPath`. No new persistence required except (future) an `Achievement` definition+unlock store.

## Assets
- Fonts: Press Start 2P, VT323, Inter, Archivo, JetBrains Mono (already bundled / Google Fonts).
- Sounds/videos for celebrations already exist under `assets/sounds/*` and `assets/videos/*`.
- No new image assets; player photos come from each `SavedPlayer`.

## Files in this bundle
Each screen = an HTML entry point + its JSX. Shared: `design-canvas.jsx` (the review-canvas wrapper; **not** part of the app — it only arranges the artboards for review). Open any `DOSSEDART *.html` in a browser to view; the paper spec card next to each design holds the per-screen detail.
```
DOSSEDART x01 cockpit final.html        + x01-cockpit-final.jsx
DOSSEDART cricket cockpit final.html    + cricket-cockpit-final.jsx
DOSSEDART atc cockpit final.html        + atc-cockpit.jsx
DOSSEDART killer cockpit final.html     + killer-cockpit.jsx
DOSSEDART splitscore input.html         + splitscore-cockpit.jsx
DOSSEDART shanghai cockpit final.html   + shanghai-cockpit.jsx
DOSSEDART setup final.html              + setup-final.jsx
DOSSEDART postgame screen final.html    + postgame-screen.jsx
DOSSEDART statistics screen.html        + statistics-screen.jsx
DOSSEDART settings screen.html          + settings-screen.jsx
DOSSEDART celebration overlays.html     + celebration-overlays.jsx
DOSSEDART ingame sheets.html            + ingame-sheets.jsx
DOSSEDART killer assignment.html        + killer-assignment.jsx
DOSSEDART home.html                     + home-variants.jsx
DOSSEDART achievements concept.html     + achievements-concept.jsx
design-canvas.jsx   (shared review wrapper)
```
```
