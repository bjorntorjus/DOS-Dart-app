# Audit Round 4 — Consistency Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the six consistency findings from the 2026-07-06 audit — F15 (sound toggle disables memes), F16 (Shanghai bypasses GameAnnouncer + racy TTS reads), F21 (Norwegian UI text), F22 (palette drift on both design tracks), F23 (outline drift), F24 (Halve It remnant on the DOSSEDART home).

**Architecture:** All fixes are in-place consistency repairs — no new subsystems. The classic and DOSSEDART design tracks stay separate (Bjørn's decision 2026-07-06): classic literals migrate to `Theme.of(context).colorScheme` roles, arcade raw hex migrates to `DossedartTokens`. Two new source-scan guard tests (`test/design/`) lock the language rule and the classic color contract against regression.

**Tech Stack:** Flutter (Dart), flutter_test with platform-channel stubs (`flutter_tts`, battery), SharedPreferences mock values, `dart:io` source-scan tests.

## Global Constraints

- Branch: `fix/dossedart-x01-cockpit-fixes` (release train). Commit per task, **do not push** — CI runs when Bjørn says so.
- UI text: **English** (CLAUDE.md rule; Bjørn confirmed 2026-07-06). Code comments: English.
- Classic palette: only the four roles via `Theme.of(context).colorScheme.<role>` — primary `#43A047`, secondary `#FFA726`, tertiary `#FFD54F`, error `#E53935`.
- Arcade palette: only `DossedartTokens.*` (file `lib/theme/dossedart_tokens.dart`).
- Documented palette exceptions (do not "fix"): `lib/utils/player_colors.dart`, `lib/widgets/heatmap_board.dart`, D-buttons `Colors.orange[800]` in halve_it/atc score input, bronze `Colors.brown[300]`, both dartboard painters (`dart_board.dart`, `dossedart_x01_dartboard.dart`).
- Dead widgets `lib/widgets/{checkout_widget,clock_progress,cricket_scoreboard,halve_it_scoreboard}.dart` are deleted in Round 5 (F25) — do NOT edit them; allowlist them in guard tests.
- Outline rule: element outlines 1px `cs.outline`; inner dividers 2px; active state 2px.
- Never call `pumpAndSettle` after a game-over path in widget tests — `VideoService` pushes a perpetual-spinner overlay (audit F18, fixed in Round 5). Use `pump()` or avoid ending games.
- `flutter analyze` must report 0 issues after every task.
- End every commit message with: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
- TTS spoken strings are already English — F21 does NOT touch anything passed to `TtsService.speak`/`GameAnnouncer`.

## Decisions baked into this plan (flag to Bjørn if he objects)

1. Mode emoji unify to the DOSSEDART set in BOTH homes: Killer 🔪, Splitscore ✂️, Shanghai 🐉 (classic home changes from 💀/➗/🌃).
2. All six classic AppBar menus become identical: Manage players / Sound / TTS / Memes / (Meme frequency, Offensive when memes on). X01's "Sound settings" dialog is replaced by the standard items.
3. Killer's blue shields → `cs.tertiary` (info role); lives hearts → `cs.error`. Podium: gold → `cs.tertiary`, silver stays `Color(0xFFC0C0C0)` (new documented exception), bronze normalizes to `Colors.brown[300]`.
4. Rating-history chart line → `cs.primary`.
5. Current-round chips (halve_it/shanghai, tertiary 1.5px) are treated as active-state → 2px. Active-player ring default 3px → 2px per spec.
6. DOSSEDART subtle magenta dividers standardize to `magenta @ alpha 0.4, 1px` (major chrome stays full magenta 2px).
7. Deferred (out of scope): the shared DOSSEDART cockpit menu exposes no offensive-sounds toggle in any mode. That is consistent within the arcade track today; adding the row to `DossedartMenuSheet` is a design change for a later round.

---

### Task 1: F24 — Home-grid parity (label + emoji from GameMode)

**Files:**
- Modify: `lib/models/game_mode.dart`
- Modify: `lib/screens/dossedart/dossedart_home_screen.dart:358-364` (+ tile usages ~379/383)
- Modify: `lib/screens/home_screen.dart:305-311` (+ `_modeButton` usage ~359)
- Test: `test/models/game_mode_emoji_test.dart` (create)

**Interfaces:**
- Consumes: existing `GameModeLabel.label` extension.
- Produces: `extension GameModeEmoji on GameMode { String get emoji; }` — later tasks and both home screens rely on `mode.label` / `mode.emoji`.

- [ ] **Step 1: Write the failing test**

```dart
// test/models/game_mode_emoji_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/game_mode.dart';

void main() {
  test('every mode has one canonical emoji (DOSSEDART set)', () {
    expect(GameMode.cricket.emoji, '🎯');
    expect(GameMode.aroundTheClock.emoji, '🕐');
    expect(GameMode.killer.emoji, '🔪');
    expect(GameMode.halveIt.emoji, '✂️');
    expect(GameMode.shanghai.emoji, '🐉');
    expect(GameMode.x01.emoji, '💯');
  });

  test('halveIt label is Splitscore (F24 regression)', () {
    expect(GameMode.halveIt.label, 'Splitscore');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/game_mode_emoji_test.dart`
Expected: FAIL — `emoji` getter is not defined.

- [ ] **Step 3: Implement**

Append to `lib/models/game_mode.dart`:

```dart
extension GameModeEmoji on GameMode {
  String get emoji {
    switch (this) {
      case GameMode.x01:
        return '💯';
      case GameMode.cricket:
        return '🎯';
      case GameMode.aroundTheClock:
        return '🕐';
      case GameMode.killer:
        return '🔪';
      case GameMode.halveIt:
        return '✂️';
      case GameMode.shanghai:
        return '🐉';
    }
  }
}
```

In `dossedart_home_screen.dart` replace the record list with plain modes and derive text from the extension:

```dart
    final modes = const [
      GameMode.cricket,
      GameMode.aroundTheClock,
      GameMode.killer,
      GameMode.halveIt,
      GameMode.shanghai,
    ];
```

Update the `_modeCell(...)` call sites (~lines 379/383) from destructured `(mode, label, emoji)` records to `mode`, `mode.label`, `mode.emoji`.

In `home_screen.dart` replace the `(GameMode, emoji)` record list the same way and use `mode.emoji` where the literal was read; the label already uses `mode.label`.

- [ ] **Step 4: Verify**

Run: `flutter test test/models/game_mode_emoji_test.dart` → PASS.
Run: `flutter analyze` → 0 issues.
Run: `grep -rn "Halve It" lib/` → only code/doc comments remain (player_setup_screen.dart:68, halve_it_game_screen.dart:517, saved_player.dart:10).

- [ ] **Step 5: Commit**

```bash
git add lib/models/game_mode.dart lib/screens/home_screen.dart lib/screens/dossedart/dossedart_home_screen.dart test/models/game_mode_emoji_test.dart
git commit -m "fix(home): derive mode label+emoji from GameMode — kills the 'Halve It' remnant (F24)"
```

---

### Task 2: F21a — Translate KAMPDETALJER + arcade stats surfaces

**Files:**
- Modify: `lib/screens/dossedart/game_detail_screen.dart`
- Modify: `lib/screens/dossedart/dossedart_stats_screen.dart`
- Modify: `lib/stats/profile_stats.dart`
- Modify: `lib/widgets/dossedart/stats/prestasjoner_section.dart`
- Test: `test/screens/game_detail_screen_test.dart`, `test/screens/dossedart_stats_screen_test.dart`, `test/stats/profile_stats_records_test.dart` (update finders)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: English UI strings that Task 4's guard test and existing tests assert on. Note `game_detail_screen.dart` compares a label internally: the `'VINNER'` literal appears both as data (L214) and in a comparison (L262 `label == 'VINNER'`) — both become `'WINNER'`.

- [ ] **Step 1: Update tests first (failing)**

In `test/screens/game_detail_screen_test.dart` replace finders:
`'KAMPDETALJER'`→`'MATCH DETAILS'`, `'PRESTASJONER DENNE KAMPEN'`→`'ACHIEVEMENTS THIS MATCH'`, `'SPILLFORLØP'`→`'MATCH FLOW'`, `'RUNDE FOR RUNDE'`→`'ROUND BY ROUND'` (2×), `'PER SPILLER'`→`'PER PLAYER'` (2×), `'Forløp ikke lagret for denne kampen'`→`'Play-by-play not saved for this match'`, `'SLUTTSTILLING'`→`'FINAL STANDINGS'`.

In `test/screens/dossedart_stats_screen_test.dart`: `'HISTORIKK'`→`'HISTORY'` (2×), `'PRESTASJONER'`→`'ACHIEVEMENTS'`, `'DETALJER ›'`→`'DETAILS ›'`, `'KAMPDETALJER'`→`'MATCH DETAILS'`, `textContaining('4 kamper')`→`textContaining('4 games')`, `'høyeste runde'`→`'highest turn'`.

In `test/stats/profile_stats_records_test.dart`: `byLabel['treff-rate']`→`byLabel['hit rate']`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/game_detail_screen_test.dart test/screens/dossedart_stats_screen_test.dart test/stats/profile_stats_records_test.dart`
Expected: FAIL — English strings not found.

- [ ] **Step 3: Translate the source strings**

`lib/screens/dossedart/game_detail_screen.dart` (line refs are pre-edit):

| Line | Norwegian | English |
|---|---|---|
| 46 | `'SLUTTSTILLING'` | `'FINAL STANDINGS'` |
| 50-51 | `'SPILLFORLØP'` / right `'kappløpet'` | `'MATCH FLOW'` / `'the race'` |
| 56 | `'Forløp ikke lagret for denne kampen'` | `'Play-by-play not saved for this match'` |
| 64 | `'PER SPILLER'` / right `'side om side'` | `'PER PLAYER'` / `'side by side'` |
| 68-70 | `'PRESTASJONER DENNE KAMPEN'` / right `'hva hver spiller oppnådde'` | `'ACHIEVEMENTS THIS MATCH'` / `'what each player achieved'` |
| 75-76 | `'RUNDE FOR RUNDE'` / right `'pil for pil'` | `'ROUND BY ROUND'` / `'dart by dart'` |
| 140 | `'◀ HISTORIKK'` | `'◀ HISTORY'` |
| 150 | `'KAMPDETALJER'` | `'MATCH DETAILS'` |
| 212 | `'VARIGHET'` | `'DURATION'` |
| 213 | `'RUNDER'` | `'ROUNDS'` |
| 214 + 262 | `'VINNER'` (data + `label == 'VINNER'`) | `'WINNER'` (both sides) |
| 292 | `'Vant'` / `'$darts piler'` / `'Fullførte'` | `'Won'` / `'$darts darts'` / `'Finished'` |
| 442 | `'NY'` | `'NEW'` |
| 537 | `'Graf utilgjengelig for denne modusen'` | `'Graph unavailable for this mode'` |
| 731 | `'3-PILERS SNITT'` | `'3-DART AVERAGE'` |
| 733 | `'BESTE RUNDE'` | `'BEST TURN'` |
| 737 | `'DOBLER'` | `'DOUBLES'` |
| 739 | `'PILER KASTET'` | `'DARTS THROWN'` |
| 777 | `'STATISTIKK'` | `'STATISTICS'` |
| 937 | `'VIS ALLE ${rounds.length} RUNDER ›'` | `'SHOW ALL ${rounds.length} ROUNDS ›'` |
| 1033 | `'$remaining igjen'` | `'$remaining left'` |

`lib/screens/dossedart/dossedart_stats_screen.dart`:

| Line | Norwegian | English |
|---|---|---|
| 116 | `['PROFIL', 'MODUS', 'HEATMAP', 'HISTORIKK']` | `['PROFILE', 'MODES', 'HEATMAP', 'HISTORY']` |
| 167 | `'STREAKS & TOPP'` | `'STREAKS & TOP'` |
| 170 | `'REKORDER'` | `'RECORDS'` |
| 255, 270 | `'snitt $avg'` | `'avg $avg'` |
| 265 | `'treff $rate%'` | `'hits $rate%'` |
| 272 | `'halvering ${…}'` | `'halving ${…}'` |
| 562 | `'NÅ PÅ RAD'` | `'CURRENT STREAK'` |
| 563 | `'${player.currentLossStreak} tap'` | `'${player.currentLossStreak} losses'` |
| 566 | `'BESTE STREAK'` | `'BEST STREAK'` |
| 567 | `'RATING-TOPP'` | `'PEAK RATING'` |
| 568 | `'BESTE RANK'` | `'BEST RANK'` |
| 812 | `'· ${player.gamesPlayed} kamper · siden ${…}'` | `'· ${player.gamesPlayed} games · since ${…}'` |
| 956 | `'DETALJER ›'` | `'DETAILS ›'` |
| 1072-1076 | `_months` `['jan','feb','mar','apr','mai','jun','jul','aug','sep','okt','nov','des']` | `['jan','feb','mar','apr','may','jun','jul','aug','sep','oct','nov','dec']` |

`lib/stats/profile_stats.dart` `RecordTile` labels: `'høyeste runde'`→`'highest turn'`, `'beste checkout'`→`'best checkout'`, `'beste poeng'`→`'best points'`, `'beste score'`→`'best score'`, `'største halvering'`→`'biggest halving'`, `'kills totalt'`→`'total kills'`, `'treff-rate'`→`'hit rate'` (lines 64-88).

`lib/widgets/dossedart/stats/prestasjoner_section.dart:51`: `'PRESTASJONER'` → `'ACHIEVEMENTS'` (the file/class name stays — identifier, Round-5 concern if ever).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/game_detail_screen_test.dart test/screens/dossedart_stats_screen_test.dart test/stats/profile_stats_records_test.dart`
Expected: PASS. Also `flutter analyze` → 0 issues.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/dossedart/game_detail_screen.dart lib/screens/dossedart/dossedart_stats_screen.dart lib/stats/profile_stats.dart lib/widgets/dossedart/stats/prestasjoner_section.dart test/screens/game_detail_screen_test.dart test/screens/dossedart_stats_screen_test.dart test/stats/profile_stats_records_test.dart
git commit -m "fix(i18n): translate match-details and arcade stats surfaces to English (F21)"
```

---

### Task 3: F21b — Translate the Splitscore/Killer/Shanghai cockpits

**Files:**
- Modify: `lib/screens/halve_it_game_screen.dart` (cockpit strings)
- Modify: `lib/screens/killer_game_screen.dart` (assignment view)
- Modify: `lib/screens/shanghai_game_screen.dart` (banner/chase cell)

**Interfaces:**
- Consumes: nothing.
- Produces: English cockpit strings. Existing cockpit tests assert on symbols/English (`↶ UNDO`, `✗ MISS`) and keep passing.

- [ ] **Step 1: Translate (line refs pre-edit)**

`halve_it_game_screen.dart`: L705 `'MÅL'`→`'TARGET'`; L762 `'✓ SIKRET · +$turnPoints DENNE RUNDEN'`→`'✓ SECURED · +$turnPoints THIS ROUND'`; L763 `'⚠ TREFF ${round.label.toUpperCase()} ELLER HALVÉR · $total → ${total ~/ 2}'`→`'⚠ HIT ${round.label.toUpperCase()} OR HALVE · $total → ${total ~/ 2}'`; L833 `'RUNDE'`→`'ROUND'`. (`'SUM'` stays.)

`killer_game_screen.dart`: L1083 `'KILLER · TILDELING'`→`'KILLER · ASSIGNMENT'`; L1085 `'SPILLER ${assignmentPlayerIndex + 1}/${players.length}'`→`'PLAYER ${assignmentPlayerIndex + 1}/${players.length}'`; L1113 `'▶ ${claimer.name.toUpperCase()} — KAST FOR Å VELGE DITT TALL'`→`'▶ ${claimer.name.toUpperCase()} — THROW TO PICK YOUR NUMBER'`; L1151 `'VELGER…'`→`'PICKING…'`; L1152 `'VENTER'`→`'WAITING'`.

`shanghai_game_screen.dart`: L830 `'TREFF T$target FOR DIREKTE SEIER!'`→`'HIT T$target FOR INSTANT WIN!'`; L831 `'S + D + T I ÉN TUR = DIREKTE SEIER'`→`'S + D + T IN ONE TURN = INSTANT WIN'`; L917 `'✓ TRUFFET'`→`'✓ HIT'`. (`'TOTAL'` stays.)

- [ ] **Step 2: Verify**

Run: `flutter analyze` → 0 issues.
Run: `flutter test test/screens/` → all pass (cockpit tests unaffected).

- [ ] **Step 3: Commit**

```bash
git add lib/screens/halve_it_game_screen.dart lib/screens/killer_game_screen.dart lib/screens/shanghai_game_screen.dart
git commit -m "fix(i18n): translate Splitscore/Killer/Shanghai cockpit strings to English (F21)"
```

---

### Task 4: F21c — Norwegian-text guard test + comment sweep

**Files:**
- Test: `test/design/no_norwegian_ui_text_test.dart` (create)
- Modify (comments only): `lib/screens/dossedart/game_detail_screen.dart`, `lib/screens/dossedart/dossedart_stats_screen.dart`, `lib/widgets/dossedart/dossedart_player_sheet.dart`, `lib/stats/profile_stats.dart`, `lib/stats/game_detail_stats.dart`, `lib/stats/mode_progression.dart`, `lib/utils/earned_feats_builder.dart`, `lib/services/achievement_service.dart`

**Interfaces:**
- Consumes: Tasks 2-3 translations (guard goes green only after them).
- Produces: a permanent regression guard scanning `lib/` string literals for æ/ø/å.

- [ ] **Step 1: Write the guard test**

```dart
// test/design/no_norwegian_ui_text_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// F21 (audit 2026-07-06): UI text must be English. This scans every string
/// literal in lib/ for Norwegian characters. Comments are stripped first —
/// they must be English too, but only literals can reach the screen.
void main() {
  test('no Norwegian characters in lib/ string literals', () {
    final nordicInString = RegExp("['\"][^'\"\\n]*[æøåÆØÅ][^'\"\\n]*['\"]");
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first; // strip line comments
        if (nordicInString.hasMatch(code)) {
          offenders.add('${f.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'UI text must be English (F21):\n${offenders.join('\n')}');
  });
}
```

- [ ] **Step 2: Run it**

Run: `flutter test test/design/no_norwegian_ui_text_test.dart`
Expected: PASS if Tasks 2-3 caught everything; if it FAILS, translate each reported literal (same style as Tasks 2-3) until green. Do not allowlist anything.

- [ ] **Step 3: Translate the known Norwegian comments to English**

The 8 files above contain Norwegian design-term comments (agent-verified): `game_detail_screen.dart` L13-18 + L159, `dossedart_stats_screen.dart` L26 + section banners L143/315/353/387, `dossedart_player_sheet.dart` L27, `profile_stats.dart` L46 (update example to `// e.g. 'highest turn'`), `game_detail_stats.dart` L3, `mode_progression.dart` L3, `earned_feats_builder.dart` L6, `achievement_service.dart` L70. Keep the artboard names as proper nouns where they aid traceability, e.g. `// KAMPDETALJER artboard: "MATCH DETAILS" drill-down` — the rule is English sentences, not erasing design references.

- [ ] **Step 4: Verify + commit**

Run: `flutter analyze` → 0 issues; `flutter test test/design/` → PASS.

```bash
git add test/design/no_norwegian_ui_text_test.dart lib/
git commit -m "test(i18n): guard against Norwegian UI strings + translate stray comments (F21)"
```

---

### Task 5: F15 — Decouple sound from memes; identical classic menus in all six modes

**Files:**
- Modify: `lib/screens/game_screen.dart` (initState ~214-219, `_onMiss` ~1140-1152, menu ~1672-1741, delete `_showSoundSettingsDialog` ~2050-2127)
- Modify: `lib/screens/cricket_game_screen.dart`, `lib/screens/around_the_clock_game_screen.dart`, `lib/screens/killer_game_screen.dart`, `lib/screens/halve_it_game_screen.dart`, `lib/screens/shanghai_game_screen.dart` (add sound item)
- Test: `test/screens/classic_menu_audio_test.dart` (create)

**Interfaces:**
- Consumes: `AppSettings.{get,set}SoundEffectsEnabled`, `{get,set}MemeEnabled`, `{get,set}MemeOffensive`, `SoundService.instance.setEnabled`, `MemeService` (`_meme`).
- Produces: every classic menu handles values `'players' | 'sound' | 'tts' | 'meme' | 'meme_freq' | 'offensive'` with identical item labels: `Sound on/off` (volume icons), `TTS on/off`, `Memes on/off` (🤡/🤐), `Meme frequency`, `Offensive on/off`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/screens/classic_menu_audio_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/screens/game_screen.dart';
import 'package:dart_scoring/services/tts_service.dart';

/// F15 (audit 2026-07-06): X01's classic "Sound" toggle used to write BOTH
/// sound_effects_enabled and meme_enabled. Sound and memes are independent.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ttsChannel = MethodChannel('flutter_tts');
  const batteryChannel =
      MethodChannel('dev.fluttercommunity.plus/battery/method');

  setUp(() {
    SharedPreferences.setMockInitialValues(
        {'sound_effects_enabled': true, 'meme_enabled': true});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async {
      if (call.method == 'getVoices' || call.method == 'getLanguages') {
        return <dynamic>[];
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(batteryChannel, (call) async {
      if (call.method == 'getBatteryLevel') return 100;
      if (call.method == 'getBatteryState') return 'full';
      return null;
    });
    TtsService.instance.resetForTesting();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(batteryChannel, null);
    TtsService.instance.resetForTesting();
  });

  Future<void> pumpX01(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        players: [Player(name: 'P0', score: 501), Player(name: 'P1', score: 501)],
        startingScore: 501,
        masterOut: 'double',
        handicap: false,
        noBust: false,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('X01 sound toggle leaves meme setting untouched', (tester) async {
    await pumpX01(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sound on'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('sound_effects_enabled'), isFalse);
    expect(prefs.getBool('meme_enabled'), isTrue,
        reason: 'F15: the sound toggle must not silently disable memes');
  });

  testWidgets('X01 classic menu exposes the standard meme items', (tester) async {
    await pumpX01(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Memes on'), findsOneWidget);
    expect(find.text('Meme frequency'), findsOneWidget);
    expect(find.text('Offensive off'), findsOneWidget);
  });
}
```

Add a third `testWidgets` for menu parity in one non-X01 mode: pump `CricketGameScreen` exactly the way `test/screens/midgame_roster_rules_test.dart` pumps it (copy that file's cricket pump verbatim — players + config), open the popup, and assert `find.text('Sound on')` finds one widget; tap it and assert `prefs.getBool('sound_effects_enabled')` is false and `'meme_enabled'` still true.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/screens/classic_menu_audio_test.dart`
Expected: FAIL — after tapping 'Sound on', `meme_enabled` is false (X01 test 1); 'Memes on' not found (test 2); 'Sound on' not found in cricket (test 3).

- [ ] **Step 3: Fix X01 (`game_screen.dart`)**

3a. Add state fields next to `_soundEnabled` (if `_memeEnabled` doesn't exist yet — `_offensiveEnabled` already exists for the old dialog):

```dart
  bool _memeEnabled = false;
```

3b. initState (~214-219) — decouple:

```dart
    AppSettings.getSoundEffectsEnabled().then((v) {
      setState(() => _soundEnabled = v);
      SoundService.instance.setEnabled(v);
    });
    AppSettings.getMemeEnabled().then((v) {
      setState(() => _memeEnabled = v);
      _meme.setEnabled(v);
    });
```

(Keep the existing `getMemeOffensive` load; add it if missing:
`AppSettings.getMemeOffensive().then((v) => setState(() => _offensiveEnabled = v));`)

3c. `_onMiss` (~1142): change `if (_soundEnabled) {` → `if (_memeEnabled) {`.

3d. Menu `onSelected` — 'sound' writes only sound; add the three standard cases (copy semantics from cricket 1128-1140):

```dart
                case 'sound':
                  setState(() => _soundEnabled = !_soundEnabled);
                  SoundService.instance.setEnabled(_soundEnabled);
                  AppSettings.setSoundEffectsEnabled(_soundEnabled);
                  break;
                case 'tts':
                  await TtsService.instance.setEnabled(!_ttsEnabled);
                  setState(() => _ttsEnabled = TtsService.instance.enabled);
                  break;
                case 'meme':
                  setState(() => _memeEnabled = !_memeEnabled);
                  AppSettings.setMemeEnabled(_memeEnabled);
                  _meme.setEnabled(_memeEnabled);
                  break;
                case 'meme_freq':
                  _showMemeFrequencyDialog();
                  break;
                case 'offensive':
                  setState(() => _offensiveEnabled = !_offensiveEnabled);
                  AppSettings.setMemeOffensive(_offensiveEnabled);
                  _meme.setOffensive(_offensiveEnabled);
                  break;
```

(Make `onSelected` `async` like cricket's. The `'sound_settings'` case and item go away.)

3e. `itemBuilder`: sound item switches to volume icons; append the cricket-style meme block (cricket 1166-1202 verbatim, 🤡/🤐 moves to the meme item):

```dart
              PopupMenuItem(
                value: 'sound',
                child: Row(
                  children: [
                    Icon(_soundEnabled ? Icons.volume_up : Icons.volume_off),
                    const SizedBox(width: 12),
                    Text(_soundEnabled ? 'Sound on' : 'Sound off'),
                  ],
                ),
              ),
```

3f. Delete `_showSoundSettingsDialog` (~2050-2127) and copy `_showMemeFrequencyDialog` from `cricket_game_screen.dart` verbatim into `game_screen.dart`.

- [ ] **Step 4: Add the sound item to the other five modes**

In each of cricket/atc/killer/halve_it/shanghai game screens:

Field: `bool _soundEnabled = true;`

initState:
```dart
    AppSettings.getSoundEffectsEnabled().then((v) {
      if (mounted) setState(() => _soundEnabled = v);
      SoundService.instance.setEnabled(v);
    });
```

`onSelected` — add before `case 'tts'`:
```dart
                case 'sound':
                  setState(() => _soundEnabled = !_soundEnabled);
                  SoundService.instance.setEnabled(_soundEnabled);
                  AppSettings.setSoundEffectsEnabled(_soundEnabled);
                  break;
```

`itemBuilder` — insert the sound item (Step 3e block) directly after the `PopupMenuDivider`, before the TTS item. Also unify the TTS item icon to `Icons.mic`/`Icons.mic_off` in all six modes (cricket/others currently use volume icons for TTS, which now collide with the sound item).

- [ ] **Step 5: Verify + commit**

Run: `flutter test test/screens/classic_menu_audio_test.dart` → PASS.
Run: `flutter test test/screens/` and `flutter analyze` → green / 0 issues.

```bash
git add lib/screens/ test/screens/classic_menu_audio_test.dart
git commit -m "fix(audio): decouple sound from memes and make all six classic menus identical (F15)"
```

---

### Task 6: F16a — GameAnnouncer unit tests (per-category gating)

**Files:**
- Test: `test/services/game_announcer_test.dart` (create)

**Interfaces:**
- Consumes: `GameAnnouncer` public API as-is (`init`, `announceNextPlayer`, `announceThrow`, `announceWinner`, `announceGameEvent`, `stop`).
- Produces: the channel-stub pattern Task 7's widget test reuses (record `speak` calls into a list).

- [ ] **Step 1: Write the tests**

```dart
// test/services/game_announcer_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/services/game_announcer.dart';
import 'package:dart_scoring/services/tts_service.dart';

/// F16 (audit 2026-07-06): the per-category TTS settings must gate every
/// announcement path. GameAnnouncer had zero tests before this file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ttsChannel = MethodChannel('flutter_tts');
  final spoken = <String>[];

  setUp(() {
    spoken.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async {
      if (call.method == 'speak') spoken.add(call.arguments as String);
      if (call.method == 'getVoices' || call.method == 'getLanguages') {
        return <dynamic>[];
      }
      return 1;
    });
    TtsService.instance.resetForTesting();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
    TtsService.instance.resetForTesting();
  });

  Future<GameAnnouncer> makeAnnouncer(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues({'tts_enabled': true, ...prefs});
    final announcer = GameAnnouncer();
    await announcer.init();
    return announcer;
  }

  test('announceNextPlayer speaks when the category is on', () async {
    final a = await makeAnnouncer({});
    a.announceNextPlayer('Alice');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(spoken, contains('Alice'));
  });

  test('announceNextPlayer is silent when the category is off', () async {
    final a = await makeAnnouncer({'tts_announce_next_player': false});
    a.announceNextPlayer('Alice');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(spoken, isEmpty);
  });

  test('announceThrow respects tts_announce_throw_result', () async {
    final a = await makeAnnouncer({'tts_announce_throw_result': false});
    a.announceThrow('triple 20');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(spoken, isEmpty);
  });

  test('announceWinner speaks "<name> wins!" when winner category is on', () async {
    final a = await makeAnnouncer({});
    a.announceWinner('Alice');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(spoken, contains('Alice wins!'));
  });

  test('announceGameEvent respects tts_announce_game_events', () async {
    final a = await makeAnnouncer({'tts_announce_game_events': false});
    a.announceGameEvent('Instant Shanghai!');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(spoken, isEmpty);
  });
}
```

Note: `GameAnnouncer.init()` also inits `SoundService` (audioplayers) and `VideoService`. X01's widget tests already run `_announcer.init()` without stubbing those — they degrade gracefully in the test env. If `init()` still throws here, stub the failing channel the same way as `flutter_tts` rather than changing production code.

- [ ] **Step 2: Run**

Run: `flutter test test/services/game_announcer_test.dart`
Expected: PASS (this task documents current behavior; it is the safety net for Task 7). If a test fails, that is a real F16 bug in `GameAnnouncer` — fix `GameAnnouncer` minimally until green.

- [ ] **Step 3: Commit**

```bash
git add test/services/game_announcer_test.dart
git commit -m "test(audio): lock GameAnnouncer per-category gating (F16 groundwork)"
```

---

### Task 7: F16b — Wire GameAnnouncer into Shanghai + race-free TTS reads everywhere

**Files:**
- Modify: `lib/screens/shanghai_game_screen.dart` (imports, initState ~122-131, `_onHit` ~218-241, `_onGameEnd` ~243-258, `_fireWinnerCelebration` ~304-312, menu 'tts' case stays)
- Modify: `lib/screens/cricket_game_screen.dart:95`, `lib/screens/around_the_clock_game_screen.dart:215`, `lib/screens/killer_game_screen.dart:206`, `lib/screens/halve_it_game_screen.dart:139`, `lib/screens/game_screen.dart:219` (TTS-read pattern)
- Test: `test/screens/shanghai_announcer_test.dart` (create)

**Interfaces:**
- Consumes: `GameAnnouncer` API (Task 6), Shanghai's `onHitForTest` hook, `ShanghaiConfig(targetEnd:)`, `HitType` from `lib/models/shanghai_engine.dart`.
- Produces: Shanghai announces next player / throws / winner through `GameAnnouncer` like the other five modes; all six modes read TTS-enabled with the race-free pattern (`init().then(...)` — the invariant from `tts_service_init_test.dart`).

- [ ] **Step 1: Write the failing widget test**

```dart
// test/screens/shanghai_announcer_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/shanghai_engine.dart' show HitType;
import 'package:dart_scoring/screens/shanghai_game_screen.dart';
import 'package:dart_scoring/services/tts_service.dart';

/// F16 (audit 2026-07-06): Shanghai bypassed GameAnnouncer — no next-player
/// announcement and per-category TTS settings had no effect.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ttsChannel = MethodChannel('flutter_tts');
  const batteryChannel =
      MethodChannel('dev.fluttercommunity.plus/battery/method');
  final spoken = <String>[];

  setUp(() {
    spoken.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async {
      if (call.method == 'speak') spoken.add(call.arguments as String);
      if (call.method == 'getVoices' || call.method == 'getLanguages') {
        return <dynamic>[];
      }
      return 1;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(batteryChannel, (call) async {
      if (call.method == 'getBatteryLevel') return 100;
      if (call.method == 'getBatteryState') return 'full';
      return null;
    });
    TtsService.instance.resetForTesting();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(batteryChannel, null);
    TtsService.instance.resetForTesting();
  });

  Future<dynamic> pumpShanghai(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ShanghaiGameScreen(
        players: [Player(name: 'P1', score: 0), Player(name: 'P2', score: 0)],
        config: const ShanghaiConfig(targetEnd: 7),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    return tester.state<State<ShanghaiGameScreen>>(
        find.byType(ShanghaiGameScreen));
  }

  testWidgets('turn end announces the next player', (tester) async {
    SharedPreferences.setMockInitialValues({'tts_enabled': true});
    final dynamic s = await pumpShanghai(tester);
    s.onHitForTest(HitType.miss);
    s.onHitForTest(HitType.miss);
    s.onHitForTest(HitType.miss); // 3rd dart ends P1's turn
    await tester.pump(const Duration(milliseconds: 50));
    expect(spoken, contains('P2'),
        reason: 'Shanghai must announce the next player like every other mode');
  });

  testWidgets('next-player category off silences the announcement',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'tts_enabled': true, 'tts_announce_next_player': false});
    final dynamic s = await pumpShanghai(tester);
    s.onHitForTest(HitType.miss);
    s.onHitForTest(HitType.miss);
    s.onHitForTest(HitType.miss);
    await tester.pump(const Duration(milliseconds: 50));
    expect(spoken, isNot(contains('P2')));
  });
}
```

(NB: never end the game in these tests — the winner video overlay spins forever under `pumpAndSettle` (F18). `targetEnd: 7` with misses is safe.)

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/screens/shanghai_announcer_test.dart`
Expected: FAIL — `spoken` never contains 'P2' (Shanghai announces no next player today).

- [ ] **Step 3: Wire the announcer into Shanghai**

3a. Import + field:

```dart
import '../services/game_announcer.dart';
...
  final GameAnnouncer _announcer = GameAnnouncer();
```

3b. initState — replace the bare `TtsService.instance.init().then(...)` (129-131) with:

```dart
    _announcer.init().then((_) {
      if (mounted) setState(() => _ttsEnabled = TtsService.instance.enabled);
    });
```

(`GameAnnouncer.init()` awaits `TtsService.init()`, so the read stays race-free.)

3c. `_onHit` — route throw TTS through the announcer (226-228) and announce turn hand-off. Replace:

```dart
    final memeTriggered = _meme.onThrow(dartThrow);
    if (!memeTriggered && _ttsEnabled) {
      TtsService.instance.speak(_spokenForHit(type, target));
    }
```

with:

```dart
    final memeTriggered = _meme.onThrow(dartThrow);
    if (!memeTriggered) {
      _announcer.announceThrow(_spokenForHit(type, target));
    }
```

and inside the existing `if (turnEnded) { ... }` block (232-236), after `_turnIdCounter++;`:

```dart
      if (!engine.gameOver) {
        _announcer.announceNextPlayer(players[engine.currentPlayerIndex].name);
      }
```

3d. Winner path — announce like the other five modes (stop → video → announceWinner). Change `_onGameEnd` (~251) to pass the winner and `_fireWinnerCelebration` to:

```dart
  Future<void> _fireWinnerCelebration(String winnerName) async {
    _announcer.stop();
    if (engine.isInstantShanghai) {
      _announcer.announceGameEvent('Instant Shanghai!');
    }
    if (!mounted) return;
    await VideoService.instance.showRandomFromFolder(context, 'winner');
    if (!mounted) return;
    _announcer.announceWinner(winnerName);
  }
```

Call site in `_onGameEnd`: `await _fireWinnerCelebration(players[ranking.first].name);` (`ranking` is already computed on the line above).

3e. Remove the now-unused direct `TtsService.instance.stop()/speak('INSTANT SHANGHAI!')` lines and the `_ttsEnabled` guard they carried (the announcer + TtsService gate internally). Keep `_ttsEnabled` — the menu toggle still displays it.

- [ ] **Step 4: Race-free TTS reads in the other five modes**

Replace the synchronous read in each initState:

`cricket_game_screen.dart:95`, `around_the_clock_game_screen.dart:215`, `killer_game_screen.dart:206`, `halve_it_game_screen.dart:139` — replace `_ttsEnabled = TtsService.instance.enabled;` with:

```dart
    TtsService.instance.init().then((_) {
      if (mounted) setState(() => _ttsEnabled = TtsService.instance.enabled);
    });
```

`game_screen.dart:219` — replace `AppSettings.getTtsEnabled().then((v) => setState(() => _ttsEnabled = v));` with the same block (reads the service, not the raw pref).

- [ ] **Step 5: Verify + commit**

Run: `flutter test test/screens/shanghai_announcer_test.dart test/screens/shanghai_postgame_undo_test.dart test/screens/shanghai_midgame_stats_test.dart` → PASS.
Run: `flutter test test/screens/ test/services/` and `flutter analyze` → green / 0.

```bash
git add lib/screens/ test/screens/shanghai_announcer_test.dart
git commit -m "fix(shanghai): route audio through GameAnnouncer; race-free TTS reads in all modes (F16)"
```

---

### Task 8: F22a — Classic-track color literals → colorScheme roles (+ guard test)

**Files:**
- Test: `test/design/color_role_guard_test.dart` (create)
- Modify: `lib/screens/stats_screen.dart`, `lib/widgets/mid_game_player_sheet.dart`, `lib/screens/killer_game_screen.dart`, `lib/screens/home_screen.dart`, `lib/screens/player_setup_screen.dart`, `lib/screens/meme_settings_screen.dart`

**Interfaces:**
- Consumes: theme roles; the avatar-color helper in `lib/utils/player_colors.dart` (read `post_game_screen.dart` for the exact call used on its player rows and reuse it).
- Produces: a permanent guard test; classic files free of role-colored Material literals.

- [ ] **Step 1: Write the failing guard test**

```dart
// test/design/color_role_guard_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// F22 (audit 2026-07-06): the classic track must use colorScheme roles.
/// Two palettes live side by side by design — the DOSSEDART track uses
/// DossedartTokens (raw hex there is checked in review, not here).
void main() {
  // Whole-file exceptions (documented in the color spec).
  const allowlist = <String>{
    'lib/utils/player_colors.dart', // avatar palette
    'lib/widgets/heatmap_board.dart', // data-viz gradient
    // Dead widgets — deleted in audit Round 5 (F25), not worth fixing:
    'lib/widgets/checkout_widget.dart',
    'lib/widgets/clock_progress.dart',
    'lib/widgets/cricket_scoreboard.dart',
    'lib/widgets/halve_it_scoreboard.dart',
  };

  final roleLiterals =
      RegExp(r'Colors\.(blue|green|red|amber|purple|pink|teal|indigo|cyan)\b');
  // orange only as the D-button literal; brown only as the bronze literal.
  final orangeNotDButton = RegExp(r'Colors\.orange(?!\[800\])');
  final brownNotBronze = RegExp(r'Colors\.brown(?!\[300\])');

  test('no role-colored Material literals on the classic track', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) =>
            !allowlist.contains(f.path.replaceAll('\\', '/')));
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first;
        if (roleLiterals.hasMatch(code) ||
            orangeNotDButton.hasMatch(code) ||
            brownNotBronze.hasMatch(code)) {
          offenders.add('${f.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Use Theme.of(context).colorScheme roles (F22):\n'
            '${offenders.join('\n')}');
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/design/color_role_guard_test.dart`
Expected: FAIL listing the violations below (and possibly a few more — fix everything it reports using the same role logic).

- [ ] **Step 3: Fix each violation** (`cs` = `Theme.of(context).colorScheme`)

| File:line | Current | Replace with |
|---|---|---|
| stats_screen.dart:175, 358 | `backgroundColor: Colors.blue` (avatars) | the same avatar-color lookup `post_game_screen.dart` uses (player_colors util) |
| stats_screen.dart:201 | `Colors.red` delete icon | `cs.error` |
| stats_screen.dart:265 | `lineColor: Colors.blue` | `lineColor: cs.primary` |
| stats_screen.dart:391 | `? Colors.green` win-rate | `? cs.primary` |
| stats_screen.dart:503/505/515 | `Colors.red.withAlpha(25)` / `.withAlpha(60)` / `Colors.red[300]` badge | `cs.error.withAlpha(25)` / `cs.error.withAlpha(60)` / `cs.error` |
| stats_screen.dart:1157 | `isUp ? Colors.green[400] : Colors.red[400]` | `isUp ? cs.primary : cs.error` |
| stats_screen.dart:1214 | `Colors.grey.withAlpha(50)` chart grid | pass `cs.outline.withAlpha(50)` into the painter (add a `gridColor` param if it is hardcoded) |
| mid_game_player_sheet.dart:153 | `backgroundColor: Colors.blue` | avatar-color lookup as above |
| mid_game_player_sheet.dart:161 | `Colors.green` add icon | `cs.primary` |
| mid_game_player_sheet.dart:201 | `canRemove ? Colors.red : Colors.grey` | `canRemove ? cs.error : cs.onSurface.withValues(alpha: 0.38)` |
| killer_game_screen.dart:1314, 1645 | `Colors.blue` shields | `cs.tertiary` |
| killer_game_screen.dart:1664 | `? Colors.red` hearts | `? cs.error` |
| home_screen.dart:159-161 | `goldColor 0xFFFFD700` / `silverColor 0xFFC0C0C0` / `bronzeColor 0xFFCD7F32` | gold → `cs.tertiary` (drop `const`), silver stays `Color(0xFFC0C0C0)` with `// podium silver — documented exception`, bronze → `Colors.brown[300]!` |
| player_setup_screen.dart:191 | `Colors.green` confirm icon | `cs.primary` |
| player_setup_screen.dart:165, 423, 560 | `Colors.grey` labels | `cs.onSurfaceVariant` |
| meme_settings_screen.dart:48 | `Colors.grey` subtitle | `cs.onSurfaceVariant` |

If the guard reports files not in this table, apply the same mapping logic (positive → primary, warning → secondary, info → tertiary, destructive/negative → error, neutral text → onSurfaceVariant) — do not allowlist anything new without a comment explaining why.

- [ ] **Step 4: Verify + commit**

Run: `flutter test test/design/color_role_guard_test.dart` → PASS.
Run: `flutter test test/screens/ test/stats/` and `flutter analyze` → green / 0.

```bash
git add test/design/color_role_guard_test.dart lib/
git commit -m "fix(theme): classic-track color literals -> colorScheme roles, guarded by test (F22)"
```

---

### Task 9: F22b — Arcade raw hex → DossedartTokens

**Files:**
- Modify: `lib/theme/dossedart_tokens.dart` (one new token)
- Modify: `lib/theme/dossedart_theme.dart:158`, `lib/widgets/dossedart/arcade_frame.dart:132-134`, `lib/widgets/dossedart/dossedart_player_avatar.dart:36`, `lib/widgets/dossedart/setup/dossedart_picker_tile.dart:42`, `lib/widgets/dossedart/setup/dossedart_setup_scaffold.dart:378-383`, `lib/screens/dossedart/dossedart_home_screen.dart:249`, `lib/screens/dossedart/game_detail_screen.dart:96`

**Interfaces:**
- Consumes: `DossedartTokens` (magenta/cyan/yellow/orange/phosphor/disabledFill/disabledBorder).
- Produces: `DossedartTokens.surfaceRaised` (`0xFF2A0050`) — Task 11 documents it.

- [ ] **Step 1: Add the missing token**

```dart
  /// Raised purple chip surface (avatar backgrounds) — one step above [surface].
  static const Color surfaceRaised = Color(0xFF2A0050);
```

- [ ] **Step 2: Replace the raw duplicates** (drop `const` where `.withValues` forces it)

| File:line | Current | Replace with |
|---|---|---|
| dossedart_theme.dart:158 | `Color(0x33FF00AA)` | `DossedartTokens.magenta.withValues(alpha: 0.2)` |
| arcade_frame.dart:132-134 | `Color(0x0000E5FF)` / `Color(0x2200E5FF)` / `Color(0x0000E5FF)` | `DossedartTokens.cyan.withValues(alpha: 0)` / `(alpha: 0.13)` / `(alpha: 0)` |
| dossedart_player_avatar.dart:36 | `Color(0xFF2A0050)` | `DossedartTokens.surfaceRaised` |
| dossedart_picker_tile.dart:42 | `Color(0x10FFD200)` | `DossedartTokens.yellow.withValues(alpha: 0.06)` |
| dossedart_setup_scaffold.dart:378 | `Color(0xFFFFA500)` in the gradient | `DossedartTokens.orange` |
| dossedart_setup_scaffold.dart:381 | `Colors.white12` | `DossedartTokens.disabledFill` |
| dossedart_setup_scaffold.dart:383 | `Colors.white24` | `DossedartTokens.disabledBorder` |
| dossedart_home_screen.dart:249 | `Color(0x14FFD200)` | `DossedartTokens.yellow.withValues(alpha: 0.08)` |
| game_detail_screen.dart:96 | `Color(0x8CD9D2C2)` | `DossedartTokens.phosphor.withValues(alpha: 0.55)` |

Deliberately NOT changed (documented as exceptions in Task 11): `arcade_frame.dart` black scanline/vignette (`0x4D000000`, `0x99000000`), the white-alpha text ramp in `game_detail_screen.dart` (`0x80FFFFFF` family), and both dartboard painters. The two magenta home-screen dividers (`:145`, `:170`) are handled in Task 10 (F23).

- [ ] **Step 3: Verify + commit**

Run: `flutter analyze` → 0. Run: `flutter test test/screens/` → green (visual-only change; `0xFFFFA500`→token orange is an intended slight shade shift).

```bash
git add lib/theme/ lib/widgets/dossedart/ lib/screens/dossedart/
git commit -m "fix(theme): arcade raw hex -> DossedartTokens; add surfaceRaised token (F22)"
```

---

### Task 10: F23 — Outline widths + magenta-divider standard

**Files:**
- Modify: `lib/widgets/active_player_highlight.dart:20`
- Modify: `lib/screens/game_screen.dart` (~1978 stale "border 3" comment)
- Modify: `lib/screens/cricket_game_screen.dart:1486, 1528`
- Modify: `lib/screens/halve_it_game_screen.dart:1083, 1300`
- Modify: `lib/screens/shanghai_game_screen.dart:1185`
- Modify: `lib/widgets/dossedart/setup/dossedart_picker_tile.dart:138`
- Modify: `lib/screens/dossedart/dossedart_home_screen.dart:145, 170`
- Test: `test/widgets/active_player_highlight_test.dart` (create)

**Interfaces:**
- Consumes: `DossedartTokens.{magenta,disabledBorder,borderThin}`.
- Produces: `ActivePlayerHighlight` default `borderWidth = 2` (X01/Shanghai/Killer/ATC inherit it — no call site passes a width).

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/active_player_highlight_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/active_player_highlight.dart';

/// F23 (audit 2026-07-06): the color spec mandates a 2px primary border for
/// the active player; the shared ring silently defaulted to 3px.
void main() {
  testWidgets('active ring defaults to a 2px border', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ActivePlayerHighlight(isActive: true, child: SizedBox()),
    ));
    final container = tester.widget<Container>(find.byType(Container).first);
    final border = (container.decoration as BoxDecoration).border as Border;
    expect(border.top.width, 2);
  });
}
```

(If the widget's constructor is not const or has required extra params, mirror its actual signature from `active_player_highlight.dart` — the assertion is what matters.)

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/widgets/active_player_highlight_test.dart`
Expected: FAIL — width is 3.

- [ ] **Step 3: Fix the widths**

| File:line | Current | Change |
|---|---|---|
| active_player_highlight.dart:20 | `this.borderWidth = 3,` | `this.borderWidth = 2,` |
| game_screen.dart:~1978 | comment mentioning "border 3" | update to say 2 (or drop the width from the comment) |
| cricket_game_screen.dart:1486 | `BorderSide(color: …onSurface.withValues(alpha: 0.4), width: 1.5)` | `BorderSide(color: Theme.of(context).colorScheme.outline, width: 1)` |
| cricket_game_screen.dart:1528 | `Border.all(color: …outline, width: 0.5)` | `width: 1` |
| halve_it_game_screen.dart:1083 | `Border.all(color: c, width: 1.5)` | `width: 1` |
| halve_it_game_screen.dart:1300 | `Border.all(color: …tertiary, width: 1.5)` | `width: 2` (active-state chip) |
| shanghai_game_screen.dart:1185 | `color: …tertiary, width: 1.5)` | `width: 2` (same chip pattern) |
| dossedart_picker_tile.dart:138 | `Border.all(color: Colors.white24, width: 1.5)` | `Border.all(color: DossedartTokens.disabledBorder, width: DossedartTokens.borderThin)` |
| dossedart_home_screen.dart:145 | `BorderSide(color: Color(0x66FF00AA), width: 1)` | `BorderSide(color: DossedartTokens.magenta.withValues(alpha: 0.4), width: 1)` |
| dossedart_home_screen.dart:170 | `BorderSide(color: Color(0x4DFF00AA), width: 1)` | `BorderSide(color: DossedartTokens.magenta.withValues(alpha: 0.4), width: 1)` |

(Divider standard after this task: major chrome = full `magenta`, 2px; subtle row dividers = `magenta @ 0.4`, 1px. `dossedart_home_screen.dart:103` already complies.)

- [ ] **Step 4: Verify + commit**

Run: `flutter test test/widgets/active_player_highlight_test.dart test/screens/` → PASS; `flutter analyze` → 0.

```bash
git add lib/ test/widgets/active_player_highlight_test.dart
git commit -m "fix(theme): 2px active ring, 1px outlines, one magenta-divider standard (F23)"
```

---

### Task 11: Document both palettes (spec + CLAUDE.md)

**Files:**
- Modify: `docs/superpowers/specs/2026-04-30-color-design-system.md`
- Modify: `CLAUDE.md` (Tema section)

**Interfaces:**
- Consumes: final state of Tasks 8-10.
- Produces: the two-track contract future reviews cite.

- [ ] **Step 1: Add two sections to the spec** (after `## Player avatar colors`)

```markdown
## DOSSEDART / Arcade track

The DOSSEDART redesign is a second, deliberate design track that lives beside
the classic four-role palette (decision 2026-07-06). It never uses
`colorScheme` roles; every color comes from `lib/theme/dossedart_tokens.dart`:

| Token | Hex | Use |
| --- | --- | --- |
| `bg` | `#0A0014` | app background |
| `surface` | `#1A0030` | cards, sheets |
| `surfaceRaised` | `#2A0050` | avatar chips, raised fills |
| `magenta` | `#FF00AA` | chrome, dividers, brand accent |
| `cyan` | `#00E5FF` | active player, focus |
| `yellow` | `#FFD200` | hero/highlight tints |
| `green` | `#3DFF8E` | positive |
| `red` | `#FF3050` | negative, destructive |
| `purple` | `#7B3FFF` | secondary accent |
| `orange` | `#FF7A00` | warm accent (start CTA gradient) |
| `phosphor` | `#D9D2C2` | body text |
| `silver` / `bronze` | `#C9D2DA` / `#D08A4A` | podium metals |
| `disabledFill/Border/Fg` | white @ 12/24/38% | disabled states |

Border widths: `borderThin` 1, `border` 2, `borderActive` 3, `borderTakeover` 5.
Dividers: major chrome = full `magenta` at 2px; subtle row dividers =
`magenta` at 40% alpha, 1px.
Alpha variants are expressed as `token.withValues(alpha: …)`, never as a new
raw hex of the same hue.

## Documented exceptions

- `lib/utils/player_colors.dart` — avatar palette (both tracks).
- `lib/widgets/heatmap_board.dart` — data-viz gradient.
- `lib/widgets/dart_board.dart` — physical bristle-board palette (its red
  `#E53935` coincidentally equals the error role; do not "fix" it).
- `lib/widgets/dossedart/x01/dossedart_x01_dartboard.dart` — neon twilight
  board palette, deliberately tuned near-neighbors of magenta/cyan.
- D-buttons `Colors.orange[800]` in halve_it/atc score input.
- Podium metals (classic): gold = `tertiary`, silver = `#C0C0C0`,
  bronze = `Colors.brown[300]`.
- CRT effects in `arcade_frame.dart` (black scanline/vignette) and the
  white-alpha text ramp in `game_detail_screen.dart` — pure black/white
  effect layers, not palette colors.
```

Also update the spec's front-matter status line to `Status: Adopted (rev 2026-07-07 — two-track model)` and fix the active-border sentence if it still says anything other than 2px.

- [ ] **Step 2: Update CLAUDE.md's Tema section**

After the existing four-role table + exceptions, adjust the exceptions list to match the spec (add the two dartboard painters and podium silver) and add one line:

```markdown
**DOSSEDART-sporet:** arkade-redesignet er et eget design-spor og bruker kun `DossedartTokens` (`lib/theme/dossedart_tokens.dart`) — aldri rå hex, aldri `colorScheme`. Full spec: samme dokument, seksjon «DOSSEDART / Arcade track».
```

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-04-30-color-design-system.md CLAUDE.md
git commit -m "docs(theme): document the two-track palette model and exceptions (F22)"
```

---

### Final verification (after all tasks)

- [ ] `flutter analyze` → 0 issues.
- [ ] Run the test suite in batches (F18 hang risk until Round 5): `flutter test test/models test/services test/stats test/design test/widgets` then `flutter test test/screens`.
- [ ] `grep -rn "Halve It" lib/` → comments only. `grep -rEn "[æøåÆØÅ]" lib/ | grep -v "^.*//"` → nothing in string literals.
- [ ] Do NOT push — Bjørn triggers CI. Tablet smoke test remains open for rounds 1-4 together.
