# Full Project Audit Report — 2026-07-06

**Scope:** whole app (v1.8.9+24, branch `fix/dossedart-x01-cockpit-fixes`), per
`docs/superpowers/specs/2026-07-06-full-project-audit-design.md`.
**Method:** automated health check + four parallel review passes (bugs,
duplication, tests, UI) + adversarial verification of every P0/P1 claim.
Every finding below was confirmed against the code; refuted or unprovable
candidates were dropped.

## Executive summary (plain language)

The good news: the app is in better shape than a 28 000-line hobby project has
any right to be. The analyzer reports **zero issues**, **all 66 test files
pass**, the notorious 10-minute test hang did not reproduce (and its root
cause was found), dependencies are healthy, and the two long-standing Shanghai
bugs from the backlog turned out to be **already fixed**.

The bad news clusters in exactly two places, and both are about *rare flows*,
not normal play:

1. **The post-game "Back" button.** Four modes save statistics *before* the
   result screen, so going Back and finishing again counts everything twice
   (double Elo, double games). Cricket has the opposite bug: it never
   re-records, so the undone result stays forever. Only Shanghai does it right.
2. **Managing players mid-game.** Removing or adding a player mid-game can
   soft-lock ATC, hard-freeze Cricket, corrupt Splitscore scores, crash
   Cricket/Killer on a later undo, and undo can resurrect removed players in
   four modes.

On top of that, one **P0**: the brand-new stats migration (committed today,
not yet on any device) can *worsen* the record it was built to fix, because it
reads turn data from all game modes — a full Killer game collapses into one
giant "turn". This must be fixed before the app is built or run.

Why did normal play feel fine while all this lurked? Because the everyday path
*is* solid — these bugs live in undo-after-finish and mid-game roster changes,
which testers rarely do and tests barely cover. That is also the structural
story of the codebase: six game screens each re-implement the same machinery
(turn rotation, undo, stats recording, audio wiring) with small differences,
and nearly every confirmed bug is a case of one copy missing a guard another
copy has. The fix plan therefore ends with *sharing that machinery*, so this
class of bug stops regrowing.

**Counts:** 1 × P0, 8 × P1, 14 × P2, 7 × P3.

---

## P0 — must fix before next build

### F1. New stats migration corrupts "best turn" with non-X01 data
- **Where:** `lib/services/stats_migration.dart:66-92` (`_fixBestTurn`);
  trigger data from `lib/screens/killer_game_screen.dart:287-295` +
  `lib/models/dart_throw.dart:24`.
- **What:** `_fixBestTurn` recomputes the record from **every** game in
  history, not just X01. Killer creates throws without a `turnId` (defaults to
  0), so an entire Killer game counts as *one turn* — the migration can write
  a "highest turn" of several hundred. Cricket/ATC throws also contaminate the
  max (a T20-T20-T20 cricket turn writes 180). This recompute path has no
  180 clamp.
- **User impact:** on first app start after this build, a player's all-time
  "best turn" record can jump to an impossible number — the exact bug the
  migration was written to fix, made worse.
- **Fix (product decision recorded 2026-07-06):** "best turn" is
  **X01-scoped**. Filter `_fixBestTurn` to X01 games (plus Splitscore, since
  live Splitscore code also writes `highestTurnScore` — keep data consistent
  with what live code writes, or change both). Killer must never count.
  Whether Cricket/Splitscore should feed the record later is a separate,
  optional product decision. Migration has not shipped — no repair migration
  needed if fixed now.

## P1 — user-visible wrong behavior or data corruption

### F2. Post-game "Back" double-records stats, Elo and history (X01, ATC, Killer, Splitscore)
- **Where:** record-before-show: `game_screen.dart:950`,
  `around_the_clock_game_screen.dart:477`, `killer_game_screen.dart:401`,
  `halve_it_game_screen.dart:277`; unconditional Back button
  `post_game_screen.dart:107-111`; undo handlers with no recorded-guard
  (`game_screen.dart:1388-1390` etc.).
- **What:** stats/Elo/game-history are persisted before the result screen;
  Back → undo → finish again runs the whole recording pipeline a second time.
- **User impact:** gamesPlayed +2, winner's wins +2, Elo applied twice
  (compounding), duplicate match in history — every time Back is used to fix
  a mis-entered final dart.

### F3. Cricket: the inverse — after Back, the real result is never recorded
- **Where:** `cricket_game_screen.dart:67` (`_statsRecorded`), set at
  `:662/:685`, never reset in `_undo` (`:372-401`).
- **What:** Cricket alone has a record-once guard, but undo doesn't reset it.
- **User impact:** finish → Back → different player wins → the *undone*
  outcome stays in stats/Elo/history forever; the real one is lost.
- **Fix for F2+F3 together:** one shared protocol. Recommended: Shanghai's —
  it defers recording until the user *leaves* the result screen
  (`shanghai_game_screen.dart:377-382`), which is verified correct. Port that
  to all five other modes (and give Shanghai its missing rating-delta display,
  F17).

### F4. X01/ATC sudden death writes "checkout 999" into permanent records and falsely unlocks achievements
- **Where:** `game_screen.dart:966-973` (score set to 999), `:660-663`
  (bestCheckout = last throw's `scoreAtStartOfTurn`), persisted via
  `stats_recorder.dart:71-72`; achievements `achievement_catalog.dart:423,433`;
  ATC analog `around_the_clock_game_screen.dart:548-554`.
- **What:** tie-break (two identical checkouts in the same round) starts
  sudden death with scores parked at 999; that 999 flows into "best checkout"
  for **both** players and unlocks the ≥100 and ≥170 checkout achievements
  neither earned. Undo during/after sudden death leaves half-rewound state
  (one player live at score 999; ATC stuck in sudden-death with reset targets).
- **User impact:** impossible "Out: 999" on the result screen, permanent fake
  PB and fake achievements; a broken game state if Back is pressed.
- **Fix:** record checkout from the pre-sudden-death finish; exclude SD throws
  from turn/checkout stats; block or properly rewind undo across the SD
  boundary. Existing corrupted values (>170 checkouts) can be clamped by the
  same migration touched in F1.

### F5. ATC: removing a player mid-round makes the game unfinishable
- **Where:** `_isRoundComplete` `around_the_clock_game_screen.dart:435-444`
  (missing the `finishedPlayers` skip X01 has at `game_screen.dart:795`);
  removal `:1753-1765`.
- **What:** a player removed before completing the current round is never
  marked round-complete, so the round never resolves and pending finishes
  never resolve — no winner, no result screen, ever.
- **User impact:** the game announces "finishes!" but never ends; only
  quitting escapes (result lost).

### F6. Splitscore: removing the current player corrupts scores
- **Where:** `halve_it_game_screen.dart:1748-1752` (turn state not reset),
  `:1762-1768` (modulo-wrap advance vs linear-scan `_finishTurn` `:307-330`).
- **What:** (a) the next player inherits the removed player's turn points and
  halving immunity; (b) removing the last player in rotation wraps to player 0
  in the *same* round — earlier players replay the round and their totals
  double-count.
- **User impact:** phantom points and wrong final ranking in the mode where
  ranking is the whole game.

### F7. Cricket: removing players can hard-freeze the app
- **Where:** `_advancePlayer` `cricket_game_screen.dart:357-359` (no
  loop-guard; X01 has one at `game_screen.dart:765-776`); removal `:1711-1723`
  (no "≤1 active → end game" rule); sheet counts finished players as active
  (`dossedart_player_sheet.dart:87-91`).
- **What:** with ≥2 genuinely finished players, the sheet lets you remove the
  last truly-active players; rotation then spins forever inside `setState`.
- **User impact:** total UI freeze, force-kill required, game lost. (Even
  without the freeze: no mode except X01 ends the game when ≤1 player
  remains.)

### F8. Cricket/Killer: undo after adding a player mid-game crashes or corrupts
- **Where:** cricket snapshot restore `cricket_game_screen.dart:387-390` vs
  add `:1691`; killer wholesale list restore `killer_game_screen.dart:589-592`.
- **What:** undo snapshots taken before the add have the old list length;
  undoing across the add boundary throws RangeError (Killer: on next render;
  Cricket: mid-`setState`, leaving half-applied state). X01/ATC/Splitscore are
  safe (per-index restore); Shanghai clears its undo stack on add/remove.
- **User impact:** red error screen or silently corrupted game right after
  the very reasonable sequence "add late-arriving friend, then undo a dart".

### F9. Undo resurrects removed players (X01, Cricket, ATC, Killer)
- **Where:** removal encoded only in `finishedPlayers`/`isEliminated`
  (`game_screen.dart:2127-2135` etc.); undo clears exactly that
  (`game_screen.dart:1163-1173`, `cricket:380`, `atc:819-828`, `killer:591`);
  `_removedPlayerIndices` never consulted by undo.
- **What:** in Cricket/Killer *any* undo after a removal restores a
  pre-removal snapshot; in X01/ATC undoing back to the removed player's throw
  puts them back as the active thrower.
- **User impact:** a "removed" player the game demands must throw, rendered
  dimmed, excluded from results — a ghost in the rotation.

## P2 — real defects, smaller blast radius

- **F10. Shanghai + mid-game changes: history entry with placement 0.**
  `shanghai_game_screen.dart:259-268,316-329` — unlike the other five modes,
  Shanghai still persists a history entry after roster changes, storing
  placement 0 for the removed player (sorts above 1st in match views), and
  never records join/leave counters. Align with the other modes' protocol.
- **F11. ATC "Best finish" records the worst finish.**
  `around_the_clock_game_screen.dart:923-924` uses a `max:` counter for dart
  count, where fewer is better. A 25-dart PB is overwritten by any slower
  finish, forever. Needs a `min:` semantics + one-time repair of stored values.
- **F12. Cricket Bull progress bar shows closed at 2 of 3 marks.**
  `cricket_game_screen.dart:1322-1323` (`maxMarks = isBull ? 2 : 3`) vs the
  engine's `>= 3` (`:122-123`). Cosmetic but misleading mid-game.
- **F13. Shanghai dart-slot display desyncs on undo across a turn boundary.**
  `shanghai_game_screen.dart:404-413, 363-375` — `_turnHits` can't be restored
  once cleared; post-game undo never touches it. Cosmetic.
- **F14. One corrupt read wipes all game history.**
  `game_history_service.dart:13-17` returns `[]` on decode error and
  `record()` then overwrites the store with a single entry. Keep the raw
  string on decode failure (backup key) instead of silently discarding 200
  games. Same pattern worth checking in `player_storage.dart`.
- **F15. X01's in-game sound toggle silently disables memes app-wide.**
  `game_screen.dart:1617-1621` writes both settings from one switch; other
  modes don't. Related drift: X01 gates miss-memes on `_soundEnabled`, the
  rest on `_memeEnabled` (`game_screen.dart:1092-1104` vs e.g.
  `cricket:339-351`); offensive-sounds toggle only reachable in X01's dialog.
- **F16. Shanghai bypasses GameAnnouncer,** so the per-category TTS settings
  (next player / throw result / winner) have no effect there
  (`shanghai_game_screen.dart:210,242-243`); it also never announces the next
  player. Plus: TTS-enabled state is read four different ways across modes —
  only Shanghai's is race-free (the exact invariant from the TTS-init
  regression).
- **F17. Shanghai result screen shows no rating changes** — the only mode
  without Elo deltas, because recording is deferred (`:336-352`); fixing F2/F3
  via the Shanghai protocol must add a pre-computed delta display, as Cricket
  comments already note (`cricket:660-664`).
- **F18. The flaky 10-minute test hang: root cause found.**
  `VideoService` is enabled by default in unit tests
  (`video_service.dart:14`), and a *random* 1-in-N roll
  (`game_screen.dart:342,462-463`) pushes a modal overlay that renders a
  perpetual spinner (`video_overlay.dart:96-99`) → the next `pumpAndSettle`
  spins to its 10-minute timeout. Intermittent-by-RNG matches the symptom
  exactly; `integration_test/helpers/test_app.dart:73-76` already documents
  it. Fix: disable VideoService (and the 35s ArcadeFrame beam + 30s
  BatterySampler timers) globally in test setup.
- **F19. The three game engines are orphans — the app's best tests guard code
  that never runs.** `lib/engines/{x01,cricket,atc}_engine.dart` are imported
  by nothing in `lib/`; screens carry parallel implementations that have
  already drifted (the engine lacks no-bust and sudden death). ~900 lines of
  solid engine tests give false confidence. Shanghai proves the fix pattern:
  its engine (`lib/models/shanghai_engine.dart`) *is* production code, and it
  is the mode with the fewest confirmed bugs and the shortest screen.
- **F20. Highest-risk test gaps** (beyond F19): `EloService` — zero tests for
  the app's headline number (K-factor switch, multi-player scaling, rating
  floor, guest filtering); `StatsRecorder.recordGame` — H2H, rating history,
  `max:` counter merge untested; `checkout_table.dart` (257 lines) — no test
  that suggestions are valid or end on a double; Splitscore's core halving
  rule unasserted; `PlayerStorage` has no corrupt/legacy-JSON tests.
- **F21. UI language is mixed** against the "UI text: English" rule —
  Splitscore cockpit is Norwegian, Killer and Shanghai mix NO/EN, X01/
  Cricket/ATC are English; KAMPDETALJER/stats surface is Norwegian. Needs one
  decision (English per CLAUDE.md, or change the rule) applied everywhere.
- **F22. The four-role color contract only governs half the app.** The entire
  DOSSEDART path runs on a second, undocumented palette
  (`lib/theme/dossedart_tokens.dart`) used directly in ~20 files, never via
  `colorScheme`. The contract and the main design track have formally
  diverged — either bless the tokens in the spec (recommended: they *are* the
  design) or migrate them into the theme. Plus 17 concrete violations on the
  classic path (blue/green/red literals, alpha-hacked pseudo-roles — worst:
  `stats_screen.dart`, `mid_game_player_sheet.dart`, killer's blue shields),
  podium hex literals on home, and two undocumented board-rendering palettes
  (`dart_board.dart`, `dossedart_x01_dartboard.dart`) that should be listed
  exceptions.
- **F23. Outline-rule drift:** 0.5px/1.5px outlines in cricket/halve_it
  classic (`cricket:1484,1442`, `halve_it:1034,1251`), one 1.5px stray in the
  DOSSEDART setup kit (`dossedart_picker_tile.dart:138`), active-border 3px
  vs 2px inconsistency (Killer/ATC vs the rest), and three different
  magenta-divider strengths across cockpit chrome.

## P3 — polish / housekeeping

- **F24.** "Halve It" remnant on the DOSSEDART home grid
  (`dossedart_home_screen.dart:362`) — the one user-visible rename miss; also
  mode emoji differs between classic (➗) and DOSSEDART (✂️) homes.
- **F25.** Delete four dead widgets (zero references):
  `checkout_widget.dart`, `clock_progress.dart`, `cricket_scoreboard.dart`,
  `halve_it_scoreboard.dart`.
- **F26.** Remove-player dialog copy/color differs across modes (`Colors.red`
  literal in cricket/shanghai; two different warning texts).
- **F27.** `.claude/` is untracked local config — add to `.gitignore`.
  `docs/design/dossedart-handoff/DOSSEDART (3).zip` is a dangling duplicate of
  the extracted design folder — commit or delete.
- **F28.** `battery_plus` one major behind; win32 override pinned. No action
  urgent.
- **F29.** Elo with guests: `1/(n-1)` scaling counts guests, so ratings move
  ~3× less in a 2-saved+2-guest game (`elo_service.dart:74`). Matches its doc
  comment — decide if intended, then test it (F20).
- **F30.** X01 `canContinue` counts removed players (`game_screen.dart:1376`).

## Automated health check (baseline)

| Check | Result |
|---|---|
| `flutter analyze` | 0 issues |
| Test suite (9 batches, incl. `test/screens`) | all pass; hang not reproduced |
| `flutter pub outdated` | minor drift only; battery_plus 1 major behind; win32 pinned |
| Version consistency | pubspec 1.8.9+24 == home_screen v1.8.9 |
| Known Shanghai post-game-undo bug | **already fixed** (deferred recording + push) |
| Known Shanghai instant-trigger gap | **already fixed** (winner video + TTS; no dedicated asset) |

## Recommended fix plan

Work on this branch (release-train), one round = one reviewable chunk, tests
per fix. Effort: S ≈ under an hour, M ≈ half a day, L ≈ days.

1. **Round 1 — Data integrity (do first): F1, F2+F3, F4.** (M)
   F1 is a three-line filter + tests. F2/F3: port Shanghai's
   defer-until-leave protocol to all modes (+ F17's delta display). F4:
   sudden-death stat exclusion + undo guard. This round stops all ongoing
   stat corruption.
2. **Round 2 — Mid-game roster rules: F5-F9 (+F26, F30).** (M-L)
   One shared rule-set: removal marks state consistently, resets turn state,
   ends the game at ≤1 active, guards rotation loops, and clears/patches undo
   stacks across roster changes (Shanghai's approach, already proven).
3. **Round 3 — Small confirmed bugs: F10-F14.** (S-M)
4. **Round 4 — Consistency pass: F15-F16 audio drift, F21 language decision,
   F22-F23 palette/outline, F24.** (M) Pairs naturally with the planned
   design-consistency pass.
5. **Round 5 — Structure & tests: F18 (test-hang fix), F19 (wire engines in,
   start with Cricket — smallest engine, and its screen holds the worst
   rotation bugs), F20 (Elo/StatsRecorder/checkout-table tests), F25.** (L)
   This is the round that keeps rounds 1-4 from regressing.

Rounds 1-3 fix everything a player can notice. Round 5 is the investment that
makes the six-screens problem stop producing new bugs; the duplication audit's
full extraction map (game-end pipeline → roster management → audio wiring →
engines) is in the appendix below if we go further.

## Appendix: duplication map (for Round 5 planning)

Shared machinery re-implemented per screen, ordered by extraction value:
1. Game-end pipeline (ratings snapshot → Elo → achievements → record →
   post-game) — 6 near-identical copies; all of F2/F3/F10/F17 live here.
2. Mid-game roster management — 6 copies + 6 sheet-openers; F5-F9 live here.
3. Audio/TTS/meme wiring — verbatim `_onMiss` ×5, meme dialog ×5; F15/F16.
4. Rotation + round resolution + sudden death — X01/ATC pair nearly identical
   (F4); Cricket/Killer loops unguarded (F7).
5. Classic scaffold (AppBar/bottom bar/`_confirmExit` ×6) — classic is the
   **default** UI (`app_settings.dart:28`), so this is live code, not legacy.
6. Undo — three architectures (replay / stack objects / engine); converge on
   engine-side undo as modes adopt engines.
