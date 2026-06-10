# DOSSEDART Arcade Redesign — Roadmap

> **This is a roadmap, not a task-level plan.** Per the writing-plans skill's scope check, this
> redesign spans multiple independent subsystems (15 screens). It is broken into one detailed
> per-screen plan at build time — this document decides *what* gets built, *in what order*, and
> *what is explicitly out of scope*. Detailed bite-sized plans live next to this file as
> `2026-06-08-dossedart-<screen>.md` and are written one at a time when a screen is picked up.

**Source of truth:** `docs/design/dossedart-handoff/DOSSEDART-design-2026-06-05/design_handoff_dossedart_arcade/`
— the bundle's `README.md` plus each screen's embedded "Implementasjon" spec card.

**Goal:** Recreate the locked arcade/CRT redesign across the whole app in the existing Flutter
codebase, extending existing DOSSEDART widgets/tokens/engines. **Look only — no new game logic.**

---

## Scope verdict (verified against code, 2026-06-08)

The handoff README claims "design refresh, not features." I verified each spec card's claims
against the actual engines/models. **Confirmed: this is a reskin project.** Every game mechanic
the design references already exists:

| Design reference | Reality in code |
|---|---|
| Cricket `isClosedByAll(target)` | `cricket_engine.dart:48` ✓ |
| ATC per-player `currentTarget` + D/T step-advance | `atc_engine.dart:37` ✓ |
| Killer `lives` / `shields` / `isKiller` / assignment phase | `killer_game_screen.dart:45-48`, `KillerPhase.assignment` ✓ |
| Shanghai instant-win | `shanghai_game_screen.dart:325` (`isInstantShanghai`) ✓ |
| Splitscore halving rounds | `halve_it_round.dart` ✓ |
| ELO rating-history graph | `_RatingGraphPainter` in `stats_screen.dart` ✓ |
| Stats tabs | already a `TabController` hub ✓ |
| Mid-game add/remove players | already exists ✓ |

### Genuinely new functionality — ALL DEFERRED (Bjørn, 2026-06-08)

These are the only three things the design needs that don't exist. None are built in this redesign:

1. **Achievements ("PRESTASJONER")** — no `Achievement` model exists. Full feature (model +
   unlock logic + rarity + 4 UI surfaces + popup/toast). → **Own job, later.** README itself marks
   it "concept, not finalized for build."
2. **Last-5 form pips** on setup picker tiles — `SavedPlayer` has no recent-results tracking
   (verified: no field). → **Dropped this round.** Build setup tiles without pips, as today.
3. **VINNER / SHANGHAI! celebration takeover overlays** — new full-screen UI; today the winner
   moment is a video clip (`VideoService` 'winner') + post-game screen. → **Keep today's video.**
   Do not build the takeover overlay now.

Everything else below is pure visual restyling against existing data and engine APIs.

---

## Foundations & shared chrome (build once, reused everywhere)

The locked design system defines shared chrome used by all 6 cockpits and most meta screens.
Build/extend these first so every screen reuses them (consistency principle: identical
AppBar / action-bar / scoreboard / palette across modes).

- **Tokens** — `lib/theme/dossedart_tokens.dart` already holds bg/surface/magenta/cyan/yellow/
  green/red/purple/orange. **Add:** `phosphor #D9D2C2`, `silver #C9D2DA`, `bronze #D08A4A`.
- **Typography** — Press Start 2P (headings/scores), VT323 (meta), Inter 600/700 (names),
  Archivo 900 (oversized display), JetBrains Mono (spec cards only). Confirm all bundled.
- **Shared cockpit chrome** — top bar (`◀ EXIT/HJEM` · centered yellow title · right context),
  action bar (`↶ UNDO` magenta · `✗ MISS` orange wide · `⋯ MENU` cyan), active strip. Already
  largely exists in `lib/widgets/dossedart/x01/` — extract the reusable parts so cockpits 2-6 share them.
- **Avatar helper** — photo-or-silhouette (never initials), used by home/setup/post-game/picker.
- **One-color logic** — active player = cyan, everyone else = phosphor (except Killer: enemies = red).

---

## Priority & ordering

### Phase 1 — Finish X01 cockpit (close the open branch) ← START HERE
We are already on `fix/dossedart-x01-cockpit-fixes` with 2 uncommitted fixes. The dartboard color
problem (the original blocker) is now answered by the **TWILIGHT palette** in the X01 spec card.
- Apply TWILIGHT dartboard palette + black board bg (`#0A0014`) per `DOSSEDART x01 cockpit final.html`.
- Keep the touch fix (`HitTestBehavior.opaque`) — already done, mode-independent.
- Re-evaluate the MISS-glow bump and "last-3" against the final design before keeping.
- Per-player accent on active card; real legs in top bar; maximize board (drop frame, glow only).
- **Output:** X01 cockpit final + the reusable chrome widgets Phase 2 depends on.

### Phase 2 — Remaining 5 cockpits (each its own plan, reuse Phase 1 chrome)
Pure reskin to shared chrome + a mode-specific hero. No engine changes.
- **Cricket** — scoreboard *is* the input (active column → S/D/T cells; opponents read-only phosphor glyphs).
- **ATC** — clock-ring hero (1→20, done=green, current=cyan pulse); compact opponent meters.
- **Killer** — battle board, ownership by wedge color (you=cyan, enemies=red, last-life blink) +
  status-key strip. **Plus** the assignment-phase UI (`KillerPhase.assignment` already exists —
  `DOSSEDART killer assignment.html`).
- **Splitscore** — scorecard hero + red jeopardy bar + adaptive input (cells / keypad / bull).
- **Shanghai** — three chase cells (input + Shanghai tracker), scorer top, round ladder bottom.

### Phase 3 — In-game sheets (shared by all cockpits)
- Menu sheet (`DossedartMenuSheet`) — already arcade-styled; align toggles.
- Merge standings + add/remove into one arcade **SPILLER-OVERSIKT** sheet, replacing the Material
  `mid_game_player_sheet.dart`. (Logic exists — UI swap only.)

### Phase 4 — Pre/post/meta screens
- **Setup** — `DossedartSetupScaffold`: photo-or-silhouette avatars, full names. **No form pips** (deferred).
- **Post-game** — champion spotlight (crown/avatar/headline stat/ELO Δ) + SLUTTSTILLING list;
  same action contract (ANGRE/OMKAMP/HJEM/FORTSETT). Binds to existing `GameResult.stats`.
- **Settings** — arcade-skin the existing form (toggle/slider/segmented/select). Binds 1:1 to
  existing `AppSettings`/`TtsService`/`EloService`. No new storage.
- **Home** — locked layout; **only** swap avatars to photo-or-silhouette.
- **Statistics** — reorg the existing tab hub to PROFIL/MODUS/HEATMAP/HISTORIKK, arcade-skinned.
  ELO graph + heatmap already exist. **Achievements section omitted** (deferred to its own job).

### Deferred (own jobs, not part of this redesign)
- Achievements feature (model + logic + UI).
- Last-5 recent-results tracking on `SavedPlayer` (unblocks setup pips later).
- VINNER/SHANGHAI celebration takeover overlays.

---

## Notes
- **Branch/release:** continue the release-train convention — one langlevd branch for the redesign
  milestone; CI/push only when Bjørn says. Version bumps at APK-build time.
- **Consistency:** chrome built in Phase 1 is the single source for all cockpits — do not fork per mode.
- **Per-screen plans** get written with the writing-plans skill when each phase/screen is picked up.
