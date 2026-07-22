# Full Project Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce `docs/superpowers/audit/2026-07-06-audit-report.md` — a verified, prioritized (P0–P3) findings report over the whole app, readable by a non-developer, ending with a recommended fix plan.

**Architecture:** Commit the pre-existing WIP first, then run automated health checks, then four parallel read-only review agents (bugs, duplication, tests, UI), then a verification pass that confirms every candidate finding against the code, then compile the report.

**Tech Stack:** Flutter/Dart, `flutter analyze`, `flutter test`, read-only Explore/general-purpose agents.

## Global Constraints

- Audit is read-only: no code changes except the Task 1 commit of pre-existing work.
- No performance-optimization findings unless they are actual bugs (spec non-goal).
- No feature ideas in the report (spec non-goal).
- Every finding in the report must be verified against actual code (file:line) — no "maybe" findings.
- Known flaky full-test hang: never run bare `flutter test` on the whole suite; run per-directory.
- Report file in English; conversation summary to Bjørn in Norwegian.

---

### Task 1: Commit the pre-existing X01 turn-fix WIP

**Files:**
- Commit (already modified/untracked): `lib/main.dart`, `lib/screens/game_screen.dart`, `lib/screens/home_screen.dart`, `lib/stats/game_detail_stats.dart`, `pubspec.yaml`, `lib/services/stats_migration.dart`, `test/stats/game_detail_stats_test.dart`, `test/services/stats_migration_test.dart`

**Interfaces:**
- Produces: a clean working tree so the audit reads committed state.

- [ ] **Step 1: Read the full diff to understand what the WIP does**

Run: `git diff` and read `lib/services/stats_migration.dart`, `test/services/stats_migration_test.dart` in full.
Expected: coherent turn-aggregation fix (turnId grouping) + one-time migration + version bump. If the diff contains anything unrelated or half-finished, split it out or stop and flag it in the report instead of committing blind.

- [ ] **Step 2: Run the tests that cover the WIP**

Run: `flutter test test/stats/game_detail_stats_test.dart test/services/stats_migration_test.dart --reporter expanded`
Expected: PASS. If FAIL: do not commit; record as a P0 finding and leave the tree as-is.

- [ ] **Step 3: Analyze the changed files**

Run: `flutter analyze`
Expected: no new errors in the changed files (pre-existing infos elsewhere are Task 2's business).

- [ ] **Step 4: Check .claude/ and the stray zip**

`.claude/` (untracked) and `docs/design/dossedart-handoff/DOSSEDART (3).zip` (untracked): inspect; commit the zip only if it belongs with the handoff docs, otherwise leave untracked and note in report. Do not commit `.claude/` unless it contains project-shared settings.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart lib/screens/game_screen.dart lib/screens/home_screen.dart lib/stats/game_detail_stats.dart pubspec.yaml lib/services/stats_migration.dart test/stats/game_detail_stats_test.dart test/services/stats_migration_test.dart
git commit -m "fix(stats): group X01 turn stats by turnId + one-time migration for corrupted records"
```

### Task 2: Automated health check

**Files:**
- Create: `<scratchpad>/audit/health.md` (raw results for later synthesis)

**Interfaces:**
- Produces: analyzer output, test-suite status per directory, outdated-deps list, version-consistency verdict — consumed by Task 5 (report).

- [ ] **Step 1: Analyzer baseline**

Run: `flutter analyze`
Expected: record every error/warning/info verbatim into `health.md`.

- [ ] **Step 2: Full test suite, per top-level test directory (hang workaround)**

Run for each dir under `test/` (e.g. `test/stats`, `test/services`, `test/models`, `test/widgets`, ... discover with `ls test/`):
`flutter test test/<dir> --reporter compact --timeout 2x`
Run loose `test/*.dart` files as one batch. Record pass/fail counts and any hang (kill after ~5 min, note which file).
Expected: all pass; failures/hangs recorded verbatim.

- [ ] **Step 3: Dependency freshness**

Run: `flutter pub outdated`
Expected: record majors-behind packages; only security/deprecation-relevant ones become findings.

- [ ] **Step 4: Version consistency**

Compare `version:` in `pubspec.yaml` with the version string in `lib/screens/home_screen.dart` (grep `1.8`).
Expected: identical; mismatch is a finding (P2).

### Task 3: Four-dimension review (parallel agents)

**Files:**
- Create: `<scratchpad>/audit/findings-{bugs,duplication,tests,ui}.md`

**Interfaces:**
- Consumes: clean tree from Task 1.
- Produces: candidate findings, each as `{id, severity-guess, file:line, claim, evidence}` — consumed by Task 4.

- [ ] **Step 1: Dispatch four read-only agents in parallel**, one per dimension, each instructed to return findings with exact file:line and code evidence, and explicitly told: no performance speculation, no feature ideas, cite code for every claim.

Agent prompts (summarized; full prompts written at dispatch time must include the project context block: Flutter dart-scoring app, six game modes, DOSSEDART design, four-role color palette from CLAUDE.md):

1. **bugs**: audit game logic in all six game screens (`lib/screens/game_screen.dart`, `cricket_game_screen.dart`, `around_the_clock_game_screen.dart`, `killer_game_screen.dart`, `halve_it_game_screen.dart`, `shanghai_game_screen.dart`) + undo stacks, bust/checkout edges, add/remove mid-game, `lib/services/elo_service.dart`, `lib/services/stats_recorder.dart`, `lib/stats/`, persistence (`player_storage`, `app_settings`, `game_history_service`). Re-check known items: Shanghai post-game undo (pushReplacement + stats saved pre-post-game), Shanghai instant-Shanghai trigger missing, SavedPlayer missing last-5 W/L.
2. **duplication**: compare the six game screens structurally; identify shared logic (turn loop, undo, announcer wiring, scoreboard, input pad, add/remove player, end-of-game flow) and rate extraction candidates by risk/value; find dead code and cross-mode behavioral inconsistencies.
3. **tests**: map `test/` against `lib/`; identify untested critical paths (game-screen logic, services, models); assess test quality (assertion depth, not just existence); locate the flaky `pumpAndSettle` hang suspects.
4. **ui**: check every screen/widget against the four-role palette (grep for `Colors.`, hex literals outside the documented exceptions), 1px `cs.outline` rule, AppBar/bottom-bar/scoreboard consistency across modes; Cricket gets a full pass (memory flag).

- [ ] **Step 2: Collect results into the four findings files**

Expected: each candidate has file:line + evidence; discard any without.

### Task 4: Verification pass

**Files:**
- Create: `<scratchpad>/audit/verified.md`

**Interfaces:**
- Consumes: candidate findings from Task 3.
- Produces: confirmed findings with final P0–P3 grades — consumed by Task 5.

- [ ] **Step 1: For each candidate finding, verify against the code**

Read the cited file:line ranges myself (or dispatch verify agents for volume, prompted to REFUTE the claim). Rules: a finding survives only if the failure scenario is concrete and reproducible from the code; severity assigned by user impact (P0 = user-visible wrong behavior/data corruption, P1 = user-visible glitch or high-risk fragile code, P2 = maintainability/consistency debt, P3 = polish).

- [ ] **Step 2: Deduplicate and cross-reference**

Merge duplicate findings across dimensions; link related ones (e.g. a bug that exists in all six screens because of duplication is one root-cause finding).

### Task 5: Compile report + summary

**Files:**
- Create: `docs/superpowers/audit/2026-07-06-audit-report.md`

**Interfaces:**
- Consumes: `health.md`, `verified.md`.

- [ ] **Step 1: Write the report** per the spec's Deliverable section: executive summary in plain language, findings grouped P0→P3 (what it is, where, what a user notices, suggested fix), recommended fix plan with order + rough effort.

- [ ] **Step 2: Self-check the report**

Every finding has file:line; no speculation survived; a non-developer can follow the executive summary and fix plan.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/audit/2026-07-06-audit-report.md
git commit -m "docs: full project audit report 2026-07-06"
```

- [ ] **Step 4: Summarize to Bjørn in Norwegian** — outcome first: counts per severity, the P0s spelled out, and the recommended first fix round.
