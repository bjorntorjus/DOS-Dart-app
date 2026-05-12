# DOSSEDART Shared Setup Screens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the DOSSEDART arcade picker (currently only in X01 setup) to all five other game modes by extracting a shared scaffold + reusable primitives, then composing per-mode setup screens.

**Architecture:** Bottom-up: build three RULES primitives → one tile widget → picker grid → setup scaffold → refactor X01 → add five mode-specific setup screens → wire home-screen routing. Each layer has tests where it matters (primitives, scaffold).

**Tech Stack:** Flutter (Material 3 dark theme), local `StatefulWidget` state, `SharedPreferences` via `PlayerStorage`. No external state library. Fonts: `PressStart2P` + `VT323` (already bundled).

**Spec:** `docs/superpowers/specs/2026-05-12-dossedart-shared-setup-design.md`

---

## Pre-task setup

Before starting, verify you're in the right worktree and branch:

- [ ] **Verify worktree and branch**

Run: `git rev-parse --abbrev-ref HEAD`
Expected: `feat/dossedart-arcade-v1`

Run: `pwd`
Expected: ends with `.worktrees/dossedart-redesign`

If anything else: stop and ask.

---

## Task 1: ArcadeChipRow primitive

A radio-style chip row used for all "pick-one" config (X01 OUT RULE, Cricket MODE, etc.). Generic on value type.

**Files:**
- Create: `lib/widgets/dossedart/setup/rules_primitives.dart` (start the file with this widget)
- Test: `test/widgets/dossedart/rules_primitives_test.dart` (start with this widget's tests)

- [ ] **Step 1: Write the failing tests**

Create `test/widgets/dossedart/rules_primitives_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring_app/widgets/dossedart/setup/rules_primitives.dart';
import 'package:dart_scoring_app/theme/dossedart_tokens.dart';

void main() {
  group('ArcadeChipRow', () {
    testWidgets('renders label and all option labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcadeChipRow<String>(
              label: 'OUT RULE',
              value: 'none',
              options: const [
                ('FREE', 'none'),
                ('DBL', 'double'),
                ('MSTR', 'master'),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('OUT RULE'), findsOneWidget);
      expect(find.text('FREE'), findsOneWidget);
      expect(find.text('DBL'), findsOneWidget);
      expect(find.text('MSTR'), findsOneWidget);
    });

    testWidgets('tap on option calls onChanged with that value', (tester) async {
      String? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcadeChipRow<String>(
              label: 'OUT',
              value: 'none',
              options: const [('FREE', 'none'), ('DBL', 'double')],
              onChanged: (v) => captured = v,
            ),
          ),
        ),
      );
      await tester.tap(find.text('DBL'));
      expect(captured, 'double');
    });

    testWidgets('selected chip has yellow background', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcadeChipRow<String>(
              label: 'OUT',
              value: 'double',
              options: const [('FREE', 'none'), ('DBL', 'double')],
              onChanged: (_) {},
            ),
          ),
        ),
      );
      // Find the container that wraps the "DBL" Text and check its color.
      final dblFinder = find.ancestor(
        of: find.text('DBL'),
        matching: find.byType(Container),
      );
      final container = tester.widget<Container>(dblFinder.first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, DossedartTokens.yellow);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widgets/dossedart/rules_primitives_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:dart_scoring_app/widgets/dossedart/setup/rules_primitives.dart'"

- [ ] **Step 3: Implement ArcadeChipRow**

Create `lib/widgets/dossedart/setup/rules_primitives.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';

/// Radio-style chip row. Tap a chip to select; selected chip turns yellow.
class ArcadeChipRow<T> extends StatelessWidget {
  const ArcadeChipRow({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<(String, T)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'VT323',
            fontSize: 13,
            color: Colors.white54,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(child: _chip(options[i].$1, options[i].$2)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _chip(String label, T optionValue) {
    final selected = optionValue == value;
    return GestureDetector(
      onTap: () => onChanged(optionValue),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? DossedartTokens.yellow : DossedartTokens.surface,
          border: Border.all(
            color: selected ? DossedartTokens.yellow : DossedartTokens.magenta,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: selected ? DossedartTokens.bg : Colors.white,
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

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widgets/dossedart/rules_primitives_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/dossedart/setup/rules_primitives.dart test/widgets/dossedart/rules_primitives_test.dart
git commit -m "feat(dossedart): add ArcadeChipRow primitive"
```

---

## Task 2: ArcadeToggleRow primitive

A row of 2-3 ON/OFF toggles. Each toggle has its own accent color.

**Files:**
- Modify: `lib/widgets/dossedart/setup/rules_primitives.dart` (append)
- Modify: `test/widgets/dossedart/rules_primitives_test.dart` (append)

- [ ] **Step 1: Add failing tests**

Append to the existing `group(...)` block list in `test/widgets/dossedart/rules_primitives_test.dart`, inside `main()`:

```dart
  group('ArcadeToggleRow', () {
    testWidgets('renders each toggle label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcadeToggleRow(toggles: [
              ('NO-BUST', false, DossedartTokens.magenta, (_) {}),
              ('HCAP', true, DossedartTokens.cyan, (_) {}),
            ]),
          ),
        ),
      );
      expect(find.text('NO-BUST'), findsOneWidget);
      expect(find.text('HCAP'), findsOneWidget);
    });

    testWidgets('tap toggles state via callback', (tester) async {
      bool? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcadeToggleRow(toggles: [
              ('NO-BUST', false, DossedartTokens.magenta, (v) => captured = v),
            ]),
          ),
        ),
      );
      await tester.tap(find.text('NO-BUST'));
      expect(captured, true);
    });

    testWidgets('ON toggle shows filled indicator, OFF shows empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcadeToggleRow(toggles: [
              ('A', true, DossedartTokens.magenta, (_) {}),
              ('B', false, DossedartTokens.magenta, (_) {}),
            ]),
          ),
        ),
      );
      // "A" is on, indicator is '●'; "B" is off, indicator is '○'.
      expect(find.textContaining('●'), findsOneWidget);
      expect(find.textContaining('○'), findsOneWidget);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widgets/dossedart/rules_primitives_test.dart`
Expected: FAIL with "Undefined name 'ArcadeToggleRow'"

- [ ] **Step 3: Implement ArcadeToggleRow**

Append to `lib/widgets/dossedart/setup/rules_primitives.dart`:

```dart
/// A row of independent ON/OFF toggles. Each toggle has its own accent color.
/// Tuple shape: (label, value, accentColor, onChanged).
class ArcadeToggleRow extends StatelessWidget {
  const ArcadeToggleRow({super.key, required this.toggles});

  final List<(String, bool, Color, ValueChanged<bool>)> toggles;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < toggles.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _toggle(toggles[i])),
        ],
      ],
    );
  }

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
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widgets/dossedart/rules_primitives_test.dart`
Expected: PASS (6 tests total)

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/dossedart/setup/rules_primitives.dart test/widgets/dossedart/rules_primitives_test.dart
git commit -m "feat(dossedart): add ArcadeToggleRow primitive"
```

---

## Task 3: ArcadeStepper primitive

`[-] N [+]` stepper for range config (Cricket target count, Splitscore round count).

**Files:**
- Modify: `lib/widgets/dossedart/setup/rules_primitives.dart` (append)
- Modify: `test/widgets/dossedart/rules_primitives_test.dart` (append)

- [ ] **Step 1: Add failing tests**

Append inside `main()`:

```dart
  group('ArcadeStepper', () {
    testWidgets('renders label and current value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcadeStepper(
              label: 'ROUNDS',
              value: 9,
              min: 5,
              max: 20,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('ROUNDS'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
    });

    testWidgets('+ increments value via onChanged', (tester) async {
      int? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcadeStepper(
              label: 'X', value: 9, min: 5, max: 20,
              onChanged: (v) => captured = v,
            ),
          ),
        ),
      );
      await tester.tap(find.text('+'));
      expect(captured, 10);
    });

    testWidgets('- decrements value via onChanged', (tester) async {
      int? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcadeStepper(
              label: 'X', value: 9, min: 5, max: 20,
              onChanged: (v) => captured = v,
            ),
          ),
        ),
      );
      await tester.tap(find.text('-'));
      expect(captured, 8);
    });

    testWidgets('+ at max does not call onChanged', (tester) async {
      int? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcadeStepper(
              label: 'X', value: 20, min: 5, max: 20,
              onChanged: (v) => captured = v,
            ),
          ),
        ),
      );
      await tester.tap(find.text('+'));
      expect(captured, isNull);
    });

    testWidgets('- at min does not call onChanged', (tester) async {
      int? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcadeStepper(
              label: 'X', value: 5, min: 5, max: 20,
              onChanged: (v) => captured = v,
            ),
          ),
        ),
      );
      await tester.tap(find.text('-'));
      expect(captured, isNull);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widgets/dossedart/rules_primitives_test.dart`
Expected: FAIL with "Undefined name 'ArcadeStepper'"

- [ ] **Step 3: Implement ArcadeStepper**

Append to `lib/widgets/dossedart/setup/rules_primitives.dart`:

```dart
/// `[-] N [+]` stepper for range config. Disabled buttons do not call onChanged.
class ArcadeStepper extends StatelessWidget {
  const ArcadeStepper({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canDec = value > min;
    final canInc = value < max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'VT323',
            fontSize: 13,
            color: Colors.white54,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _button('-', canDec, () => onChanged(value - 1)),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: DossedartTokens.magenta, width: 2),
                  color: DossedartTokens.surface,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$value',
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            _button('+', canInc, () => onChanged(value + 1)),
          ],
        ),
      ],
    );
  }

  Widget _button(String glyph, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 48,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: enabled ? DossedartTokens.yellow : Colors.white12,
          border: Border.all(
            color: enabled ? DossedartTokens.yellow : Colors.white24,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          glyph,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 16,
            color: enabled ? DossedartTokens.bg : Colors.white38,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widgets/dossedart/rules_primitives_test.dart`
Expected: PASS (11 tests total)

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/dossedart/setup/rules_primitives.dart test/widgets/dossedart/rules_primitives_test.dart
git commit -m "feat(dossedart): add ArcadeStepper primitive"
```

---

## Task 4: DossedartPickerTile

One picker tile: avatar (top-left), name (centered), `R 1420` + 5 W/L pips, P-slot badge on selected.

**Files:**
- Create: `lib/widgets/dossedart/setup/dossedart_picker_tile.dart`

This is pure UI — no test. We rely on visual QA. The widget is small and the structure mirrors what already works in `dossedart_x01_setup_screen.dart`.

- [ ] **Step 1: Create the file**

Create `lib/widgets/dossedart/setup/dossedart_picker_tile.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../models/saved_player.dart';
import '../../../theme/dossedart_tokens.dart';
import '../../player_avatar.dart';

/// One tile in the picker grid.
///
/// Shows avatar (top-left), name (centered), `R nnnn` + 5 W/L pips,
/// and a P-slot badge (yellow, rotated) when selected.
class DossedartPickerTile extends StatelessWidget {
  const DossedartPickerTile({
    super.key,
    required this.player,
    required this.selected,
    this.slot,
    required this.onTap,
    required this.onLongPress,
  });

  final SavedPlayer player;
  final bool selected;
  final int? slot;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final accent =
        selected ? DossedartTokens.yellow : DossedartTokens.magenta;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: selected ? 1.0 : 0.7,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0x10FFD200)
                    : DossedartTokens.surface,
                border: Border.all(color: accent, width: 3),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: PlayerAvatar(
                      avatarPath: player.avatarPath,
                      name: player.name,
                      radius: 16,
                      backgroundColor: DossedartTokens.bg,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    player.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'VT323',
                      fontSize: 23,
                      color: Colors.white,
                      letterSpacing: 1,
                      height: 1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'R ${player.rating.round()}',
                        style: const TextStyle(
                          fontFamily: 'VT323',
                          fontSize: 17,
                          color: Colors.white70,
                          letterSpacing: 1,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 16),
                      _formPips(accent),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (slot != null)
            Positioned(
              top: -8,
              right: -4,
              child: Transform.rotate(
                angle: 0.07,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  color: DossedartTokens.yellow,
                  child: Text(
                    'P$slot',
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 10,
                      color: DossedartTokens.bg,
                      letterSpacing: 1,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 5 placeholder W/L pips. Recent-results tracking isn't wired up yet
  /// (see project memory) — every pip renders as '?'.
  Widget _formPips(Color accent) {
    final pips = <Widget>[];
    for (var i = 0; i < 5; i++) {
      pips.add(_pip());
      if (i < 4) pips.add(const SizedBox(width: 4));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: pips);
  }

  Widget _pip() {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      alignment: Alignment.center,
      child: const Text(
        '?',
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 8,
          color: Colors.white30,
          height: 1,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/widgets/dossedart/setup/dossedart_picker_tile.dart`
Expected: No errors (info-level lints OK)

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/dossedart/setup/dossedart_picker_tile.dart
git commit -m "feat(dossedart): extract DossedartPickerTile widget"
```

---

## Task 5: DossedartPlayerPicker

A stateless 2-column grid of `DossedartPickerTile`s plus an ADD PLAYER tile.

**Files:**
- Create: `lib/widgets/dossedart/setup/dossedart_player_picker.dart`

- [ ] **Step 1: Create the file**

Create `lib/widgets/dossedart/setup/dossedart_player_picker.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../models/saved_player.dart';
import '../../../theme/dossedart_tokens.dart';
import 'dossedart_picker_tile.dart';

/// 2-column grid of picker tiles plus an ADD PLAYER tile.
///
/// Pure presentation — caller passes the saved players, the current
/// selection (in order), and three callbacks.
class DossedartPlayerPicker extends StatelessWidget {
  const DossedartPlayerPicker({
    super.key,
    required this.savedPlayers,
    required this.selectedIds,
    required this.onToggle,
    required this.onLongPress,
    required this.onAdd,
  });

  final List<SavedPlayer> savedPlayers;
  final List<String> selectedIds;
  final ValueChanged<SavedPlayer> onToggle;
  final ValueChanged<SavedPlayer> onLongPress;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 142,
      ),
      itemCount: savedPlayers.length + 1,
      itemBuilder: (_, i) {
        if (i == savedPlayers.length) return _AddTile(onAdd: onAdd);
        final sp = savedPlayers[i];
        final slotIdx = selectedIds.indexOf(sp.id);
        return DossedartPickerTile(
          player: sp,
          selected: slotIdx >= 0,
          slot: slotIdx >= 0 ? slotIdx + 1 : null,
          onTap: () => onToggle(sp),
          onLongPress: () => onLongPress(sp),
        );
      },
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: DossedartTokens.cyan, width: 3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                border: Border.all(color: DossedartTokens.cyan, width: 2),
              ),
              alignment: Alignment.center,
              child: const Text(
                '+',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 20,
                  color: DossedartTokens.cyan,
                  letterSpacing: 1,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'ADD PLAYER',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 10,
                color: DossedartTokens.cyan,
                letterSpacing: 1.5,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/widgets/dossedart/setup/dossedart_player_picker.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/dossedart/setup/dossedart_player_picker.dart
git commit -m "feat(dossedart): extract DossedartPlayerPicker grid"
```

---

## Task 6: DossedartSetupScaffold (state + dialogs)

The big one. Owns picker state, ADD-player + profile-edit dialogs, top-bar, start-bar.

**Files:**
- Create: `lib/widgets/dossedart/setup/dossedart_setup_scaffold.dart`

- [ ] **Step 1: Create the file**

Create `lib/widgets/dossedart/setup/dossedart_setup_scaffold.dart`:

```dart
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../models/player.dart';
import '../../../models/saved_player.dart';
import '../../../services/player_storage.dart';
import '../../../theme/dossedart_tokens.dart';
import '../arcade_frame.dart';
import 'dossedart_player_picker.dart';

/// Shared chrome for all DOSSEDART setup screens.
///
/// Owns the player roster, the current selection (in order = play order),
/// the random-order toggle, and all picker-side dialogs (add-player,
/// profile-edit). Mode-specific RULES are passed in via [rulesSection],
/// and the per-mode start logic is delegated to [onStart].
class DossedartSetupScaffold extends StatefulWidget {
  const DossedartSetupScaffold({
    super.key,
    required this.title,
    required this.rulesSection,
    required this.minPlayers,
    required this.summaryBuilder,
    required this.onStart,
  });

  final String title;
  final Widget rulesSection;
  final int minPlayers;

  /// Builds the trailing summary string shown under the START button.
  /// Receives the current count of selected players so the caller can
  /// inject mode-config text (e.g. 'CUTTHROAT · RANDOM TARGETS').
  final String Function(int playerCount) summaryBuilder;

  /// Called when the user taps START. The scaffold supplies the ordered
  /// player list (with `score: 0` as a placeholder — the mode screen
  /// overrides if needed, e.g. for X01 handicap) and the randomize flag.
  /// The mode screen is responsible for any final shuffle and navigation.
  final void Function(List<Player> players, bool randomize) onStart;

  @override
  State<DossedartSetupScaffold> createState() => _DossedartSetupScaffoldState();
}

class _DossedartSetupScaffoldState extends State<DossedartSetupScaffold> {
  List<SavedPlayer> _savedPlayers = [];
  final List<String> _selectedIds = []; // preserves slot order
  bool _isLoading = true;
  bool _randomOrder = true; // default ON per spec

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final players = await PlayerStorage.loadPlayers();
    players.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() {
      _savedPlayers = players;
      _isLoading = false;
    });
  }

  void _toggleSelected(SavedPlayer sp) {
    setState(() {
      if (_selectedIds.contains(sp.id)) {
        _selectedIds.remove(sp.id);
      } else {
        _selectedIds.add(sp.id);
      }
    });
  }

  Future<void> _addNewPlayer() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('NEW FIGHTER'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    final name = controller.text.trim();
    controller.dispose();
    if (ok != true || name.isEmpty) return;

    final saved = await PlayerStorage.addPlayer(name);
    setState(() {
      _savedPlayers.add(saved);
      _savedPlayers.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _selectedIds.add(saved.id);
    });
  }

  Future<void> _showPlayerProfile(SavedPlayer sp) async {
    final nameController = TextEditingController(text: sp.name);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Player profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final imagePath = await _pickImage();
                    if (imagePath == null) return;
                    final dir = await getApplicationDocumentsDirectory();
                    final avatarDir = Directory('${dir.path}/avatars');
                    if (!avatarDir.existsSync()) {
                      avatarDir.createSync(recursive: true);
                    }
                    final ext = p.extension(imagePath);
                    final dest = '${avatarDir.path}/${sp.id}$ext';
                    await File(imagePath).copy(dest);
                    sp.avatarPath = dest;
                    await PlayerStorage.savePlayers(_savedPlayers);
                    setDialogState(() {});
                    setState(() {});
                  },
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: sp.avatarPath != null
                        ? FileImage(File(sp.avatarPath!))
                        : null,
                    child: sp.avatarPath == null
                        ? const Icon(Icons.add_a_photo, size: 32)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                _stat('Rating', sp.rating.round().toString()),
                _stat('Games played', sp.gamesPlayed.toString()),
                _stat('Win rate',
                    '${(sp.winRate * 100).toStringAsFixed(0)}%'),
                _stat('Avg turn score', sp.averageTurnScore.toStringAsFixed(1)),
                _stat('Best turn', sp.highestTurnScore.toString()),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty && newName != sp.name) {
                  sp.name = newName;
                  await PlayerStorage.savePlayers(_savedPlayers);
                  setState(() {});
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
  }

  Future<String?> _pickImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    return image?.path;
  }

  Widget _stat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _handleStart() {
    if (_selectedIds.length < widget.minPlayers) return;
    final byId = {for (final p in _savedPlayers) p.id: p};
    final players = _selectedIds
        .map((id) => byId[id]!)
        .map((sp) => Player(
              name: sp.name,
              score: 0,
              savedPlayerId: sp.id,
              avatarPath: sp.avatarPath,
            ))
        .toList();
    if (_randomOrder) players.shuffle(Random());
    widget.onStart(players, _randomOrder);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DossedartTokens.bg,
      body: ArcadeFrame(
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: DossedartTokens.magenta))
              : Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '► RULES',
                                style: TextStyle(
                                  fontFamily: 'PressStart2P',
                                  fontSize: 11,
                                  color: DossedartTokens.cyan,
                                  letterSpacing: 1.5,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 12),
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
                              _buildCastHeader(),
                              const SizedBox(height: 12),
                              DossedartPlayerPicker(
                                savedPlayers: _savedPlayers,
                                selectedIds: _selectedIds,
                                onToggle: _toggleSelected,
                                onLongPress: _showPlayerProfile,
                                onAdd: _addNewPlayer,
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildStartBar(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(color: DossedartTokens.magenta, width: 2),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text(
              '◀ HOME',
              style: TextStyle(
                fontFamily: 'VT323',
                fontSize: 18,
                color: DossedartTokens.cyan,
                letterSpacing: 2,
                height: 1,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 13,
                  color: DossedartTokens.yellow,
                  letterSpacing: 2,
                  height: 1.3,
                ),
              ),
            ),
          ),
          const Text(
            '1CR',
            style: TextStyle(
              fontFamily: 'VT323',
              fontSize: 16,
              color: Colors.white54,
              letterSpacing: 2,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCastHeader() {
    final count = _selectedIds.length;
    final readyLabel = count < widget.minPlayers
        ? '$count READY · MIN ${widget.minPlayers}'
        : '$count READY';
    return Row(
      children: [
        const Expanded(
          child: Text(
            '► PICK YOUR FIGHTERS',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 11,
              color: DossedartTokens.cyan,
              letterSpacing: 1.5,
              height: 1.3,
            ),
          ),
        ),
        Text(
          readyLabel,
          style: const TextStyle(
            fontFamily: 'VT323',
            fontSize: 14,
            color: DossedartTokens.yellow,
            letterSpacing: 2,
            height: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildStartBar() {
    final canStart = _selectedIds.length >= widget.minPlayers;
    final summary = widget.summaryBuilder(_selectedIds.length);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: DossedartTokens.yellow, width: 2),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        children: [
          GestureDetector(
            onTap: canStart ? _handleStart : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: canStart
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [DossedartTokens.yellow, Color(0xFFFFA500)],
                      )
                    : null,
                color: canStart ? null : Colors.white12,
                border: Border.all(
                  color: canStart ? Colors.white : Colors.white24,
                  width: 3,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '▶ START MATCH ◀',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 16,
                  color: canStart ? DossedartTokens.bg : Colors.white38,
                  letterSpacing: 2,
                  height: 1.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            style: const TextStyle(
              fontFamily: 'VT323',
              fontSize: 15,
              color: Colors.white60,
              letterSpacing: 3,
              height: 1,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/widgets/dossedart/setup/dossedart_setup_scaffold.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/dossedart/setup/dossedart_setup_scaffold.dart
git commit -m "feat(dossedart): add shared DossedartSetupScaffold"
```

---

## Task 7: Scaffold widget tests

Lock the start-bar logic (disable-below-min, summary-builder wiring, onStart callback).

**Files:**
- Create: `test/widgets/dossedart/dossedart_setup_scaffold_test.dart`

- [ ] **Step 1: Write the tests**

Create `test/widgets/dossedart/dossedart_setup_scaffold_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring_app/models/player.dart';
import 'package:dart_scoring_app/models/saved_player.dart';
import 'package:dart_scoring_app/services/player_storage.dart';
import 'package:dart_scoring_app/widgets/dossedart/setup/dossedart_setup_scaffold.dart';

Future<void> _seedPlayers(List<String> names) async {
  SharedPreferences.setMockInitialValues({});
  final saved = <SavedPlayer>[];
  for (final n in names) {
    saved.add(await PlayerStorage.addPlayer(n));
  }
  await PlayerStorage.savePlayers(saved);
}

Widget _harness({
  required int minPlayers,
  required String Function(int) summaryBuilder,
  required void Function(List<Player>, bool) onStart,
}) {
  return MaterialApp(
    home: DossedartSetupScaffold(
      title: 'TEST',
      rulesSection: const SizedBox.shrink(),
      minPlayers: minPlayers,
      summaryBuilder: summaryBuilder,
      onStart: onStart,
    ),
  );
}

void main() {
  // NOTE: ArcadeFrame runs a continuous AnimationController, so we never use
  // pumpAndSettle (it would hang). Instead, pump twice — once to render the
  // loading state, once after a small duration to let _load()'s async future
  // resolve.
  Future<void> _settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('start button disabled when zero players selected', (tester) async {
    await _seedPlayers(['Alice', 'Bob']);
    bool called = false;
    await tester.pumpWidget(_harness(
      minPlayers: 2,
      summaryBuilder: (_) => '',
      onStart: (_, __) => called = true,
    ));
    await _settle(tester);
    await tester.tap(find.text('▶ START MATCH ◀'));
    await tester.pump();
    expect(called, isFalse);
  });

  testWidgets('summary shows MIN N when under threshold', (tester) async {
    await _seedPlayers(['Alice', 'Bob']);
    await tester.pumpWidget(_harness(
      minPlayers: 2,
      summaryBuilder: (n) => '$n PLAYERS',
      onStart: (_, __) {},
    ));
    await _settle(tester);
    // CAST header shows MIN; we verify the cast header label.
    expect(find.text('0 READY · MIN 2'), findsOneWidget);
  });

  testWidgets('start triggers onStart with selected players', (tester) async {
    await _seedPlayers(['Alice', 'Bob', 'Carol']);
    List<Player>? captured;
    bool? randomized;
    await tester.pumpWidget(_harness(
      minPlayers: 2,
      summaryBuilder: (_) => '',
      onStart: (p, r) {
        captured = p;
        randomized = r;
      },
    ));
    await _settle(tester);
    // Tap Alice and Carol. Names render uppercased in tiles.
    await tester.tap(find.text('ALICE'));
    await tester.pump();
    await tester.tap(find.text('CAROL'));
    await tester.pump();
    // Scroll the START button into view if needed.
    await tester.ensureVisible(find.text('▶ START MATCH ◀'));
    await tester.pump();
    await tester.tap(find.text('▶ START MATCH ◀'));
    await tester.pump();
    expect(captured, isNotNull);
    expect(captured!.length, 2);
    expect(randomized, isTrue); // default RANDOM ORDER on
  });
}
```

- [ ] **Step 2: Run tests**

Run: `flutter test test/widgets/dossedart/dossedart_setup_scaffold_test.dart`
Expected: PASS (3 tests)

If a test fails because the random shuffle makes order assertions flaky, do NOT add ordering assertions — the test above only checks count.

- [ ] **Step 3: Commit**

```bash
git add test/widgets/dossedart/dossedart_setup_scaffold_test.dart
git commit -m "test(dossedart): scaffold start-bar logic"
```

---

## Task 8: Refactor X01 setup to use scaffold

Replace the inline scaffold/picker code in `dossedart_x01_setup_screen.dart` with a composition of the new scaffold + an inline RULES section.

**Files:**
- Modify: `lib/screens/dossedart/dossedart_x01_setup_screen.dart`

- [ ] **Step 1: Rewrite the file**

Replace the entire contents of `lib/screens/dossedart/dossedart_x01_setup_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../theme/dossedart_tokens.dart';
import '../../widgets/dossedart/setup/dossedart_setup_scaffold.dart';
import '../../widgets/dossedart/setup/rules_primitives.dart';
import '../game_screen.dart';

/// DOSSEDART X01 setup — picks players + X01 rules.
/// Start score is chosen on the home screen and passed in.
class DossedartX01SetupScreen extends StatefulWidget {
  const DossedartX01SetupScreen({super.key, required this.startingScore});

  final int startingScore;

  @override
  State<DossedartX01SetupScreen> createState() =>
      _DossedartX01SetupScreenState();
}

class _DossedartX01SetupScreenState extends State<DossedartX01SetupScreen> {
  String _outRule = 'none'; // 'none' (free) | 'double' | 'master'
  bool _noBust = false;
  bool _handicap = false;

  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: 'NEW MATCH · ${widget.startingScore}',
      minPlayers: 2,
      rulesSection: _buildRules(),
      summaryBuilder: _summary,
      onStart: _startGame,
    );
  }

  Widget _buildRules() {
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
          ('NO-BUST', _noBust, DossedartTokens.magenta,
              (v) => setState(() => _noBust = v)),
          ('HANDICAP', _handicap, DossedartTokens.cyan,
              (v) => setState(() => _handicap = v)),
        ]),
      ],
    );
  }

  String _summary(int playerCount) {
    final outLabel = switch (_outRule) {
      'double' => 'DOUBLE OUT',
      'master' => 'MASTER OUT',
      _ => 'FREE OUT',
    };
    return [
      '$playerCount PLAYERS',
      outLabel,
      if (_noBust) 'NO-BUST',
      if (_handicap) 'HANDICAP',
    ].join(' · ');
  }

  void _startGame(List<Player> players, bool randomize) {
    // X01 starting score override (and would be where handicap applies).
    final withScore = players
        .map((p) => Player(
              name: p.name,
              score: widget.startingScore,
              savedPlayerId: p.savedPlayerId,
              avatarPath: p.avatarPath,
            ))
        .toList();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          players: withScore,
          masterOut: _outRule,
          startingScore: widget.startingScore,
          handicap: _handicap,
          noBust: _noBust,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/screens/dossedart/dossedart_x01_setup_screen.dart`
Expected: No errors

- [ ] **Step 3: Run full test suite to catch regressions**

Run: `flutter test`
Expected: All tests PASS

- [ ] **Step 4: Manual smoke test in emulator**

Launch the app on the Galaxy Tab emulator. Navigate Home → 301. Verify:
- Top bar shows `NEW MATCH · 301`
- OUT RULE chips work (FREE/DOUBLE/MASTER)
- NO-BUST and HANDICAP toggles work
- RANDOM ORDER toggle defaults ON
- Picker grid renders with existing players
- Long-press → profile dialog opens
- ADD PLAYER → creates a new player
- START is disabled with 0-1 players, enabled with 2+
- START → game opens with correct config

- [ ] **Step 5: Commit**

```bash
git add lib/screens/dossedart/dossedart_x01_setup_screen.dart
git commit -m "refactor(dossedart): X01 setup uses shared scaffold"
```

---

## Task 9: DossedartCricketSetupScreen

**Files:**
- Create: `lib/screens/dossedart/dossedart_cricket_setup_screen.dart`

- [ ] **Step 1: Create the file**

```dart
import 'package:flutter/material.dart';
import '../../models/game_config.dart';
import '../../models/player.dart';
import '../../theme/dossedart_tokens.dart';
import '../../widgets/dossedart/setup/dossedart_setup_scaffold.dart';
import '../../widgets/dossedart/setup/rules_primitives.dart';
import '../cricket_game_screen.dart';

class DossedartCricketSetupScreen extends StatefulWidget {
  const DossedartCricketSetupScreen({super.key});

  @override
  State<DossedartCricketSetupScreen> createState() =>
      _DossedartCricketSetupScreenState();
}

class _DossedartCricketSetupScreenState
    extends State<DossedartCricketSetupScreen> {
  bool _isCutthroat = false;
  bool _isRandom = false;
  int _targetCount = 7;
  bool _includeBull = true;

  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: 'CRICKET',
      minPlayers: 2,
      rulesSection: _buildRules(),
      summaryBuilder: _summary,
      onStart: _startGame,
    );
  }

  Widget _buildRules() {
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
          ('BULL', _includeBull, DossedartTokens.magenta,
              (v) => setState(() => _includeBull = v)),
        ]),
      ],
    );
  }

  String _summary(int playerCount) {
    return [
      '$playerCount PLAYERS',
      if (_isCutthroat) 'CUTTHROAT' else 'STANDARD',
      if (_isRandom) 'RANDOM TARGETS' else '15-20',
      if (_includeBull) 'BULL',
    ].join(' · ');
  }

  void _startGame(List<Player> players, bool _) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CricketGameScreen(
          players: players,
          config: CricketConfig(
            isRandom: _isRandom,
            targetCount: _targetCount,
            includeBull: _includeBull,
            isCutthroat: _isCutthroat,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/screens/dossedart/dossedart_cricket_setup_screen.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/screens/dossedart/dossedart_cricket_setup_screen.dart
git commit -m "feat(dossedart): Cricket setup screen"
```

---

## Task 10: DossedartKillerSetupScreen

**Files:**
- Create: `lib/screens/dossedart/dossedart_killer_setup_screen.dart`

- [ ] **Step 1: Create the file**

```dart
import 'package:flutter/material.dart';
import '../../models/game_config.dart';
import '../../models/player.dart';
import '../../theme/dossedart_tokens.dart';
import '../../widgets/dossedart/setup/dossedart_setup_scaffold.dart';
import '../../widgets/dossedart/setup/rules_primitives.dart';
import '../killer_game_screen.dart';

class DossedartKillerSetupScreen extends StatefulWidget {
  const DossedartKillerSetupScreen({super.key});

  @override
  State<DossedartKillerSetupScreen> createState() =>
      _DossedartKillerSetupScreenState();
}

class _DossedartKillerSetupScreenState
    extends State<DossedartKillerSetupScreen> {
  int _lives = 3;
  bool _throwToPick = true;
  bool _multiplyHits = false;
  bool _shields = false;
  bool _suicide = false;

  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: 'KILLER',
      minPlayers: 2,
      rulesSection: _buildRules(),
      summaryBuilder: _summary,
      onStart: _startGame,
    );
  }

  Widget _buildRules() {
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
          ('×HITS', _multiplyHits, DossedartTokens.magenta,
              (v) => setState(() => _multiplyHits = v)),
          ('SHIELD', _shields, DossedartTokens.cyan,
              (v) => setState(() => _shields = v)),
          ('SUICIDE', _suicide, DossedartTokens.purple,
              (v) => setState(() => _suicide = v)),
        ]),
      ],
    );
  }

  String _summary(int playerCount) {
    return [
      '$playerCount PLAYERS',
      '$_lives LIVES',
      if (_throwToPick) 'THROW-PICK' else 'RANDOM PICK',
      if (_multiplyHits) '×HITS',
      if (_shields) 'SHIELDS',
      if (_suicide) 'SUICIDE',
    ].join(' · ');
  }

  void _startGame(List<Player> players, bool _) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => KillerGameScreen(
          players: players,
          config: KillerConfig(
            throwToPick: _throwToPick,
            lives: _lives,
            multiplyHits: _multiplyHits,
            shields: _shields,
            suicide: _suicide,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/screens/dossedart/dossedart_killer_setup_screen.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/screens/dossedart/dossedart_killer_setup_screen.dart
git commit -m "feat(dossedart): Killer setup screen (min players = 2)"
```

---

## Task 11: DossedartAtcSetupScreen

**Files:**
- Create: `lib/screens/dossedart/dossedart_atc_setup_screen.dart`

- [ ] **Step 1: Create the file**

```dart
import 'package:flutter/material.dart';
import '../../models/game_config.dart';
import '../../models/player.dart';
import '../../theme/dossedart_tokens.dart';
import '../../widgets/dossedart/setup/dossedart_setup_scaffold.dart';
import '../../widgets/dossedart/setup/rules_primitives.dart';
import '../around_the_clock_game_screen.dart';

class DossedartAtcSetupScreen extends StatefulWidget {
  const DossedartAtcSetupScreen({super.key});

  @override
  State<DossedartAtcSetupScreen> createState() =>
      _DossedartAtcSetupScreenState();
}

class _DossedartAtcSetupScreenState extends State<DossedartAtcSetupScreen> {
  bool _includeBull = false;
  bool _countMultiples = true;
  bool _reverse = false;

  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: 'AROUND THE CLOCK',
      minPlayers: 1,
      rulesSection: _buildRules(),
      summaryBuilder: _summary,
      onStart: _startGame,
    );
  }

  Widget _buildRules() {
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
          ('BULL', _includeBull, DossedartTokens.magenta,
              (v) => setState(() => _includeBull = v)),
          ('×MULT', _countMultiples, DossedartTokens.cyan,
              (v) => setState(() => _countMultiples = v)),
        ]),
      ],
    );
  }

  String _summary(int playerCount) {
    return [
      '$playerCount PLAYERS',
      if (_reverse) '20→1' else '1→20',
      if (_includeBull) 'BULL',
      if (_countMultiples) '×MULT',
    ].join(' · ');
  }

  void _startGame(List<Player> players, bool _) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AroundTheClockGameScreen(
          players: players,
          config: AroundTheClockConfig(
            includeBull: _includeBull,
            countMultiples: _countMultiples,
            reverse: _reverse,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/screens/dossedart/dossedart_atc_setup_screen.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/screens/dossedart/dossedart_atc_setup_screen.dart
git commit -m "feat(dossedart): Around the Clock setup screen"
```

---

## Task 12: DossedartSplitscoreSetupScreen

(Halve It rebranded to Splitscore per project memory.)

**Files:**
- Create: `lib/screens/dossedart/dossedart_splitscore_setup_screen.dart`

- [ ] **Step 1: Create the file**

```dart
import 'package:flutter/material.dart';
import '../../models/game_config.dart';
import '../../models/player.dart';
import '../../theme/dossedart_tokens.dart';
import '../../widgets/dossedart/setup/dossedart_setup_scaffold.dart';
import '../../widgets/dossedart/setup/rules_primitives.dart';
import '../halve_it_game_screen.dart';

class DossedartSplitscoreSetupScreen extends StatefulWidget {
  const DossedartSplitscoreSetupScreen({super.key});

  @override
  State<DossedartSplitscoreSetupScreen> createState() =>
      _DossedartSplitscoreSetupScreenState();
}

class _DossedartSplitscoreSetupScreenState
    extends State<DossedartSplitscoreSetupScreen> {
  bool _isRandom = false;
  int _roundCount = 9;
  bool _includeDouble = true;
  bool _includeTriple = true;
  bool _includeBull = true;

  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: 'SPLITSCORE',
      minPlayers: 1,
      rulesSection: _buildRules(),
      summaryBuilder: _summary,
      onStart: _startGame,
    );
  }

  Widget _buildRules() {
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
            ('DBL', _includeDouble, DossedartTokens.magenta,
                (v) => setState(() => _includeDouble = v)),
            ('TPL', _includeTriple, DossedartTokens.cyan,
                (v) => setState(() => _includeTriple = v)),
            ('BULL', _includeBull, DossedartTokens.purple,
                (v) => setState(() => _includeBull = v)),
          ]),
        ] else ...[
          const SizedBox(height: 14),
          ArcadeToggleRow(toggles: [
            ('BULL', _includeBull, DossedartTokens.purple,
                (v) => setState(() => _includeBull = v)),
          ]),
        ],
      ],
    );
  }

  String _summary(int playerCount) {
    return [
      '$playerCount PLAYERS',
      if (_isRandom) 'RANDOM · $_roundCount RND' else 'STANDARD',
      if (_includeBull) 'BULL',
    ].join(' · ');
  }

  void _startGame(List<Player> players, bool _) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HalveItGameScreen(
          players: players,
          config: HalveItConfig(
            isRandom: _isRandom,
            roundCount: _roundCount,
            includeDouble: _includeDouble,
            includeTriple: _includeTriple,
            includeBull: _includeBull,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/screens/dossedart/dossedart_splitscore_setup_screen.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/screens/dossedart/dossedart_splitscore_setup_screen.dart
git commit -m "feat(dossedart): Splitscore setup screen"
```

---

## Task 13: DossedartShanghaiSetupScreen

**Files:**
- Create: `lib/screens/dossedart/dossedart_shanghai_setup_screen.dart`

- [ ] **Step 1: Create the file**

```dart
import 'package:flutter/material.dart';
import '../../models/game_config.dart';
import '../../models/player.dart';
import '../../widgets/dossedart/setup/dossedart_setup_scaffold.dart';
import '../../widgets/dossedart/setup/rules_primitives.dart';
import '../shanghai_game_screen.dart';

class DossedartShanghaiSetupScreen extends StatefulWidget {
  const DossedartShanghaiSetupScreen({super.key});

  @override
  State<DossedartShanghaiSetupScreen> createState() =>
      _DossedartShanghaiSetupScreenState();
}

class _DossedartShanghaiSetupScreenState
    extends State<DossedartShanghaiSetupScreen> {
  int _targetEnd = 7;

  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: 'SHANGHAI',
      minPlayers: 1,
      rulesSection: _buildRules(),
      summaryBuilder: _summary,
      onStart: _startGame,
    );
  }

  Widget _buildRules() {
    return ArcadeChipRow<int>(
      label: 'TARGET RANGE',
      value: _targetEnd,
      options: const [('1-7', 7), ('1-9', 9), ('1-20', 20)],
      onChanged: (v) => setState(() => _targetEnd = v),
    );
  }

  String _summary(int playerCount) {
    return [
      '$playerCount PLAYERS',
      '1 → $_targetEnd',
    ].join(' · ');
  }

  void _startGame(List<Player> players, bool _) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ShanghaiGameScreen(
          players: players,
          config: ShanghaiConfig(targetEnd: _targetEnd),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/screens/dossedart/dossedart_shanghai_setup_screen.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/screens/dossedart/dossedart_shanghai_setup_screen.dart
git commit -m "feat(dossedart): Shanghai setup screen"
```

---

## Task 14: Wire home-screen routing

Route all five non-X01 mode tiles to the new setup screens.

**Files:**
- Modify: `lib/screens/dossedart/dossedart_home_screen.dart` (around lines 540-560)

- [ ] **Step 1: Update imports**

At the top of `lib/screens/dossedart/dossedart_home_screen.dart`, replace the line:

```dart
import '../player_setup_screen.dart';
```

with:

```dart
import 'dossedart_atc_setup_screen.dart';
import 'dossedart_cricket_setup_screen.dart';
import 'dossedart_killer_setup_screen.dart';
import 'dossedart_shanghai_setup_screen.dart';
import 'dossedart_splitscore_setup_screen.dart';
```

Also, near the top, you'll already see `import '../../models/game_mode.dart';` — leave it.

- [ ] **Step 2: Rewrite `_startGame`**

Find the `_startGame` method (around line 545). Replace its body with:

```dart
  Future<void> _startGame(GameMode mode, {int? startingScore}) async {
    Widget screen;
    switch (mode) {
      case GameMode.x01:
        screen = DossedartX01SetupScreen(startingScore: startingScore!);
      case GameMode.cricket:
        screen = const DossedartCricketSetupScreen();
      case GameMode.killer:
        screen = const DossedartKillerSetupScreen();
      case GameMode.aroundTheClock:
        screen = const DossedartAtcSetupScreen();
      case GameMode.halveIt:
        screen = const DossedartSplitscoreSetupScreen();
      case GameMode.shanghai:
        screen = const DossedartShanghaiSetupScreen();
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _loadTopPlayers();
  }
```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/screens/dossedart/dossedart_home_screen.dart`
Expected: No errors (unused import warnings on the removed `player_setup_screen.dart` should be gone)

- [ ] **Step 4: Run full test suite**

Run: `flutter test`
Expected: All tests PASS

- [ ] **Step 5: Manual QA — all six modes**

Launch on Galaxy Tab emulator. For each mode (X01-301, Cricket, Killer, ATC, Splitscore, Shanghai):

1. Home → mode tile → setup. Top bar shows the right title.
2. Select 2-3 players. P1/P2 slot badges appear in selection order.
3. Long-press a tile → profile dialog opens. Edit name → tile refreshes.
4. Tap each chip / toggle / stepper-button in the RULES section. Verify state changes.
5. Summary text in start-bar updates on every config change.
6. START disabled below min-players; enables at or above (X01/Cricket/Killer=2, ATC/Splitscore/Shanghai=1).
7. START → correct game screen opens with correct config. Player order shuffled (RANDOM ORDER default ON).

- [ ] **Step 6: Commit**

```bash
git add lib/screens/dossedart/dossedart_home_screen.dart
git commit -m "feat(dossedart): route all modes to new arcade setup screens"
```

---

## Self-review checklist

Before declaring the plan complete, run:

- [ ] `flutter analyze` — no errors
- [ ] `flutter test` — all pass
- [ ] Manual QA pass on all 6 modes (see Task 14, Step 5)

## Out of scope (for follow-up)

- Roster / profile management screen (planned separately per project memory).
- Persisting last-used mode config across sessions.
- Manual reorder of selected players.
- Deleting `lib/screens/player_setup_screen.dart` (kept as legacy fallback until DOSSEDART becomes the default theme).
