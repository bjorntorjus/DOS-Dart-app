# DOSSEDART X01 cockpit fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the X01 active player card readable, surface 3-dart average, expose sound/video/memes/TTS toggles from the in-game menu, and stop the home leaderboard hero rating from wrapping.

**Architecture:** Four small, independent edits to existing files. No new files. No changes to `ArcadeFrame`, the dartboard widget, the DOSSEDART palette, or any other game mode. The fix to the "dark cloud" is replacing one transparent gradient with a solid color — root cause was the CRT scanline overlay blending into 90 %-transparent foreground content.

**Tech Stack:** Flutter / Dart, `shared_preferences` via `AppSettings`, widget-tests using `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-05-22-dossedart-x01-cockpit-fixes-design.md`
**Mockup:** `docs/design/dossedart-handoff/PROPOSAL-x01-brightness-v2.html`

---

## File Structure

| File | Change |
| ---- | ------ |
| `lib/widgets/dossedart/x01/dossedart_x01_active_card.dart` | Solid bg, optional `avg` param, AVG cell in stats strip |
| `test/widgets/dossedart/x01/dossedart_x01_active_card_test.dart` | Tests for solid bg + AVG rendering |
| `lib/screens/game_screen.dart` | Pass `avg` into card; rewrite `_showDossedartMenu` with toggles |
| `lib/screens/dossedart/dossedart_home_screen.dart` | Widen rating column 58 → 72 (header + row) |

Each task is self-contained — they can be done in order or in parallel (active card change + home rating fix don't touch each other).

---

## Task 1: Active-card solid background

**Files:**
- Modify: `lib/widgets/dossedart/x01/dossedart_x01_active_card.dart:39-55`
- Test: `test/widgets/dossedart/x01/dossedart_x01_active_card_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `test/widgets/dossedart/x01/dossedart_x01_active_card_test.dart` (inside `main()`, after existing tests, before the closing `}`):

```dart
  testWidgets('uses solid surface background (no gradient)', (tester) async {
    await tester.pumpWidget(harness());
    // Outer card is the first Container in the widget tree with a magenta
    // border. Look it up via the BoxDecoration and assert: solid color set,
    // no gradient.
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(DossedartX01ActiveCard),
            matching: find.byType(Container),
          )
          .first,
    );
    final deco = container.decoration as BoxDecoration;
    expect(deco.gradient, isNull,
        reason: 'active card should use a solid bg, not a gradient');
    expect(deco.color, isNotNull,
        reason: 'active card should set a solid background color');
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/dossedart/x01/dossedart_x01_active_card_test.dart -p chrome --plain-name "uses solid surface background"`
(If chrome isn't set up, use the default: `flutter test test/widgets/dossedart/x01/dossedart_x01_active_card_test.dart --plain-name "uses solid surface background"`)
Expected: FAIL — `deco.gradient` is non-null and `deco.color` is null.

- [ ] **Step 3: Replace gradient with solid surface color**

In `lib/widgets/dossedart/x01/dossedart_x01_active_card.dart`, change the `decoration:` block of the outer `Container` (currently lines 42–55):

```dart
      decoration: BoxDecoration(
        color: DossedartTokens.surface,
        border: Border.all(color: accentColor, width: 3),
        boxShadow: [
          BoxShadow(color: accentColor.withValues(alpha: 0.25), blurRadius: 14),
        ],
      ),
```

(`DossedartTokens` is already imported at the top of the file.)

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/widgets/dossedart/x01/dossedart_x01_active_card_test.dart`
Expected: all tests pass (the new one plus the existing ones).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/dossedart/x01/dossedart_x01_active_card.dart test/widgets/dossedart/x01/dossedart_x01_active_card_test.dart
git commit -m "fix(dossedart-x01): active-card uses solid surface bg

The transparent magenta gradient blended into the ArcadeFrame
scanlines, producing a 'dark cloud' over the active player info.
Solid surface bg keeps the magenta border + glow but lets the
content stay readable."
```

---

## Task 2: Active-card AVG stat

**Files:**
- Modify: `lib/widgets/dossedart/x01/dossedart_x01_active_card.dart`
- Test: `test/widgets/dossedart/x01/dossedart_x01_active_card_test.dart`

- [ ] **Step 1: Write the failing tests**

Append to `test/widgets/dossedart/x01/dossedart_x01_active_card_test.dart`. Also update `harness` to accept an `avg` parameter — find the existing `harness({...})` block at the top of `main()` and change it to:

```dart
  Widget harness({
    String name = 'MIA',
    int remaining = 170,
    int currentDartIndex = 2,
    String? lastTurn = 'T20 · S20 · S20',
    int? lastTurnSum = 80,
    String? checkoutTip,
    double? avg,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: DossedartX01ActiveCard(
          playerName: name,
          avatarPath: null,
          accentColor: const Color(0xFFFF00AA),
          remaining: remaining,
          currentDartIndex: currentDartIndex,
          lastTurnLabel: lastTurn,
          lastTurnSum: lastTurnSum,
          checkoutTip: checkoutTip,
          avg: avg,
        ),
      ),
    );
  }
```

Then append these tests at the end of `main()`:

```dart
  testWidgets('shows AVG when avg is non-null', (tester) async {
    await tester.pumpWidget(harness(avg: 52.8));
    expect(find.text('AVG'), findsOneWidget);
    expect(find.text('52.8'), findsOneWidget);
  });

  testWidgets('formats AVG to 1 decimal', (tester) async {
    await tester.pumpWidget(harness(avg: 60));
    expect(find.text('60.0'), findsOneWidget);
  });

  testWidgets('hides AVG when avg is null', (tester) async {
    await tester.pumpWidget(harness(avg: null));
    expect(find.text('AVG'), findsNothing);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widgets/dossedart/x01/dossedart_x01_active_card_test.dart`
Expected: compile error (`avg` is not a named parameter of `DossedartX01ActiveCard`) — that's fine, that's our first failure signal.

- [ ] **Step 3: Add `avg` parameter and render AVG cell**

In `lib/widgets/dossedart/x01/dossedart_x01_active_card.dart`:

3a. Add the parameter. Inside the class, find the constructor (currently lines 7–17) and replace with:

```dart
  const DossedartX01ActiveCard({
    super.key,
    required this.playerName,
    required this.avatarPath,
    required this.accentColor,
    required this.remaining,
    required this.currentDartIndex,
    required this.lastTurnLabel,
    required this.lastTurnSum,
    required this.checkoutTip,
    this.avg,
  });
```

3b. Add the field. After the existing `final String? checkoutTip;` line (around line 26), add:

```dart
  final double? avg;
```

3c. Render the AVG cell. Find the "Row 3: last turn" block (currently around lines 148–197 — the `if (lastTurnLabel != null) ...[ ... ]` block) and replace its entire body with a new stats strip that holds AVG + LAST side by side:

```dart
          // Row 3: AVG + LAST (visible when there is either an avg or a last turn)
          if (lastTurnLabel != null || avg != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: accentColor.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (avg != null)
                    SizedBox(
                      width: 52,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'AVG',
                            style: TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 8,
                              color: Colors.white60,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            avg!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 14,
                              color: DossedartTokens.cyan,
                              letterSpacing: 1,
                              shadows: [
                                Shadow(
                                  color: Color(0x8000E5FF),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (lastTurnLabel != null)
                    Expanded(
                      child: Row(
                        children: [
                          const Text(
                            'LAST',
                            style: TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 9,
                              color: Colors.white70,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              lastTurnLabel!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'VT323',
                                fontSize: 20,
                                color: DossedartTokens.yellow,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          if (lastTurnSum != null)
                            Text(
                              '= $lastTurnSum',
                              style: const TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 13,
                                color: DossedartTokens.yellow,
                                letterSpacing: 1,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/widgets/dossedart/x01/dossedart_x01_active_card_test.dart`
Expected: all tests (existing + 3 new) pass.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/dossedart/x01/dossedart_x01_active_card.dart test/widgets/dossedart/x01/dossedart_x01_active_card_test.dart
git commit -m "feat(dossedart-x01): show 3-dart AVG on active card

AVG cell sits left of the LAST row, same divider above. Hidden
when avg is null (early in the game)."
```

---

## Task 3: Pass `avg` from game_screen into the active card

**Files:**
- Modify: `lib/screens/game_screen.dart` (around lines 1474–1486)

- [ ] **Step 1: Compute `avg` in the same scope as `lastLabel`/`tip`/`lastSum`**

In `lib/screens/game_screen.dart`, find the block at lines 1450–1455:

```dart
    final player = players[currentPlayerIndex];
    final lastLabel = _previousTurnLabel(currentPlayerIndex);
    final tip = _checkoutFor(player.score);

    // Last-turn sum (sum of the three throws ending the previous turn).
    final lastSum = _sumOfLastThreeBeforeCurrentTurn(currentPlayerIndex);
```

Replace it with:

```dart
    final player = players[currentPlayerIndex];
    final lastLabel = _previousTurnLabel(currentPlayerIndex);
    final tip = _checkoutFor(player.score);

    // Last-turn sum (sum of the three throws ending the previous turn).
    final lastSum = _sumOfLastThreeBeforeCurrentTurn(currentPlayerIndex);

    // 3-dart match average for the active player (null when no darts yet).
    final activeThrows = throwHistory
        .where((t) => t.playerIndex == currentPlayerIndex)
        .toList();
    final activePointsSum =
        activeThrows.fold<int>(0, (acc, t) => acc + t.segment * t.multiplier);
    final avg = activeThrows.isEmpty
        ? null
        : (activePointsSum / activeThrows.length) * 3;
```

- [ ] **Step 2: Pass `avg` into `DossedartX01ActiveCard`**

Find the existing call site (currently lines 1476–1485):

```dart
                  DossedartX01ActiveCard(
                    playerName: player.name,
                    avatarPath: player.avatarPath,
                    accentColor: DossedartTokens.magenta,
                    remaining: player.score,
                    currentDartIndex: dartsInTurn,
                    lastTurnLabel: lastLabel.isEmpty ? null : lastLabel,
                    lastTurnSum: lastSum,
                    checkoutTip: tip.isEmpty ? null : tip,
                  ),
```

Add `avg: avg,` as a new line before the closing `),`:

```dart
                  DossedartX01ActiveCard(
                    playerName: player.name,
                    avatarPath: player.avatarPath,
                    accentColor: DossedartTokens.magenta,
                    remaining: player.score,
                    currentDartIndex: dartsInTurn,
                    lastTurnLabel: lastLabel.isEmpty ? null : lastLabel,
                    lastTurnSum: lastSum,
                    checkoutTip: tip.isEmpty ? null : tip,
                    avg: avg,
                  ),
```

- [ ] **Step 3: Run a quick flutter analyze**

Run: `flutter analyze lib/screens/game_screen.dart`
Expected: no new warnings, no errors.

- [ ] **Step 4: Smoke-test the cockpit manually**

Run: `flutter run` (target your usual emulator/device).
Start an X01 game, throw at least one dart, and confirm the active-card now shows AVG to the left of LAST.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/game_screen.dart
git commit -m "feat(dossedart-x01): wire 3-dart AVG into active card

Computed inline from the active player's throw history using
the same formula already used for PlayerOverviewRow."
```

---

## Task 4: In-game menu with sound/video/memes/TTS toggles

**Files:**
- Modify: `lib/screens/game_screen.dart` (the `_showDossedartMenu` method, currently around lines 1546–1586)

- [ ] **Step 1: Add the imports if missing**

At the top of `lib/screens/game_screen.dart`, confirm the following imports exist (they should already be there, but verify):

```dart
import '../services/app_settings.dart';
import '../theme/dossedart_tokens.dart';
```

If `app_settings.dart` is not imported, add it.

- [ ] **Step 2: Replace `_showDossedartMenu` with the new sheet**

Replace the entire `_showDossedartMenu` method body with:

```dart
  void _showDossedartMenu(BuildContext outerContext) {
    showModalBottomSheet(
      context: outerContext,
      backgroundColor: DossedartTokens.surface,
      builder: (sheetCtx) {
        return SafeArea(
          child: _DossedartMenuSheet(
            onPlayerOverview: () {
              Navigator.pop(sheetCtx);
              _openPlayerOverview();
            },
            onExit: () {
              Navigator.pop(sheetCtx);
              _confirmExit();
            },
          ),
        );
      },
    );
  }
```

- [ ] **Step 3: Add the `_DossedartMenuSheet` widget**

At the bottom of `lib/screens/game_screen.dart`, after the closing `}` of the existing state class, add:

```dart
class _DossedartMenuSheet extends StatefulWidget {
  const _DossedartMenuSheet({
    required this.onPlayerOverview,
    required this.onExit,
  });

  final VoidCallback onPlayerOverview;
  final VoidCallback onExit;

  @override
  State<_DossedartMenuSheet> createState() => _DossedartMenuSheetState();
}

class _DossedartMenuSheetState extends State<_DossedartMenuSheet> {
  bool? _sound;
  bool? _video;
  bool? _memes;
  bool? _tts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await AppSettings.getSoundEffectsEnabled();
    final v = await AppSettings.getVideoEventsEnabled();
    final m = await AppSettings.getMemeEnabled();
    final t = await AppSettings.getTtsEnabled();
    if (!mounted) return;
    setState(() {
      _sound = s;
      _video = v;
      _memes = m;
      _tts = t;
    });
  }

  Future<void> _toggle({
    required bool current,
    required Future<void> Function(bool) setter,
    required void Function(bool) localApply,
  }) async {
    final next = !current;
    localApply(next);
    setState(() {});
    await setter(next);
  }

  @override
  Widget build(BuildContext context) {
    if (_sound == null || _video == null || _memes == null || _tts == null) {
      return const SizedBox(
        height: 240,
        child: Center(
          child: CircularProgressIndicator(color: DossedartTokens.cyan),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: 8, bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        _ToggleRow(
          icon: Icons.volume_up,
          label: 'SOUND',
          value: _sound!,
          onChanged: () => _toggle(
            current: _sound!,
            setter: AppSettings.setSoundEffectsEnabled,
            localApply: (v) => _sound = v,
          ),
        ),
        _ToggleRow(
          icon: Icons.movie,
          label: 'VIDEO EVENTS',
          value: _video!,
          onChanged: () => _toggle(
            current: _video!,
            setter: AppSettings.setVideoEventsEnabled,
            localApply: (v) => _video = v,
          ),
        ),
        _ToggleRow(
          icon: Icons.emoji_emotions,
          label: 'MEMES',
          value: _memes!,
          onChanged: () => _toggle(
            current: _memes!,
            setter: AppSettings.setMemeEnabled,
            localApply: (v) => _memes = v,
          ),
        ),
        _ToggleRow(
          icon: Icons.record_voice_over,
          label: 'VOICE (TTS)',
          value: _tts!,
          onChanged: () => _toggle(
            current: _tts!,
            setter: AppSettings.setTtsEnabled,
            localApply: (v) => _tts = v,
          ),
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.fromLTRB(18, 4, 18, 4),
          color: Colors.white.withValues(alpha: 0.08),
        ),
        _ActionRow(
          icon: Icons.scoreboard,
          iconColor: DossedartTokens.cyan,
          label: 'PLAYER OVERVIEW',
          labelColor: Colors.white,
          onTap: widget.onPlayerOverview,
        ),
        _ActionRow(
          icon: Icons.exit_to_app,
          iconColor: DossedartTokens.red,
          label: 'EXIT MATCH',
          labelColor: DossedartTokens.red,
          onTap: widget.onExit,
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Icon(icon, color: DossedartTokens.cyan, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 11,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            _Pill(on: value),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 22,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: on
              ? DossedartTokens.green
              : Colors.white.withValues(alpha: 0.25),
          width: 2,
        ),
        color: on
            ? DossedartTokens.green.withValues(alpha: 0.18)
            : Colors.transparent,
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            left: on ? null : 2,
            right: on ? 2 : null,
            top: 2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on
                    ? DossedartTokens.green
                    : Colors.white.withValues(alpha: 0.5),
                boxShadow: on
                    ? [
                        BoxShadow(
                          color: DossedartTokens.green
                              .withValues(alpha: 0.8),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final Color labelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 11,
                  color: labelColor,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                color: labelColor.withValues(alpha: 0.6), size: 18),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run flutter analyze**

Run: `flutter analyze lib/screens/game_screen.dart`
Expected: no new warnings, no errors. (If there is a "private types in public API" warning on `_DossedartMenuSheet`, that's fine — these private widgets are intentionally only used in this file.)

- [ ] **Step 5: Manual smoke test**

Run the app, open an X01 game, tap ⋯ MENU. Confirm:
- All four toggles render with current persisted state
- Tapping a toggle flips it visually, sheet stays open
- Close sheet, re-open sheet — toggle states are still what you set them to
- Tapping PLAYER OVERVIEW opens the existing overview screen
- Tapping EXIT MATCH triggers the existing exit-confirm dialog

- [ ] **Step 6: Commit**

```bash
git add lib/screens/game_screen.dart
git commit -m "feat(dossedart-x01): in-game menu with sound/video/memes/TTS toggles

Pill-style toggles persist via AppSettings. Sheet stays open after
a toggle; only PLAYER OVERVIEW and EXIT MATCH dismiss it."
```

---

## Task 5: Home — widen rating column so hero rating fits one line

**Files:**
- Modify: `lib/screens/dossedart/dossedart_home_screen.dart` (around lines 191–196 and 279–287)

- [ ] **Step 1: Change the header column width**

In `_buildLeaderboard`, find the column header for RATING (currently lines 191–196):

```dart
                SizedBox(
                  width: 58,
                  child: Text('RATING',
                      textAlign: TextAlign.right,
                      style: _vt(12, color: Colors.white60, letterSpacing: 1.5)),
                ),
```

Change `width: 58` to `width: 72`.

- [ ] **Step 2: Change the row cell width**

In `_leaderboardRow`, find the rating cell (currently lines 279–287):

```dart
          SizedBox(
            width: 58,
            child: Text(
              player.rating.toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: _press(hero ? 14 : 11,
                  color: accent, letterSpacing: 0.5),
            ),
          ),
```

Change `width: 58` to `width: 72`. Leave font and letterSpacing unchanged.

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze lib/screens/dossedart/dossedart_home_screen.dart`
Expected: no warnings, no errors.

- [ ] **Step 4: Manual smoke test**

Run the app. On the home screen, confirm the 1st-place rating (4 digits) renders on a single line. The PLAYER name column gets 14 px less width; long names ellipsise slightly sooner — verify nothing else regresses.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/dossedart/dossedart_home_screen.dart
git commit -m "fix(dossedart-home): rating column 58→72 to stop hero wrap

Hero row uses PressStart2P at 14pt; a 4-digit rating overflowed
the 58px cell and wrapped to two lines. Widening the column to
72px restores single-line rendering. PLAYER column absorbs the
loss via its existing Expanded + ellipsis."
```

---

## Task 6: Final verification

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: all tests pass. If any unrelated test breaks, stop and investigate before continuing.

- [ ] **Step 2: Build a debug APK and sanity-check on device**

Run: `flutter build apk --debug`
Install and:
- Confirm the X01 cockpit no longer has a "dark cloud" over the active card.
- Throw a dart, confirm AVG appears.
- Open the in-game menu, toggle each setting, confirm changes persist after closing/reopening the sheet.
- On the home screen, confirm the 1st-place rating stays on one line.

- [ ] **Step 3: Update version + release build (optional, only when ready to ship)**

Bump `pubspec.yaml` version (e.g., `1.8.0+15` → `1.8.1+16`) and the version string in `lib/screens/home_screen.dart` and `lib/screens/dossedart/dossedart_home_screen.dart`. Run `flutter build apk --release`. Commit version bump separately.
