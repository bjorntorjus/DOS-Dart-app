# DOSSEDART toggle visibility

**Status:** Approved 2026-05-12
**Branch:** `feat/dossedart-arcade-v1`
**Context:** Galaxy Tab QA found the ON/OFF state of arcade toggles (RANDOM ORDER, BULL, HANDICAP, ×HITS, etc.) hard to read from normal reading distance. ON and OFF differed only by a subtle 15% background tint, text color shift, and `●`/`○` glyph swap. Border stayed identical between states, removing the strongest visual signal.

## Goal

Make ON state unmistakable while preserving each toggle's per-color identity in OFF state.

## Visual specification

### ArcadeToggleRow toggle states

| State | Background | Border | Text color | Weight | Glyph |
|---|---|---|---|---|---|
| **ON** | `accent` (full opacity) | `DossedartTokens.yellow`, 2px | `DossedartTokens.bg` | bold | `●` |
| **OFF** | `DossedartTokens.surface` | `accent.withValues(alpha: 0.4)`, 2px | `accent.withValues(alpha: 0.6)` | normal | `○` |

Rationale:
- Yellow border on ON mirrors the existing chip-row "yellow = selected" language — toggles and chips now speak the same visual idiom.
- Filled accent background gives the unmistakable "lit up" arcade feel.
- Dim accent border/text in OFF keeps per-toggle color identity (NO-BUST stays "the magenta one"), so users learn the color associations.

### Padding, size, font

Unchanged: vertical 8 / horizontal 4 padding, PressStart2P size 9, letterSpacing 0.5, height 1.3, accent border 2px in both states.

## Scope

### Modified

**`lib/widgets/dossedart/setup/rules_primitives.dart`**
- `ArcadeToggleRow._toggle`: apply the new state styling table above.

**`lib/widgets/dossedart/setup/dossedart_setup_scaffold.dart`**
- Replace the inline RANDOM ORDER toggle (currently hardcoded purple `GestureDetector + Container`) with `ArcadeToggleRow(toggles: [('RANDOM ORDER', _randomOrder, DossedartTokens.purple, (v) => setState(() => _randomOrder = v))])`. Single source of truth for toggle styling.

### Tests

**`test/widgets/dossedart/rules_primitives_test.dart`**
- Existing 3 ArcadeToggleRow tests still pass (they verify label, callback, glyph — not specific colors).
- Add one test: **`ON toggle border uses DossedartTokens.yellow`**. Verifies the visual signal that drove this change.

### Untouched

- `ArcadeChipRow` styling (already clear).
- Toggle dimensions / padding / typography.
- Animation / transitions (pure state swap).

## Acceptance

- Galaxy Tab visual QA: at normal arm's-length, ON toggles are distinguishable from OFF at a glance for all four accent colors (magenta, cyan, purple, yellow when used).
- All existing tests pass.
- One new test asserts the yellow border on ON.
