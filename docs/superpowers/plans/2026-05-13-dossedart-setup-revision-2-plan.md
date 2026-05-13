# DOSSEDART setup revision 2 — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle `ArcadeToggleRow` to chip-look, repack per-mode toggle rows, default Cricket/Splitscore `BULL=false`, rename ATC `×MULT → D/T = ×N`, and switch `PlayerAvatar`'s null-path fallback to a silhouette icon — all on `feat/dossedart-arcade-v1` in the `.worktrees/dossedart-redesign` worktree.

**Architecture:** Pure visual + layout revision. One primitive (`ArcadeToggleRow`) gets a styling overhaul and a tuple-shape change; six setup screens are updated; `DossedartSetupScaffold` is refactored from passing `rulesSection: Widget` to `rulesSection: Widget Function(bool, ValueChanged<bool>)` so each mode can decide where `RANDOM ORDER` appears in its toggle layout. `PlayerAvatar` gets a small content swap when `avatarPath == null`.

**Tech Stack:** Flutter (Dart). State is `StatefulWidget` local. No new dependencies, no new tests (per spec — pure visual revision).

**Spec:** `docs/superpowers/specs/2026-05-13-dossedart-setup-revision-2-design.md` (commit `e6e96f8`).

**Discovered constraint not in spec:** `RANDOM ORDER` currently lives in `DossedartSetupScaffold` (renders below `rulesSection`). To merge it into per-mode toggle rows the scaffold must hand the state down to each mode. Task 3 handles this.

---

## File map

**Modified:**
- `lib/widgets/dossedart/setup/rules_primitives.dart` — `ArcadeToggleRow` restyle, tuple shape change, drop accent + glyph
- `lib/widgets/player_avatar.dart` — silhouette icon fallback when `avatarPath == null`
- `lib/widgets/dossedart/setup/dossedart_setup_scaffold.dart` — `rulesSection` becomes a builder that receives `(randomOrder, onChanged)`; scaffold no longer renders its own `RANDOM ORDER` row
- `lib/screens/dossedart/dossedart_x01_setup_screen.dart` — combine NO-BUST + HANDICAP + RANDOM ORDER
- `lib/screens/dossedart/dossedart_cricket_setup_screen.dart` — combine BULL + RANDOM ORDER; default BULL=false
- `lib/screens/dossedart/dossedart_atc_setup_screen.dart` — combine BULL + `D/T = ×N` + RANDOM ORDER; rename label
- `lib/screens/dossedart/dossedart_killer_setup_screen.dart` — RANDOM ORDER as its own row, after `×HITS`/`SHIELD`/`SUICIDE`
- `lib/screens/dossedart/dossedart_splitscore_setup_screen.dart` — combine BULL + RANDOM ORDER (both branches); default BULL=false
- `lib/screens/dossedart/dossedart_shanghai_setup_screen.dart` — wrap chip in a Column with RANDOM ORDER toggle row

**No new files. No deleted files. No new tests.**

---

## Task 1: Restyle `ArcadeToggleRow` + drop accent and glyph

**Files:**
- Modify: `lib/widgets/dossedart/setup/rules_primitives.dart:67-115`

- [ ] **Step 1.1: Replace `ArcadeToggleRow` class with chip-styled version**

Replace lines 67-115 of `lib/widgets/dossedart/setup/rules_primitives.dart` with:

```dart
/// A row of independent ON/OFF toggles. Visually matches `ArcadeChipRow`:
/// ON = yellow fill on yellow border, OFF = surface fill on magenta border.
/// Tuple shape: (label, value, onChanged).
class ArcadeToggleRow extends StatelessWidget {
  const ArcadeToggleRow({super.key, required this.toggles});

  final List<(String, bool, ValueChanged<bool>)> toggles;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < toggles.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(child: _toggle(toggles[i])),
        ],
      ],
    );
  }

  Widget _toggle((String, bool, ValueChanged<bool>) t) {
    final (label, value, onChanged) = t;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: value ? DossedartTokens.yellow : DossedartTokens.surface,
          border: Border.all(
            color: value ? DossedartTokens.yellow : DossedartTokens.magenta,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: value ? DossedartTokens.bg : Colors.white,
            letterSpacing: 0.5,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
```

Notes:
- Tuple shape went from `(String, bool, Color, ValueChanged<bool>)` to `(String, bool, ValueChanged<bool>)`.
- Spacing between toggles changed from `width: 6` to `width: 4` to match `ArcadeChipRow`.
- Glyph `●`/`○` removed from label.
- Padding/font/border now identical to `_chip` in `ArcadeChipRow` (lines 37-64).

- [ ] **Step 1.2: Run analyzer to surface broken call sites**

```bash
cd .worktrees/dossedart-redesign
flutter analyze lib/screens/dossedart lib/widgets/dossedart
```
Expected: errors on every `ArcadeToggleRow(toggles: [...])` call where a `Color` is still being passed in the tuple. These will be fixed in Task 3 (scaffold) and Tasks 4–9 (mode screens) — for now they confirm the API change reached every consumer.

- [ ] **Step 1.3: Do NOT commit yet**

Call sites are still broken. Commit happens at end of Task 3 (scaffold) when everything compiles.

---

## Task 2: `PlayerAvatar` silhouette fallback

**Files:**
- Modify: `lib/widgets/player_avatar.dart:20-42`

- [ ] **Step 2.1: Replace `build` method**

Replace the `build` method (lines 20-42) of `lib/widgets/player_avatar.dart` with:

```dart
  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      Icons.person,
      size: radius * 1.2,
      color: Colors.white,
    );

    if (avatarPath != null && avatarPath!.isNotEmpty && !kIsWeb) {
      final file = File(avatarPath!);
      if (file.existsSync()) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surfaceContainer,
          backgroundImage: FileImage(file),
        );
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surfaceContainer,
      child: fallback,
    );
  }
```

Notes:
- `final initial = Text(...)` removed; `name` parameter is now only used by callers and ignored inside `build`. Leave the field on the class — removing it would break callers and is out of scope.
- Icon sized to `radius * 1.2` to roughly match the current `Text(fontSize: radius * 0.8)` visual weight inside the circle. If visual QA shows it too large/small, adjust the multiplier.

- [ ] **Step 2.2: Verify analyzer is clean for this file**

```bash
cd .worktrees/dossedart-redesign
flutter analyze lib/widgets/player_avatar.dart
```
Expected: no issues found (the file).

- [ ] **Step 2.3: Commit**

```bash
cd .worktrees/dossedart-redesign
git add lib/widgets/player_avatar.dart
git commit -m "feat(dossedart): PlayerAvatar uses silhouette icon when avatarPath is null"
```

---

## Task 3: Refactor scaffold to hand `RANDOM ORDER` to the rules builder

**Files:**
- Modify: `lib/widgets/dossedart/setup/dossedart_setup_scaffold.dart:22-50` (constructor + field type)
- Modify: `lib/widgets/dossedart/setup/dossedart_setup_scaffold.dart:283-295` (build body)

- [ ] **Step 3.1: Change `rulesSection` to a builder**

In `lib/widgets/dossedart/setup/dossedart_setup_scaffold.dart`, change the field declaration around line 33 from:

```dart
  final Widget rulesSection;
```

to:

```dart
  final Widget Function(bool randomOrder, ValueChanged<bool> onRandomOrderChanged) rulesSection;
```

Update the constructor parameter doc comment above the class (line 16-21) by replacing the sentence "Mode-specific RULES are passed in via [rulesSection]" with:

```dart
/// Mode-specific RULES are passed in via [rulesSection] as a builder that
/// receives the random-order state so each mode can place the RANDOM ORDER
/// toggle wherever fits its layout.
```

- [ ] **Step 3.2: Stop rendering the scaffold's own RANDOM ORDER row, call the builder**

In the `build` method around lines 281-295, replace:

```dart
                              const SizedBox(height: 12),
                              widget.rulesSection,
                              const SizedBox(height: 6),
                              // Random-order toggle lives in the shared
                              // chrome (every mode has it, always defaults ON).
                              ArcadeToggleRow(toggles: [
                                (
                                  'RANDOM ORDER',
                                  _randomOrder,
                                  DossedartTokens.purple,
                                  (v) => setState(() => _randomOrder = v),
                                ),
                              ]),
                              const SizedBox(height: 18),
```

with:

```dart
                              const SizedBox(height: 12),
                              widget.rulesSection(
                                _randomOrder,
                                (v) => setState(() => _randomOrder = v),
                              ),
                              const SizedBox(height: 18),
```

- [ ] **Step 3.3: Tasks 4–9 update every call site**

Do not commit yet. The scaffold change breaks every setup screen; Tasks 4–9 fix them. Single commit at end of Task 9 lands the whole rewrite together.

---

## Task 4: X01 setup — three-toggle row

**Files:**
- Modify: `lib/screens/dossedart/dossedart_x01_setup_screen.dart:27-58`

- [ ] **Step 4.1: Switch `rulesSection` to builder + combine toggles**

Replace `build` and `_buildRules` (lines 26-59) with:

```dart
  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: 'NEW MATCH · ${widget.startingScore}',
      minPlayers: 2,
      rulesSection: _buildRules,
      summaryBuilder: _summary,
      onStart: _startGame,
    );
  }

  Widget _buildRules(bool randomOrder, ValueChanged<bool> onRandomOrderChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArcadeChipRow<String>(
          label: 'OUT RULE',
          value: _outRule,
          options: const [
            ('FREE OUT', 'none'),
            ('DOUBLE OUT', 'double'),
            ('MASTER OUT', 'master'),
          ],
          onChanged: (v) => setState(() => _outRule = v),
        ),
        const SizedBox(height: 14),
        ArcadeToggleRow(toggles: [
          ('NO-BUST', _noBust, (v) => setState(() => _noBust = v)),
          ('HANDICAP', _handicap, (v) => setState(() => _handicap = v)),
          ('RANDOM ORDER', randomOrder, onRandomOrderChanged),
        ]),
      ],
    );
  }
```

- [ ] **Step 4.2: Remove unused import**

If `DossedartTokens` is no longer referenced in this file, remove the import line `import '../../theme/dossedart_tokens.dart';` near the top. Verify by searching the file for `DossedartTokens` — should return zero hits after the toggle restyle dropped the accent param.

---

## Task 5: Cricket setup — BULL + RANDOM ORDER + default BULL=false

**Files:**
- Modify: `lib/screens/dossedart/dossedart_cricket_setup_screen.dart:22, 24-69`

- [ ] **Step 5.1: Default BULL to false**

Change line 22 from:

```dart
  bool _includeBull = true;
```

to:

```dart
  bool _includeBull = false;
```

- [ ] **Step 5.2: Switch `rulesSection` to builder + combine toggles**

Replace `build` and `_buildRules` (lines 24-69) with:

```dart
  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: 'CRICKET',
      minPlayers: 2,
      rulesSection: _buildRules,
      summaryBuilder: _summary,
      onStart: _startGame,
    );
  }

  Widget _buildRules(bool randomOrder, ValueChanged<bool> onRandomOrderChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArcadeChipRow<bool>(
          label: 'MODE',
          value: _isCutthroat,
          options: const [('STANDARD', false), ('CUTTHROAT', true)],
          onChanged: (v) => setState(() => _isCutthroat = v),
        ),
        const SizedBox(height: 14),
        ArcadeChipRow<bool>(
          label: 'TARGETS',
          value: _isRandom,
          options: const [('15-20', false), ('RANDOM', true)],
          onChanged: (v) => setState(() => _isRandom = v),
        ),
        if (_isRandom) ...[
          const SizedBox(height: 14),
          ArcadeStepper(
            label: 'COUNT',
            value: _targetCount,
            min: 3,
            max: 15,
            onChanged: (v) => setState(() => _targetCount = v),
          ),
        ],
        const SizedBox(height: 14),
        ArcadeToggleRow(toggles: [
          ('BULL', _includeBull, (v) => setState(() => _includeBull = v)),
          ('RANDOM ORDER', randomOrder, onRandomOrderChanged),
        ]),
      ],
    );
  }
```

- [ ] **Step 5.3: Remove unused import**

Remove `import '../../theme/dossedart_tokens.dart';` if `DossedartTokens` is no longer referenced anywhere in the file.

---

## Task 6: ATC setup — three-toggle row + rename `×MULT → D/T = ×N`

**Files:**
- Modify: `lib/screens/dossedart/dossedart_atc_setup_screen.dart:22-61`

- [ ] **Step 6.1: Switch `rulesSection` to builder + combine toggles + rename label**

Replace `build`, `_buildRules`, and `_summary` (lines 22-61) with:

```dart
  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: 'AROUND THE CLOCK',
      minPlayers: 1,
      rulesSection: _buildRules,
      summaryBuilder: _summary,
      onStart: _startGame,
    );
  }

  Widget _buildRules(bool randomOrder, ValueChanged<bool> onRandomOrderChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArcadeChipRow<bool>(
          label: 'DIRECTION',
          value: _reverse,
          options: const [('1 → 20', false), ('20 → 1', true)],
          onChanged: (v) => setState(() => _reverse = v),
        ),
        const SizedBox(height: 14),
        ArcadeToggleRow(toggles: [
          ('BULL', _includeBull, (v) => setState(() => _includeBull = v)),
          ('D/T = ×N', _countMultiples, (v) => setState(() => _countMultiples = v)),
          ('RANDOM ORDER', randomOrder, onRandomOrderChanged),
        ]),
      ],
    );
  }

  String _summary(int playerCount) {
    return [
      '$playerCount PLAYERS',
      if (_reverse) '20→1' else '1→20',
      if (_includeBull) 'BULL',
      if (_countMultiples) 'D/T=×N',
    ].join(' · ');
  }
```

- [ ] **Step 6.2: Remove unused import**

Remove `import '../../theme/dossedart_tokens.dart';` if no longer referenced.

---

## Task 7: Killer setup — keep RANDOM ORDER on own row

**Files:**
- Modify: `lib/screens/dossedart/dossedart_killer_setup_screen.dart:26-64`

- [ ] **Step 7.1: Switch `rulesSection` to builder + drop tuple accent**

Replace `build` and `_buildRules` (lines 26-64) with:

```dart
  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: 'KILLER',
      minPlayers: 2,
      rulesSection: _buildRules,
      summaryBuilder: _summary,
      onStart: _startGame,
    );
  }

  Widget _buildRules(bool randomOrder, ValueChanged<bool> onRandomOrderChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArcadeChipRow<int>(
          label: 'LIVES',
          value: _lives,
          options: const [('1', 1), ('2', 2), ('3', 3), ('4', 4), ('5', 5)],
          onChanged: (v) => setState(() => _lives = v),
        ),
        const SizedBox(height: 14),
        ArcadeChipRow<bool>(
          label: 'PICK NUMBER',
          value: _throwToPick,
          options: const [('THROW', true), ('RANDOM', false)],
          onChanged: (v) => setState(() => _throwToPick = v),
        ),
        const SizedBox(height: 14),
        ArcadeToggleRow(toggles: [
          ('×HITS', _multiplyHits, (v) => setState(() => _multiplyHits = v)),
          ('SHIELD', _shields, (v) => setState(() => _shields = v)),
          ('SUICIDE', _suicide, (v) => setState(() => _suicide = v)),
        ]),
        const SizedBox(height: 14),
        ArcadeToggleRow(toggles: [
          ('RANDOM ORDER', randomOrder, onRandomOrderChanged),
        ]),
      ],
    );
  }
```

- [ ] **Step 7.2: Remove unused import**

Remove `import '../../theme/dossedart_tokens.dart';` if no longer referenced.

---

## Task 8: Splitscore setup — BULL + RANDOM ORDER + default BULL=false

**Files:**
- Modify: `lib/screens/dossedart/dossedart_splitscore_setup_screen.dart:23, 25-73`

- [ ] **Step 8.1: Default BULL to false**

Change line 23 from:

```dart
  bool _includeBull = true;
```

to:

```dart
  bool _includeBull = false;
```

- [ ] **Step 8.2: Switch `rulesSection` to builder + combine toggles in both branches**

Replace `build` and `_buildRules` (lines 25-73) with:

```dart
  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: 'SPLITSCORE',
      minPlayers: 1,
      rulesSection: _buildRules,
      summaryBuilder: _summary,
      onStart: _startGame,
    );
  }

  Widget _buildRules(bool randomOrder, ValueChanged<bool> onRandomOrderChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArcadeChipRow<bool>(
          label: 'ROUNDS',
          value: _isRandom,
          options: const [('STANDARD', false), ('RANDOM', true)],
          onChanged: (v) => setState(() => _isRandom = v),
        ),
        if (_isRandom) ...[
          const SizedBox(height: 14),
          ArcadeStepper(
            label: 'COUNT',
            value: _roundCount,
            min: 5,
            max: 20,
            onChanged: (v) => setState(() => _roundCount = v),
          ),
          const SizedBox(height: 14),
          ArcadeToggleRow(toggles: [
            ('DBL', _includeDouble, (v) => setState(() => _includeDouble = v)),
            ('TPL', _includeTriple, (v) => setState(() => _includeTriple = v)),
            ('BULL', _includeBull, (v) => setState(() => _includeBull = v)),
          ]),
          const SizedBox(height: 14),
          ArcadeToggleRow(toggles: [
            ('RANDOM ORDER', randomOrder, onRandomOrderChanged),
          ]),
        ] else ...[
          const SizedBox(height: 14),
          ArcadeToggleRow(toggles: [
            ('BULL', _includeBull, (v) => setState(() => _includeBull = v)),
            ('RANDOM ORDER', randomOrder, onRandomOrderChanged),
          ]),
        ],
      ],
    );
  }
```

Notes:
- In the `RANDOM` branch the row would have 4 toggles if combined — too dense at PressStart2P size 10, so RANDOM ORDER stays as its own row only in that branch.
- In the `STANDARD` (non-random) branch BULL + RANDOM ORDER fit on one row as the memo specified.

- [ ] **Step 8.3: Remove unused import**

Remove `import '../../theme/dossedart_tokens.dart';` if no longer referenced.

---

## Task 9: Shanghai setup — wrap chip with RANDOM ORDER row + commit

**Files:**
- Modify: `lib/screens/dossedart/dossedart_shanghai_setup_screen.dart:21-38`

- [ ] **Step 9.1: Switch `rulesSection` to builder + wrap chip + add RANDOM ORDER row**

Replace `build` and `_buildRules` (lines 21-38) with:

```dart
  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: 'SHANGHAI',
      minPlayers: 1,
      rulesSection: _buildRules,
      summaryBuilder: _summary,
      onStart: _startGame,
    );
  }

  Widget _buildRules(bool randomOrder, ValueChanged<bool> onRandomOrderChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArcadeChipRow<int>(
          label: 'TARGET RANGE',
          value: _targetEnd,
          options: const [('1-7', 7), ('1-9', 9), ('1-20', 20)],
          onChanged: (v) => setState(() => _targetEnd = v),
        ),
        const SizedBox(height: 14),
        ArcadeToggleRow(toggles: [
          ('RANDOM ORDER', randomOrder, onRandomOrderChanged),
        ]),
      ],
    );
  }
```

- [ ] **Step 9.2: Run analyzer across the whole worktree**

```bash
cd .worktrees/dossedart-redesign
flutter analyze
```
Expected: no issues found (everything compiles, no unused imports, no unused fields).

If analyzer reports unused `name` field on `PlayerAvatar`, ignore — `name` is part of the public API and consumers still pass it.

- [ ] **Step 9.3: Run existing tests**

```bash
cd .worktrees/dossedart-redesign
flutter test
```
Expected: all existing tests pass. Pure visual revision should not affect any logic-level test.

- [ ] **Step 9.4: Commit**

```bash
cd .worktrees/dossedart-redesign
git add lib/widgets/dossedart/setup/rules_primitives.dart \
        lib/widgets/dossedart/setup/dossedart_setup_scaffold.dart \
        lib/screens/dossedart/dossedart_x01_setup_screen.dart \
        lib/screens/dossedart/dossedart_cricket_setup_screen.dart \
        lib/screens/dossedart/dossedart_atc_setup_screen.dart \
        lib/screens/dossedart/dossedart_killer_setup_screen.dart \
        lib/screens/dossedart/dossedart_splitscore_setup_screen.dart \
        lib/screens/dossedart/dossedart_shanghai_setup_screen.dart
git commit -m "refactor(dossedart): chip-styled toggles, repacked layouts, BULL defaults, ATC rename

- ArcadeToggleRow restyled to match ArcadeChipRow (yellow fill ON / surface OFF)
- Drop accent Color and ON/OFF glyph from ArcadeToggleRow tuple
- Scaffold passes RANDOM ORDER state to mode rules via builder callback
- X01: NO-BUST + HANDICAP + RANDOM ORDER on one row
- Cricket: BULL + RANDOM ORDER on one row, BULL default false
- ATC: BULL + D/T = ×N + RANDOM ORDER on one row, rename label
- Killer: RANDOM ORDER on its own row below ×HITS/SHIELD/SUICIDE
- Splitscore: BULL + RANDOM ORDER on one row, BULL default false
- Shanghai: RANDOM ORDER row added

Implements QA findings from 2026-05-12 (Galaxy Tab A7)."
```

---

## Task 10: Manual verification on Galaxy Tab emulator

**Files:** none (verification only)

- [ ] **Step 10.1: Launch the app on the Galaxy Tab emulator**

```bash
cd .worktrees/dossedart-redesign
flutter run -d <galaxy-tab-emulator-id>
```
(Use `flutter devices` to find the emulator ID. Per saved preference: Galaxy Tab A / S5e 2019, not the phone default.)

- [ ] **Step 10.2: Walk the checklist from the spec**

For each item, confirm visually and note any deviation:

- [ ] All six setup screens render correctly at tablet width
- [ ] Toggles flip ON/OFF with yellow-fill vs surface-fill (no per-toggle accent fill remaining)
- [ ] No `●`/`○` glyphs in any toggle label
- [ ] Cricket: BULL is OFF on first open
- [ ] Splitscore (STANDARD branch): BULL is OFF on first open
- [ ] X01: NO-BUST + HANDICAP + RANDOM ORDER fit on one row without wrap
- [ ] ATC: BULL + D/T = ×N + RANDOM ORDER fit on one row, `D/T = ×N` legible
- [ ] Killer: `×HITS` / `SHIELD` / `SUICIDE` use new chip styling; `RANDOM ORDER` on row below
- [ ] Shanghai: `RANDOM ORDER` row appears below `TARGET RANGE` chips
- [ ] Player picker tile with no `avatarPath` shows silhouette `Icons.person`, not initial
- [ ] Spot-check `post_game` and `stats` screens: `PlayerAvatar` with null path still readable

- [ ] **Step 10.3: If ATC `D/T = ×N` wraps or clips**

Fallback per spec: drop the spaces (`D/T=×N`) in `dossedart_atc_setup_screen.dart` `_buildRules` and `_summary` (the summary already uses the no-space form). Re-run, verify, amend the commit with `git commit --amend --no-edit` only if not yet pushed. If already pushed, make a new commit.

---

## Self-review notes

**Spec coverage:**
- §1 Primitive restyle → Task 1 ✓
- §2 Per-mode layout (6 modes) → Tasks 4–9 ✓
- §2 Cricket + Splitscore BULL=false → Step 5.1, Step 8.1 ✓
- §2 ATC ×MULT rename → Step 6.1 ✓
- §3 Avatar fallback → Task 2 ✓
- §4 Out-of-scope guards → no tasks touch leaderboard/ChipRow/Stepper/game screens ✓
- §Verification checklist → Task 10 ✓

**Discovered gap addressed:** scaffold refactor for RANDOM ORDER (Task 3) — noted in plan header.

**No placeholders.** All code is concrete; all paths absolute-from-worktree-root; all commit messages spelled out.

**Type consistency:** `ArcadeToggleRow` tuple `(String, bool, ValueChanged<bool>)` used identically in Tasks 1, 4, 5, 6, 7, 8, 9. Scaffold builder type `Widget Function(bool, ValueChanged<bool>)` used identically in Tasks 3 and 4–9.
