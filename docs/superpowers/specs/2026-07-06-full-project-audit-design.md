# Full Project Audit — Design Spec

**Date:** 2026-07-06
**Status:** Draft for review
**Author:** Bjørn + Claude

## Goal

A full review of the dart app producing a single prioritized findings report,
followed by fix rounds in priority order. The report must be readable by a
non-developer: every finding explains what it means for the app's users, gets a
severity grade, and the report ends with a recommended fix plan — not just a
list.

## Non-goals

- No fixes during the audit itself (report first, then fix rounds).
- No performance-optimization push — the app feels fast; the 2026-04-23 audit
  was parked deliberately. Performance findings are only reported if they are
  actual bugs (e.g. runaway rebuilds), not speculative optimizations.
- No unrequested features. Findings are about existing code, not new ideas.

## Deliverable

`docs/superpowers/audit/2026-07-06-audit-report.md` — one report with:

- Executive summary in plain language.
- Findings graded **P0** (real bug, must fix) → **P3** (nice to have), each
  with: what it is, where (file:line), what a user of the app would notice,
  and suggested fix.
- A recommended fix plan (order + rough effort) — the product-manager call.

Every finding is verified against the code before it enters the report; no
"maybe" findings.

## Phases

### Phase 0 — Clean the workbench

The branch `fix/dossedart-x01-cockpit-fixes` has uncommitted work: the X01
turn-aggregation fix (`turnId` grouping) plus a one-time stats migration
(`lib/services/stats_migration.dart`) with tests. Verify its tests pass,
commit it, then audit from a clean tree.

### Phase 1 — Automated health check

- `flutter analyze` (zero-tolerance baseline: report every warning).
- Full test suite. Known issue: full `flutter test` sometimes hangs ~10 min on
  `pumpAndSettle` — run per-directory or with `--reporter expanded` as the
  workaround, and note whether the hang reproduces.
- `dart pub outdated` — dependency freshness, flag anything with breaking
  security/deprecation implications only.
- Version consistency: `pubspec.yaml` version vs the `home_screen.dart`
  version string.

### Phase 2 — Systematic review, four dimensions

Parallel read agents where coverage is wide; every candidate finding gets a
verification pass against the actual code before it is kept.

1. **Bugs & correctness** — game logic in all six modes (X01, Cricket, ATC,
   Killer, Halve It/Splitscore, Shanghai), undo stacks, bust/checkout edge
   cases, add/remove player mid-game, stats/Elo calculations,
   persistence/migrations. Includes re-checking known open items from memory
   (Shanghai post-game undo, Shanghai instant-trigger, DOSSEDART last-5 W/L).
2. **Code quality & duplication** — the six game screens (1331–2222 lines
   each) share large amounts of logic; assess what belongs in a shared
   engine/widgets (the parked engine-extraction item), find dead code and
   cross-mode inconsistencies.
3. **Test coverage** — map what the 66 test files actually cover; identify
   the riskiest gaps (game screens, services), not a coverage-percentage
   exercise.
4. **UI consistency** — the four-role color palette, 1px outline rules,
   AppBar/bottom-bar/scoreboard consistency across modes, against the
   DOSSEDART design direction. Cricket gets extra attention (flagged in
   memory as needing a consistency re-check).

### Phase 3 — Prioritized report

Compile all verified findings into the deliverable above. Present the summary
to Bjørn in Norwegian in the conversation; the report file itself is in
English like the rest of `docs/`.

### Phase 4 — Fix rounds

After Bjørn reads the report: fixes in priority order on a long-lived branch
(release-train pattern), tests per fix, push only when Bjørn says so. Each fix
round is its own implementation plan; this spec only covers the audit through
Phase 3.

## Success criteria

- Report exists, every finding verified and graded, fix plan included.
- Bjørn can read it without developer background and decide what to green-light.
- No code changes on the tree besides committing the pre-existing Phase 0 work.
