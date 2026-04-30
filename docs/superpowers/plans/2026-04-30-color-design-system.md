# Color & Design System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the M3 branch to the four-role palette defined in `docs/superpowers/specs/2026-04-30-color-design-system.md` — replace `Colors.amber`/`Colors.orange` literals with `cs.tertiary`/`cs.secondary` and codify rules in `CLAUDE.md`.

**Architecture:** Pure refactor. The theme in `main.dart` gets `tertiary` added and `secondary` swapped from red to orange. All hex/named-color literals that semantically match an M3 role are replaced with `Theme.of(context).colorScheme.<role>`. Three categories of color stay as-is: dart-input button colors (D = orange[800] is functional, not role), heatmap gradient (data viz), and `avatarColor` palette (separate per spec).

**Tech Stack:** Flutter, Dart, Material 3 ColorScheme. No new dependencies.

**Verification:** No widget tests exist for color usage. Each task ends with `flutter analyze` (must pass with zero new issues) and a commit. After all tasks: build APK + manual visual smoke test against the spec's state-signaling table.

---

## File map

**Modify:**
- `lib/main.dart` — add tertiary, change secondary
- `lib/screens/post_game_screen.dart` — winner amber → tertiary; stats-skipped orange → secondary
- `lib/screens/stats_screen.dart` — podium amber → tertiary
- `lib/screens/game_screen.dart` — checkout amber → tertiary
- `lib/screens/halve_it_game_screen.dart` — current-target amber → tertiary (D-buttons stay)
- `lib/screens/around_the_clock_game_screen.dart` — current-target amber → tertiary (D-button stays)
- `lib/screens/killer_game_screen.dart` — current-target/highlight amber + orange → tertiary
- `lib/widgets/checkout_widget.dart` — checkout amber → tertiary
- `lib/widgets/clock_progress.dart` — current-target amber → tertiary
- `lib/widgets/halve_it_scoreboard.dart` — current-row amber → tertiary
- `lib/widgets/mid_game_player_sheet.dart` — info orange → secondary
- `CLAUDE.md` — add palette rules section

**Out of scope (explicitly preserved):**
- `lib/widgets/heatmap_board.dart` — data-viz palette, not role colors
- `lib/utils/player_colors.dart` — avatar palette per spec
- `lib/screens/halve_it_game_screen.dart:864-903` and `around_the_clock_game_screen.dart:553` — `Colors.orange[800]` for D-buttons (dart-input semantics)

---

## Task 1: Update theme palette

**Files:**
- Modify: `lib/main.dart:42-48`

- [ ] **Step 1: Read main.dart around the ColorScheme.fromSeed call**

Run: open `lib/main.dart` and confirm lines 42-48 match the snippet below.

- [ ] **Step 2: Replace the ColorScheme.fromSeed override**

In `lib/main.dart`, replace:

```dart
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF43A047),
          brightness: Brightness.dark,
          primary: const Color(0xFF43A047),
          secondary: const Color(0xFFE53935),
          error: const Color(0xFFE53935),
        ),
```

with:

```dart
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF43A047),
          brightness: Brightness.dark,
          primary: const Color(0xFF43A047),
          secondary: const Color(0xFFFFA726),
          tertiary: const Color(0xFFFFD54F),
          error: const Color(0xFFE53935),
        ),
```

- [ ] **Step 3: Verify analyze passes**

Run: `flutter analyze lib/main.dart`
Expected: no new issues. Pre-existing infos in other files are OK; analyzer should not flag main.dart for this change.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat(theme): add tertiary role + swap secondary to orange"
```

---

## Task 2: Migrate winner/podium amber → tertiary

**Files:**
- Modify: `lib/screens/post_game_screen.dart` (winner header + placement color helper)
- Modify: `lib/screens/stats_screen.dart:339`

- [ ] **Step 1: post_game_screen — winner banner**

In `lib/screens/post_game_screen.dart`, find the winner banner around line 25-58. The `build` method must already have a `cs` local; if not, add `final cs = Theme.of(context).colorScheme;` at the top of `build`. Then replace:

```dart
                colors: [
                  Colors.amber.withAlpha(40),
                  Colors.transparent,
                ],
```
with:
```dart
                colors: [
                  cs.tertiary.withAlpha(40),
                  Colors.transparent,
                ],
```

And replace:
```dart
                const Icon(Icons.emoji_events, size: 48, color: Colors.amber),
```
with:
```dart
                Icon(Icons.emoji_events, size: 48, color: cs.tertiary),
```

And replace:
```dart
                const Text('Winner!',
                    style: TextStyle(color: Colors.amber, fontSize: 16)),
```
with:
```dart
                Text('Winner!',
                    style: TextStyle(color: cs.tertiary, fontSize: 16)),
```

(Drop `const` where the color now comes from context.)

- [ ] **Step 2: post_game_screen — placement color helper**

In `lib/screens/post_game_screen.dart` around line 144-156, replace:

```dart
  Color _placementColor(int p, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (p) {
      case 1:
        return Colors.amber;
      case 2:
        return cs.onSurface.withValues(alpha: 0.7);
      case 3:
        return Colors.brown[300]!;
      default:
        return cs.onSurface.withValues(alpha: 0.4);
    }
  }
```

with:

```dart
  Color _placementColor(int p, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (p) {
      case 1:
        return cs.tertiary;
      case 2:
        return cs.onSurface.withValues(alpha: 0.7);
      case 3:
        return Colors.brown[300]!;
      default:
        return cs.onSurface.withValues(alpha: 0.4);
    }
  }
```

(Bronze stays `Colors.brown[300]` — bronze is not in the role palette, and it's a single literal that reads as bronze. Document in CLAUDE.md.)

- [ ] **Step 3: stats_screen — podium**

In `lib/screens/stats_screen.dart` around line 338, replace:

```dart
                      color: rank == 0
                          ? Colors.amber
                          : rank == 1
```

with:

```dart
                      color: rank == 0
                          ? Theme.of(context).colorScheme.tertiary
                          : rank == 1
```

- [ ] **Step 4: Verify**

Run: `flutter analyze lib/screens/post_game_screen.dart lib/screens/stats_screen.dart`
Expected: no new issues.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/post_game_screen.dart lib/screens/stats_screen.dart
git commit -m "refactor(theme): winner/podium amber literals → cs.tertiary"
```

---

## Task 3: Migrate checkout-tip amber → tertiary

**Files:**
- Modify: `lib/widgets/checkout_widget.dart`
- Modify: `lib/screens/game_screen.dart:1532, 1540`

- [ ] **Step 1: checkout_widget**

In `lib/widgets/checkout_widget.dart`, replace the `build` method body's container/icon block. Find:

```dart
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.amber[600], size: 16),
```

Replace with:

```dart
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.tertiary.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.tertiary.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lightbulb_outline, color: cs.tertiary, size: 16),
```

- [ ] **Step 2: game_screen — checkout label**

In `lib/screens/game_screen.dart` around line 1525-1545, replace:

```dart
                        Text(
                          'Checkout',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.amber[400],
                          ),
                        ),
                        Text(
                          _checkoutFor(currentPlayer.score),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[600],
                          ),
                        ),
```

with:

```dart
                        Text(
                          'Checkout',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.8),
                          ),
                        ),
                        Text(
                          _checkoutFor(currentPlayer.score),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                        ),
```

- [ ] **Step 3: Verify**

Run: `flutter analyze lib/widgets/checkout_widget.dart lib/screens/game_screen.dart`
Expected: no new issues.

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/checkout_widget.dart lib/screens/game_screen.dart
git commit -m "refactor(theme): checkout-tip amber literals → cs.tertiary"
```

---

## Task 4: Migrate current-target highlights → tertiary

**Files:**
- Modify: `lib/widgets/clock_progress.dart:46, 49`
- Modify: `lib/widgets/halve_it_scoreboard.dart:63, 72`
- Modify: `lib/screens/halve_it_game_screen.dart:680, 685, 695`
- Modify: `lib/screens/around_the_clock_game_screen.dart:1109`
- Modify: `lib/screens/killer_game_screen.dart:786, 797, 897, 1011, 1060`

- [ ] **Step 1: clock_progress**

In `lib/widgets/clock_progress.dart`, change the `build` method. After line `return Padding(`, the existing code uses `Theme.of(context).colorScheme` already. Replace inside the `Container` (lines 38-51):

```dart
              color: done
                  ? Colors.green
                  : isCurrent
                      ? Colors.amber
                      : Theme.of(context).colorScheme.surfaceContainerLow,
              border: isCurrent
                  ? Border.all(color: Colors.amber, width: 2)
                  : null,
```

with:

```dart
              color: done
                  ? Theme.of(context).colorScheme.primary
                  : isCurrent
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.surfaceContainerLow,
              border: isCurrent
                  ? Border.all(color: Theme.of(context).colorScheme.tertiary, width: 2)
                  : null,
```

(Also: `Colors.green` for "done" → `cs.primary`. This was a hex literal that should already have been migrated in round 1 but slipped through.)

- [ ] **Step 2: halve_it_scoreboard**

In `lib/widgets/halve_it_scoreboard.dart` around line 63 and 72, replace:

```dart
                color: isCurrent
                    ? WidgetStatePropertyAll(Colors.amber.withAlpha(20))
                    : null,
```

with:

```dart
                color: isCurrent
                    ? WidgetStatePropertyAll(Theme.of(context).colorScheme.tertiary.withAlpha(20))
                    : null,
```

And replace:

```dart
                      color: isCurrent ? Colors.amber : null,
```

with:

```dart
                      color: isCurrent ? Theme.of(context).colorScheme.tertiary : null,
```

- [ ] **Step 3: halve_it_game_screen — current target highlight**

In `lib/screens/halve_it_game_screen.dart` around lines 680-695, replace `Colors.amber` (3 occurrences in the highlighted target block) with `Theme.of(context).colorScheme.tertiary`. Use Edit with `replace_all: false` and unique surrounding context per occurrence:

Replace:
```dart
                        ? Colors.amber.withAlpha(40)
```
with:
```dart
                        ? Theme.of(context).colorScheme.tertiary.withAlpha(40)
```

Replace:
```dart
                        ? Border.all(color: Colors.amber, width: 1.5)
```
with:
```dart
                        ? Border.all(color: Theme.of(context).colorScheme.tertiary, width: 1.5)
```

Replace (the one at ~line 695):
```dart
                          ? Colors.amber
                          : Theme.of(context).colorScheme.onSurface,
```
with:
```dart
                          ? Theme.of(context).colorScheme.tertiary
                          : Theme.of(context).colorScheme.onSurface,
```

(If this exact pair isn't unique, add the `:` line as anchor — `replace_all: false` on Edit, with enough context to be unique.)

- [ ] **Step 4: around_the_clock_game_screen — winner trophy**

In `lib/screens/around_the_clock_game_screen.dart` around line 1109, replace:

```dart
                                            color: Colors.amber, size: 28)
```

with:

```dart
                                            color: Theme.of(context).colorScheme.tertiary, size: 28)
```

- [ ] **Step 5: killer_game_screen — five amber/orange literals**

In `lib/screens/killer_game_screen.dart`, change all five highlight uses to tertiary.

Around line 786:
```dart
                              ? Colors.amber
```
→
```dart
                              ? Theme.of(context).colorScheme.tertiary
```

Around line 797:
```dart
                                          ? Colors.orange
```
→
```dart
                                          ? Theme.of(context).colorScheme.tertiary
```

(Per spec: this `orange` is a "danger lite" target highlight, not a true secondary action — tertiary is the right role.)

Around line 897:
```dart
                          color: Colors.amber, fontSize: 12)),
```
→
```dart
                          color: Theme.of(context).colorScheme.tertiary, fontSize: 12)),
```

Around line 1011:
```dart
                                  color: Colors.amber, size: 20)
```
→
```dart
                                  color: Theme.of(context).colorScheme.tertiary, size: 20)
```

Around line 1060:
```dart
                                    color: Colors.amber,
```
→
```dart
                                    color: Theme.of(context).colorScheme.tertiary,
```

- [ ] **Step 6: Verify**

Run: `flutter analyze lib/widgets/clock_progress.dart lib/widgets/halve_it_scoreboard.dart lib/screens/halve_it_game_screen.dart lib/screens/around_the_clock_game_screen.dart lib/screens/killer_game_screen.dart`
Expected: no new issues.

- [ ] **Step 7: Commit**

```bash
git add lib/widgets/clock_progress.dart lib/widgets/halve_it_scoreboard.dart lib/screens/halve_it_game_screen.dart lib/screens/around_the_clock_game_screen.dart lib/screens/killer_game_screen.dart
git commit -m "refactor(theme): current-target highlights → cs.tertiary"
```

---

## Task 5: Migrate info/warning orange → secondary

**Files:**
- Modify: `lib/screens/post_game_screen.dart:66-77` (stats-skipped notice)
- Modify: `lib/widgets/mid_game_player_sheet.dart:113`

- [ ] **Step 1: post_game_screen — stats-skipped notice**

In `lib/screens/post_game_screen.dart` around lines 60-82, the entire block uses `Colors.orange` for a soft-warning "info" notice (stats not recorded). The build method already has `cs` available (added in Task 2). Replace:

```dart
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(30),
                border: Border.all(color: Colors.orange.withAlpha(80)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Statistics not recorded (player list changed mid-game)',
                      style: TextStyle(color: Colors.orange, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
```

with:

```dart
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.secondary.withAlpha(30),
                border: Border.all(color: cs.secondary.withAlpha(80)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: cs.secondary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Statistics not recorded (player list changed mid-game)',
                      style: TextStyle(color: cs.secondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
```

(`const Row` becomes non-const because children now use runtime colors.)

- [ ] **Step 2: mid_game_player_sheet — info text**

In `lib/widgets/mid_game_player_sheet.dart` around line 113, replace:

```dart
                    style:
                        TextStyle(fontSize: 12, color: Colors.orange[300]),
```

with:

```dart
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.secondary),
```

- [ ] **Step 3: Verify**

Run: `flutter analyze lib/screens/post_game_screen.dart lib/widgets/mid_game_player_sheet.dart`
Expected: no new issues.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/post_game_screen.dart lib/widgets/mid_game_player_sheet.dart
git commit -m "refactor(theme): info/warning orange literals → cs.secondary"
```

---

## Task 6: Document palette rules in CLAUDE.md

**Files:**
- Modify: `CLAUDE.md` (replace the `## Tema` section)

- [ ] **Step 1: Replace the Tema section**

In `CLAUDE.md`, find:

```markdown
## Tema

Mørkt tema med grønn (#43A047) primær og rød (#E53935) sekundær.
```

Replace with:

```markdown
## Tema

Mørkt tema, M3 (`useMaterial3: true`). Paletten er låst til fire roller — alle nye komponenter MÅ velge fra disse:

| Rolle       | Hex       | Når                                                     |
| ----------- | --------- | ------------------------------------------------------- |
| `primary`   | `#43A047` | Primær handling, aktiv spiller, positiv endring         |
| `secondary` | `#FFA726` | Sekundær handling, finished/out, soft warning           |
| `tertiary`  | `#FFD54F` | Informasjon, achievements, checkout-tips                |
| `error`     | `#E53935` | Bust, destructive, negativ endring                      |

Bruk alltid `Theme.of(context).colorScheme.<role>` — ikke `Colors.amber` / `Colors.orange` / hex literals.

**Unntak (kun disse):**
- `lib/utils/player_colors.dart` — avatar-farger, separat palett
- `lib/widgets/heatmap_board.dart` — data-viz gradient
- D-knapper i score-input (`Colors.orange[800]` i halve_it/atc) — funksjonell input-semantikk for double
- Bronze (`Colors.brown[300]`) for 3.-plass — ikke i role-palette, kun en literal

Full spec: `docs/superpowers/specs/2026-04-30-color-design-system.md`.
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: codify four-role color palette in CLAUDE.md"
```

---

## Task 7: Build + visual verification

- [ ] **Step 1: Bump version**

In `pubspec.yaml`, change:
```yaml
version: 1.7.0+...
```
to:
```yaml
version: 1.7.0+<existing-build+1>
```

(If build number isn't already bumped from prior M3 work, increment by 1.)

In `lib/screens/home_screen.dart`, ensure the version string matches `'v1.7.0'` (should already from prior commit `385260a`).

- [ ] **Step 2: Build APK**

Run: `flutter build apk --release`
Expected: `✓ Built build/app/outputs/flutter-apk/app-release.apk`. Note the build time and any warnings.

- [ ] **Step 3: Manual visual smoke test**

Install the APK on a device and verify against the spec's state-signaling table:

- [ ] Home: primary buttons green, no double-red anywhere
- [ ] X01 in-game: active player has green border; checkout suggestion is amber/yellow; bust state is red
- [ ] Cricket / ATC / Killer / Halve It: current target highlights are amber/yellow (not orange)
- [ ] Post-game (winner): trophy + "Winner!" label amber; stats-skipped warning (if triggered) is orange
- [ ] Stats: 1st place podium number is amber, 2nd is dimmed, 3rd is bronze

If any state is wrong, add a follow-up task; do not silently re-color.

- [ ] **Step 4: Final commit (version bump only if changed)**

```bash
git add pubspec.yaml
git commit -m "chore: bump build number for v1.7.0 color system release"
```

---

## Self-review notes

Plan covers all five spec migration steps. Heatmap, avatar palette, and D-button orange are explicitly preserved per the spec's out-of-scope statement. Bronze podium color is documented in CLAUDE.md as a single-literal exception. No placeholders. Each task ends with `flutter analyze` + commit. Final task is the only one that requires a device.
