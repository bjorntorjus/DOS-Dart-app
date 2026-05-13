# DOSSEDART Toggle Visibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make ON/OFF state of DOSSEDART arcade toggles unmistakable on the Galaxy Tab by giving ON a filled accent background + yellow border, while OFF keeps a dim accent border + dim accent text so each toggle retains its color identity.

**Architecture:** Two changes — update `ArcadeToggleRow._toggle` styling (Task 1), then refactor the inline RANDOM ORDER toggle in `DossedartSetupScaffold` to use `ArcadeToggleRow` so all toggles share one source of styling (Task 2).

**Tech Stack:** Flutter widget tweaks only, no new dependencies.

**Spec:** `docs/superpowers/specs/2026-05-12-dossedart-toggle-visibility-design.md`

---

## Pre-task setup

- [ ] **Verify worktree and branch**

Run: `git rev-parse --abbrev-ref HEAD`
Expected: `feat/dossedart-arcade-v1`

Run: `pwd`
Expected: ends with `.worktrees/dossedart-redesign`

---

## Task 1: Update ArcadeToggleRow ON/OFF styling + new test

**Files:**
- Modify: `lib/widgets/dossedart/setup/rules_primitives.dart` (the `ArcadeToggleRow._toggle` method around lines 90-120)
- Modify: `test/widgets/dossedart/rules_primitives_test.dart` (append one new test inside the existing `group('ArcadeToggleRow', ...)`)

- [ ] **Step 1: Add the failing test**

Open `test/widgets/dossedart/rules_primitives_test.dart`. Inside the existing `group('ArcadeToggleRow', () { ... })` block, append this test right after the existing `'ON toggle shows filled indicator, OFF shows empty'` test:

```dart
    testWidgets('ON toggle border uses DossedartTokens.yellow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcadeToggleRow(toggles: [
              ('BULL', true, DossedartTokens.magenta, (_) {}),
            ]),
          ),
        ),
      );
      // Find the toggle's outer container (the one with the BoxDecoration).
      final containerFinder = find.ancestor(
        of: find.textContaining('BULL'),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.decoration is BoxDecoration,
        ),
      );
      final container = tester.widget<Container>(containerFinder.first);
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, DossedartTokens.yellow);
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/dossedart/rules_primitives_test.dart`
Expected: FAIL on the new test. The failure will say something like `Expected: Color(0xffffd200)` (yellow) `Actual: Color(0xffff00aa)` (magenta — the current ON border).

- [ ] **Step 3: Implement the new styling**

Open `lib/widgets/dossedart/setup/rules_primitives.dart`. Find the `_toggle` method inside `ArcadeToggleRow`. It currently looks roughly like:

```dart
  Widget _toggle((String, bool, Color, ValueChanged<bool>) t) {
    final (label, value, accent, onChanged) = t;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: value ? accent.withValues(alpha: 0.15) : DossedartTokens.surface,
          border: Border.all(color: accent, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          '$label ${value ? '●' : '○'}',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 9,
            color: value ? accent : Colors.white70,
            letterSpacing: 0.5,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
```

Replace the entire `_toggle` method with:

```dart
  Widget _toggle((String, bool, Color, ValueChanged<bool>) t) {
    final (label, value, accent, onChanged) = t;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: value ? accent : DossedartTokens.surface,
          border: Border.all(
            color: value ? DossedartTokens.yellow : accent.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '$label ${value ? '●' : '○'}',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 9,
            color: value ? DossedartTokens.bg : accent.withValues(alpha: 0.6),
            fontWeight: value ? FontWeight.bold : FontWeight.normal,
            letterSpacing: 0.5,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
```

Changes from the old version:
- ON background: was `accent.withValues(alpha: 0.15)` → now `accent` (full opacity)
- ON border: was `accent` → now `DossedartTokens.yellow`
- OFF border: was `accent` → now `accent.withValues(alpha: 0.4)` (dim accent)
- ON text color: was `accent` → now `DossedartTokens.bg` (dark text on bright bg)
- OFF text color: was `Colors.white70` → now `accent.withValues(alpha: 0.6)` (dim accent — keeps per-toggle identity)
- New: `fontWeight: value ? FontWeight.bold : FontWeight.normal`

- [ ] **Step 4: Run all rules_primitives tests to verify they pass**

Run: `flutter test test/widgets/dossedart/rules_primitives_test.dart`
Expected: PASS (12 tests total — 11 existing + 1 new).

If the existing `'ON toggle shows filled indicator'` test fails, it should not — the indicator glyph logic is unchanged. If anything else fails, stop and report.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/dossedart/setup/rules_primitives.dart test/widgets/dossedart/rules_primitives_test.dart
git commit -m "feat(dossedart): boost ON-state visibility of ArcadeToggleRow"
```

---

## Task 2: Refactor scaffold's inline RANDOM ORDER toggle to use ArcadeToggleRow

**Files:**
- Modify: `lib/widgets/dossedart/setup/dossedart_setup_scaffold.dart` (the inline RANDOM ORDER toggle in `build()`, approximately lines 283-315)

The scaffold currently has the RANDOM ORDER toggle hardcoded as a `Row` → `Expanded` → `GestureDetector` → `Container` directly inside `build()`. We replace it with a single-element `ArcadeToggleRow` so all toggles share one styling source.

- [ ] **Step 1: Verify current inline block exists**

Open `lib/widgets/dossedart/setup/dossedart_setup_scaffold.dart`. Find the section in `build()` between the `widget.rulesSection` and the cast header (look for the comment `// Random-order toggle lives in the shared chrome...`). It should look like:

```dart
                              widget.rulesSection,
                              const SizedBox(height: 6),
                              // Random-order toggle lives in the shared
                              // chrome (every mode has it, always defaults ON).
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(
                                          () => _randomOrder = !_randomOrder),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8, horizontal: 4),
                                        decoration: BoxDecoration(
                                          color: _randomOrder
                                              ? DossedartTokens.purple
                                                  .withValues(alpha: 0.15)
                                              : DossedartTokens.surface,
                                          border: Border.all(
                                              color: DossedartTokens.purple,
                                              width: 2),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          'RANDOM ORDER ${_randomOrder ? '●' : '○'}',
                                          style: TextStyle(
                                            fontFamily: 'PressStart2P',
                                            fontSize: 9,
                                            color: _randomOrder
                                                ? DossedartTokens.purple
                                                : Colors.white70,
                                            letterSpacing: 0.5,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
```

- [ ] **Step 2: Verify the import for rules_primitives**

Look at the imports at the top of `dossedart_setup_scaffold.dart`. The file already imports `dossedart_player_picker.dart`. Add (if not already present) an import for `rules_primitives.dart`:

```dart
import 'rules_primitives.dart';
```

It belongs in the import block alongside the other relative imports (after the `arcade_frame.dart` import). If it is already there, leave it.

- [ ] **Step 3: Replace the inline block with ArcadeToggleRow**

Replace the entire `Row(children: [Expanded(...)])` block (everything between the `// Random-order toggle...` comment and the `const SizedBox(height: 18)`) with:

```dart
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
```

Keep the surrounding `widget.rulesSection`, the preceding `SizedBox(height: 6)`, and the following `SizedBox(height: 18)` unchanged.

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze lib/widgets/dossedart/setup/dossedart_setup_scaffold.dart`
Expected: No errors.

- [ ] **Step 5: Run full test suite to catch regressions**

Run: `flutter test`
Expected: All tests pass. Specifically the three scaffold tests in `test/widgets/dossedart/dossedart_setup_scaffold_test.dart` should still pass — they don't assert on RANDOM ORDER colors.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/dossedart/setup/dossedart_setup_scaffold.dart
git commit -m "refactor(dossedart): scaffold RANDOM ORDER uses ArcadeToggleRow"
```

---

## Manual QA (after both tasks)

Build and run the release APK on the Galaxy Tab emulator:

1. Open any mode setup screen (e.g., Cricket).
2. Verify the RANDOM ORDER toggle: ON state should have purple background + yellow border + dark text + bold. Tap to turn OFF: surface background + dim purple border + dim purple text + normal weight.
3. Verify mode-specific toggles (e.g., Cricket's BULL): same treatment in their accent color (magenta, cyan, etc.).
4. Confirm the contrast is comfortable from normal arm's-length reading distance — the bug that triggered this work.

## Self-review checklist (run before claiming done)

- `flutter analyze`: no errors
- `flutter test`: all 157 tests pass (156 + 1 new)
- Manual QA on Galaxy Tab: ON/OFF distinguishable for all four accent colors (magenta, cyan, purple, plus any yellow toggle if present)
