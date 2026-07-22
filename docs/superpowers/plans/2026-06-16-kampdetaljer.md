# KAMPDETALJER Drill-down Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make HISTORIKK rows tappable → a KAMPDETALJER screen showing standings + ΔELO, per-player earned feats, full play-by-play (progression chart + round log) and a side-by-side comparison, for all 6 game modes.

**Architecture:** Capture-at-game-end (Approach A): persist `throwHistory` + per-player `earnedFeats` on `GameHistoryEntry` when a game ends. Display derives the progression chart, round log, and per-player grid from the stored `throwHistory` via per-mode strategies; old games without it fall to an empty state. Feats reuse the achievement events/unlocks each cockpit already computes.

**Tech Stack:** Flutter (Dart), SharedPreferences (via `GameHistoryService`), `flutter_test`. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-06-16-kampdetaljer-design.md`

**Conventions:** Code/comments/UI in English. Colors from `DossedartTokens` / the role palette only. Board-style feat colors: cyan=you, gold/silver/bronze=placement/tier, green/red=ELO, triple=cyan/double=magenta on dart chips.

**Test command:** `flutter test test/<file>_test.dart` (single test: append `--plain-name "<name>"`).

---

## PHASE 0 — Data foundation

### Task 1: DartThrow JSON serialization

**Files:**
- Modify: `lib/models/dart_throw.dart`
- Test: `test/models/dart_throw_json_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/dart_throw.dart';

void main() {
  test('DartThrow round-trips through JSON', () {
    final t = DartThrow(
      playerIndex: 1, segment: 20, multiplier: 3, points: 60,
      scoreBefore: 501, turnNumber: 0, scoreAtStartOfTurn: 501,
      turnId: 7, roundNumber: 1, isBust: false,
    );
    final back = DartThrow.fromJson(t.toJson());
    expect(back.playerIndex, 1);
    expect(back.segment, 20);
    expect(back.multiplier, 3);
    expect(back.points, 60);
    expect(back.scoreBefore, 501);
    expect(back.turnNumber, 0);
    expect(back.scoreAtStartOfTurn, 501);
    expect(back.turnId, 7);
    expect(back.roundNumber, 1);
    expect(back.isBust, false);
  });
}
```

> NOTE: confirm the package name in `pubspec.yaml` (`name:`). If it is not `dart_scoring`, replace `package:dart_scoring/...` everywhere in this plan with the actual name.

- [ ] **Step 2: Run test, verify it fails**

Run: `flutter test test/models/dart_throw_json_test.dart`
Expected: FAIL — `The method 'fromJson' isn't defined for the type 'DartThrow'`.

- [ ] **Step 3: Add toJson/fromJson to DartThrow**

In `lib/models/dart_throw.dart`, inside the `DartThrow` class (after the constructor, before `String get label`):

```dart
  Map<String, dynamic> toJson() => {
        'pi': playerIndex,
        'seg': segment,
        'mul': multiplier,
        'pts': points,
        'sb': scoreBefore,
        'tn': turnNumber,
        'sst': scoreAtStartOfTurn,
        'tid': turnId,
        'rnd': roundNumber,
        if (isBust) 'bust': true,
      };

  factory DartThrow.fromJson(Map<String, dynamic> j) => DartThrow(
        playerIndex: j['pi'] as int,
        segment: j['seg'] as int,
        multiplier: j['mul'] as int,
        points: j['pts'] as int,
        scoreBefore: j['sb'] as int,
        turnNumber: j['tn'] as int,
        scoreAtStartOfTurn: j['sst'] as int,
        turnId: (j['tid'] as int?) ?? 0,
        roundNumber: (j['rnd'] as int?) ?? 0,
        isBust: (j['bust'] as bool?) ?? false,
      );
```

(Short JSON keys keep stored history compact — throwHistory is the bulk of an entry.)

- [ ] **Step 4: Run test, verify it passes**

Run: `flutter test test/models/dart_throw_json_test.dart` → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/dart_throw.dart test/models/dart_throw_json_test.dart
git commit -m "feat(history): DartThrow JSON serialization"
```

---

### Task 2: EarnedFeat model + event/achievement mapping

**Files:**
- Create: `lib/models/earned_feat.dart`
- Test: `test/models/earned_feat_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/achievement.dart';
import 'package:dart_scoring/models/achievement_event.dart';
import 'package:dart_scoring/models/earned_feat.dart';

void main() {
  test('EarnedFeat round-trips through JSON', () {
    const f = EarnedFeat(
        label: '180!', tier: AchievementTier.gold,
        note: 'Maks i runde 1', kind: FeatKind.feat, round: 1);
    final back = EarnedFeat.fromJson(f.toJson());
    expect(back.label, '180!');
    expect(back.tier, AchievementTier.gold);
    expect(back.note, 'Maks i runde 1');
    expect(back.kind, FeatKind.feat);
    expect(back.round, 1);
  });

  test('feat from in-game event maps to a label + tier', () {
    final f = EarnedFeat.fromEvent(AchievementEvent.score180);
    expect(f.label, '180!');
    expect(f.kind, FeatKind.feat);
  });

  test('feat from unlocked achievement is a star unlock', () {
    const a = Achievement(
      id: 'x01_maximum', name: 'MAXIMUM', description: 'Hit a 180',
      tier: AchievementTier.gold, category: AchievementCategory.scoring,
      glyph: AchievementGlyph.asset('x'),
    );
    final f = EarnedFeat.fromUnlock(a);
    expect(f.label, 'MAXIMUM');
    expect(f.tier, AchievementTier.gold);
    expect(f.kind, FeatKind.unlock);
  });
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `flutter test test/models/earned_feat_test.dart` → FAIL (file/class missing).

- [ ] **Step 3: Create `lib/models/earned_feat.dart`**

```dart
import 'achievement.dart';
import 'achievement_event.dart';

enum FeatKind { unlock, feat } // unlock = newly-earned achievement (★), feat = in-game moment (✦)

class EarnedFeat {
  final String label;
  final AchievementTier tier;
  final String? note;
  final FeatKind kind;
  final int? round;

  const EarnedFeat({
    required this.label,
    required this.tier,
    this.note,
    required this.kind,
    this.round,
  });

  /// ✦ in-game feat from the event a cockpit already fires at game-end.
  factory EarnedFeat.fromEvent(AchievementEvent e, {int? round}) {
    final (label, tier) = _eventLabel(e);
    return EarnedFeat(label: label, tier: tier, kind: FeatKind.feat, round: round);
  }

  /// ★ unlock from a newly-earned achievement.
  factory EarnedFeat.fromUnlock(Achievement a) => EarnedFeat(
        label: a.name,
        tier: a.tier,
        note: a.description,
        kind: FeatKind.unlock,
      );

  static (String, AchievementTier) _eventLabel(AchievementEvent e) {
    switch (e) {
      case AchievementEvent.score180:
        return ('180!', AchievementTier.gold);
      case AchievementEvent.bigCheckout:
        return ('100+ CHECKOUT', AchievementTier.silver);
      case AchievementEvent.bullFinish:
        return ('BULL FINISH', AchievementTier.silver);
      case AchievementEvent.threeTreblesTurn:
        return ('3× TRIPLE', AchievementTier.silver);
      case AchievementEvent.threeBullsTurn:
        return ('3× BULL', AchievementTier.gold);
      case AchievementEvent.nineMarkTurn:
        return ('9 MARKS', AchievementTier.gold);
      case AchievementEvent.instantShanghai:
        return ('INSTANT SHANGHAI', AchievementTier.gold);
      case AchievementEvent.becameKiller:
        return ('BECAME KILLER', AchievementTier.bronze);
      case AchievementEvent.multiKill:
        return ('MULTI-KILL', AchievementTier.silver);
      case AchievementEvent.clutchSave:
        return ('CLUTCH SAVE', AchievementTier.silver);
      case AchievementEvent.nice69:
        return ('NICE (69)', AchievementTier.bronze);
      case AchievementEvent.sixSeven:
        return ('6-7', AchievementTier.bronze);
      case AchievementEvent.threeMisses:
        return ('3 MISSES', AchievementTier.bronze);
    }
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'tier': tier.name,
        if (note != null) 'note': note,
        'kind': kind.name,
        if (round != null) 'round': round,
      };

  factory EarnedFeat.fromJson(Map<String, dynamic> j) => EarnedFeat(
        label: j['label'] as String,
        tier: AchievementTier.values.byName(j['tier'] as String),
        note: j['note'] as String?,
        kind: FeatKind.values.byName(j['kind'] as String),
        round: j['round'] as int?,
      );
}
```

- [ ] **Step 4: Run test, verify it passes** → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/earned_feat.dart test/models/earned_feat_test.dart
git commit -m "feat(history): EarnedFeat model + event/unlock mapping"
```

---

### Task 3: GameHistoryEntry/Player new fields

**Files:**
- Modify: `lib/models/game_history.dart`
- Test: `test/models/game_history_json_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/achievement.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/models/earned_feat.dart';
import 'package:dart_scoring/models/game_history.dart';

void main() {
  test('entry with new fields round-trips', () {
    final entry = GameHistoryEntry(
      id: '1', gameMode: 'x01', date: DateTime(2026, 6, 16),
      gameConfig: '501 · Dobbel ut', durationSeconds: 1080,
      throwHistory: [
        DartThrow(playerIndex: 0, segment: 20, multiplier: 3, points: 60,
            scoreBefore: 501, turnNumber: 0, scoreAtStartOfTurn: 501,
            turnId: 1, roundNumber: 1),
      ],
      players: [
        GameHistoryPlayer(
          name: 'Jonas', placement: 1, stats: {'totalDarts': 15},
          earnedFeats: const [EarnedFeat(
              label: '180!', tier: AchievementTier.gold,
              kind: FeatKind.feat, round: 1)],
        ),
      ],
    );
    final back = GameHistoryEntry.fromJson(entry.toJson());
    expect(back.gameConfig, '501 · Dobbel ut');
    expect(back.durationSeconds, 1080);
    expect(back.throwHistory!.length, 1);
    expect(back.throwHistory!.first.points, 60);
    expect(back.players.first.earnedFeats!.first.label, '180!');
  });

  test('old entry JSON without new fields still decodes (nulls)', () {
    final old = {
      'id': '9', 'gameMode': 'cricket', 'date': '2026-01-01T00:00:00.000',
      'players': [
        {'name': 'A', 'placement': 1, 'stats': {'points': 40}},
      ],
    };
    final back = GameHistoryEntry.fromJson(old);
    expect(back.throwHistory, isNull);
    expect(back.gameConfig, isNull);
    expect(back.durationSeconds, isNull);
    expect(back.players.first.earnedFeats, isNull);
  });
}
```

- [ ] **Step 2: Run test, verify it fails** → FAIL (named params don't exist).

- [ ] **Step 3: Add fields to `game_history.dart`**

Add imports at top:
```dart
import 'dart_throw.dart';
import 'earned_feat.dart';
```

`GameHistoryEntry` — add fields + params + JSON. Replace the class's field block, constructor, `toJson`, and `fromJson`:

```dart
class GameHistoryEntry {
  final String id;
  final String gameMode;
  final DateTime date;
  final List<GameHistoryPlayer> players;
  final String? gameConfig;
  final int? durationSeconds;
  final List<DartThrow>? throwHistory;

  GameHistoryEntry({
    required this.id,
    required this.gameMode,
    required this.date,
    required this.players,
    this.gameConfig,
    this.durationSeconds,
    this.throwHistory,
  });

  /// Max round in the recorded throws, or null when no throw history.
  int? get rounds => throwHistory == null || throwHistory!.isEmpty
      ? null
      : throwHistory!.map((t) => t.roundNumber).reduce((a, b) => a > b ? a : b);

  Map<String, dynamic> toJson() => {
        'id': id,
        'gameMode': gameMode,
        'date': date.toIso8601String(),
        'players': players.map((p) => p.toJson()).toList(),
        if (gameConfig != null) 'gameConfig': gameConfig,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        if (throwHistory != null)
          'throws': throwHistory!.map((t) => t.toJson()).toList(),
      };

  factory GameHistoryEntry.fromJson(Map<String, dynamic> json) =>
      GameHistoryEntry(
        id: json['id'] as String,
        gameMode: json['gameMode'] as String,
        date: DateTime.parse(json['date'] as String),
        players: (json['players'] as List)
            .map((p) => GameHistoryPlayer.fromJson(p as Map<String, dynamic>))
            .toList(),
        gameConfig: json['gameConfig'] as String?,
        durationSeconds: json['durationSeconds'] as int?,
        throwHistory: (json['throws'] as List?)
            ?.map((t) => DartThrow.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
  // encodeList / decodeList unchanged
```

`GameHistoryPlayer` — add `earnedFeats`:

```dart
  final List<EarnedFeat>? earnedFeats;
```
Add `this.earnedFeats,` to the constructor. In `toJson`, before the closing `};`:
```dart
        if (earnedFeats != null)
          'feats': earnedFeats!.map((f) => f.toJson()).toList(),
```
In `fromJson`, add:
```dart
        earnedFeats: (json['feats'] as List?)
            ?.map((f) => EarnedFeat.fromJson(f as Map<String, dynamic>))
            .toList(),
```

- [ ] **Step 4: Run test, verify it passes** → PASS (both tests).

- [ ] **Step 5: Commit**

```bash
git add lib/models/game_history.dart test/models/game_history_json_test.dart
git commit -m "feat(history): throwHistory, gameConfig, duration, earnedFeats fields"
```

---

### Task 4: StatsRecorder captures new fields

**Files:**
- Modify: `lib/services/stats_recorder.dart` (signature ~13-22, entry build ~99-121)
- Test: `test/services/stats_recorder_capture_test.dart`

- [ ] **Step 1: Write the failing test**

The recorder writes to SharedPreferences via `GameHistoryService`. Use `SharedPreferences.setMockInitialValues`.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/models/earned_feat.dart';
import 'package:dart_scoring/models/achievement.dart';
import 'package:dart_scoring/services/game_history_service.dart';
import 'package:dart_scoring/services/stats_recorder.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('recordGame persists throwHistory + earnedFeats + config', () async {
    StatsRecorder.recordGame(
      gameMode: 'x01',
      playerIds: [null],            // no saved player → skips rating/stats loops
      playerNames: ['Guest'],
      placements: [1],
      savedPlayers: const [],
      gameConfig: '501 · Dobbel ut',
      durationSeconds: 600,
      throwHistory: [
        DartThrow(playerIndex: 0, segment: 20, multiplier: 3, points: 60,
            scoreBefore: 501, turnNumber: 0, scoreAtStartOfTurn: 501,
            turnId: 1, roundNumber: 1),
      ],
      earnedFeatsByIndex: {
        0: const [EarnedFeat(label: '180!', tier: AchievementTier.gold,
            kind: FeatKind.feat, round: 1)],
      },
    );
    // record() is fire-and-forget; allow the microtask/IO to settle.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final history = await GameHistoryService.load();
    expect(history, isNotEmpty);
    expect(history.first.gameConfig, '501 · Dobbel ut');
    expect(history.first.durationSeconds, 600);
    expect(history.first.throwHistory!.single.points, 60);
    expect(history.first.players.first.earnedFeats!.single.label, '180!');
  });
}
```

- [ ] **Step 2: Run test, verify it fails** → FAIL (named params don't exist).

- [ ] **Step 3: Extend `recordGame`**

Add params to the signature (after `ratingsAfter`):
```dart
    String? gameConfig,
    int? durationSeconds,
    List<DartThrow>? throwHistory,
    Map<int, List<EarnedFeat>>? earnedFeatsByIndex,
```
Add imports:
```dart
import '../models/dart_throw.dart';
import '../models/earned_feat.dart';
```
In the `historyPlayers` builder (the `List.generate`), add `earnedFeats` to the `GameHistoryPlayer(...)`:
```dart
        earnedFeats: earnedFeatsByIndex?[i],
```
In the `GameHistoryEntry(...)` build, add:
```dart
      gameConfig: gameConfig,
      durationSeconds: durationSeconds,
      throwHistory: throwHistory,
```

- [ ] **Step 4: Run test, verify it passes** → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/stats_recorder.dart test/services/stats_recorder_capture_test.dart
git commit -m "feat(history): StatsRecorder captures throwHistory + feats + config"
```

---

### Task 5: throwHistory retention trim

**Files:**
- Modify: `lib/services/game_history_service.dart`
- Test: `test/services/game_history_retention_test.dart`

Keep full entries to `_maxEntries` (200) but `throwHistory` only on the newest `_maxThrowHistory` (100); older entries keep everything else, throwHistory nulled.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/services/game_history_service.dart';

GameHistoryEntry _entry(int i) => GameHistoryEntry(
      id: '$i', gameMode: 'x01', date: DateTime(2026, 1, 1).add(Duration(minutes: i)),
      players: [GameHistoryPlayer(name: 'A', placement: 1, stats: const {})],
      throwHistory: [DartThrow(playerIndex: 0, segment: 1, multiplier: 1, points: 1,
          scoreBefore: 1, turnNumber: 0, scoreAtStartOfTurn: 1)],
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('only the newest 100 entries keep throwHistory', () async {
    for (var i = 0; i < 105; i++) {
      await GameHistoryService.record(_entry(i));
    }
    final all = await GameHistoryService.load(); // newest first
    expect(all.length, 105);
    expect(all[0].throwHistory, isNotNull);   // newest
    expect(all[99].throwHistory, isNotNull);  // 100th newest
    expect(all[100].throwHistory, isNull);    // beyond cap, trimmed
    expect(all[100].players.first.placement, 1); // rest of entry intact
  });
}
```

- [ ] **Step 2: Run test, verify it fails** → FAIL (entry 100 still has throwHistory).

- [ ] **Step 3: Add trim to `record`**

```dart
  static const _maxEntries = 200;
  static const _maxThrowHistory = 100;

  static Future<void> record(GameHistoryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await load();
    existing.insert(0, entry); // newest first
    final trimmed = existing.take(_maxEntries).toList();
    // Drop throwHistory beyond the newest _maxThrowHistory to bound storage.
    for (var i = _maxThrowHistory; i < trimmed.length; i++) {
      final e = trimmed[i];
      if (e.throwHistory == null) continue;
      trimmed[i] = GameHistoryEntry(
        id: e.id, gameMode: e.gameMode, date: e.date, players: e.players,
        gameConfig: e.gameConfig, durationSeconds: e.durationSeconds,
        throwHistory: null,
      );
    }
    await prefs.setString(_key, GameHistoryEntry.encodeList(trimmed));
  }
```

- [ ] **Step 4: Run test, verify it passes** → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/game_history_service.dart test/services/game_history_retention_test.dart
git commit -m "feat(history): cap throwHistory to newest 100 games"
```

---

## PHASE 1 — Capture at game-end (wire the cockpits)

### Task 6: awardGameEnd returns newly-unlocked achievements

**Files:**
- Modify: `lib/services/achievement_service.dart` (`awardGameEnd` ~69-112)
- Test: `test/services/achievement_award_return_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/achievement.dart';
import 'package:dart_scoring/models/achievement_event.dart';
import 'package:dart_scoring/models/game_mode.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/achievement_service.dart';

void main() {
  test('awardGameEnd returns the achievements unlocked, keyed by index', () {
    const a = Achievement(
      id: 'x01_maximum', name: 'MAXIMUM', description: 'Hit a 180',
      tier: AchievementTier.gold, category: AchievementCategory.scoring,
      glyph: AchievementGlyph.icon(null), event: AchievementEvent.score180,
    );
    final svc = AchievementService.forTest([a]);
    final sp = SavedPlayer(id: 'p1', name: 'Jonas'); // adjust to real ctor
    final unlocked = svc.awardGameEnd(
      mode: GameMode.x01,
      playerIds: ['p1'],
      savedPlayers: [sp],
      placements: [1],
      ratingsBefore: const {'p1': 1000},
      ratingsAfter: const {'p1': 1010},
      eventsByIndex: {0: [AchievementEvent.score180]},
    );
    expect(unlocked[0]!.map((a) => a.id), contains('x01_maximum'));
  });
}
```

> Adjust the `SavedPlayer` constructor call to the real one (check `lib/models/saved_player.dart`).

- [ ] **Step 2: Run test, verify it fails** → FAIL (`awardGameEnd` returns void).

- [ ] **Step 3: Change `awardGameEnd` to collect + return unlocks**

Change the return type from `void` to `Map<int, List<Achievement>>`. Inside the loop, capture results:
```dart
    final unlockedByIndex = <int, List<Achievement>>{};
    for (int i = 0; i < playerIds.length; i++) {
      // ... existing id/sp guards ...
      final newly = <Achievement>[];
      for (final e in eventsByIndex[i] ?? const <AchievementEvent>[]) {
        newly.addAll(checkEvent(e, sp));
      }
      // ... existing opponents build ...
      newly.addAll(evaluateMilestones(sp, GameOutcome(/* unchanged */)));
      if (newly.isNotEmpty) unlockedByIndex[i] = newly;
    }
    return unlockedByIndex;
```
Early return becomes `return const {};` (the `if (placements.isEmpty) return;`).

- [ ] **Step 4: Run test, verify it passes** → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/achievement_service.dart test/services/achievement_award_return_test.dart
git commit -m "feat(achievements): awardGameEnd returns newly-unlocked by index"
```

---

### Task 7: Shared earnedFeats builder

**Files:**
- Create: `lib/utils/earned_feats_builder.dart`
- Test: `test/utils/earned_feats_builder_test.dart`

Builds a per-index `Map<int, List<EarnedFeat>>` from (a) the events each cockpit already passes to `awardGameEnd` (✦) and (b) the unlocks it returns (★).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/achievement.dart';
import 'package:dart_scoring/models/achievement_event.dart';
import 'package:dart_scoring/models/earned_feat.dart';
import 'package:dart_scoring/utils/earned_feats_builder.dart';

void main() {
  test('combines in-game events (feat) and unlocks (unlock)', () {
    const a = Achievement(
      id: 'x', name: 'MAXIMUM', description: 'd', tier: AchievementTier.gold,
      category: AchievementCategory.scoring, glyph: AchievementGlyph.icon(null));
    final feats = buildEarnedFeats(
      eventsByIndex: {0: [AchievementEvent.score180]},
      unlocksByIndex: {0: [a]},
    );
    final labels = feats[0]!.map((f) => f.label).toList();
    expect(labels, containsAll(['180!', 'MAXIMUM']));
    expect(feats[0]!.where((f) => f.kind == FeatKind.feat).length, 1);
    expect(feats[0]!.where((f) => f.kind == FeatKind.unlock).length, 1);
  });
}
```

- [ ] **Step 2: Run test, verify it fails** → FAIL (missing).

- [ ] **Step 3: Create the builder**

```dart
import '../models/achievement.dart';
import '../models/achievement_event.dart';
import '../models/earned_feat.dart';

/// Merge the ✦ in-game events a cockpit fires with the ★ unlocks awardGameEnd
/// returns into the per-player feat lists shown on KAMPDETALJER.
Map<int, List<EarnedFeat>> buildEarnedFeats({
  required Map<int, List<AchievementEvent>> eventsByIndex,
  required Map<int, List<Achievement>> unlocksByIndex,
}) {
  final out = <int, List<EarnedFeat>>{};
  for (final entry in eventsByIndex.entries) {
    out[entry.key] = entry.value.map((e) => EarnedFeat.fromEvent(e)).toList();
  }
  for (final entry in unlocksByIndex.entries) {
    (out[entry.key] ??= []).addAll(entry.value.map(EarnedFeat.fromUnlock));
  }
  return out;
}
```

- [ ] **Step 4: Run test, verify it passes** → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/utils/earned_feats_builder.dart test/utils/earned_feats_builder_test.dart
git commit -m "feat(history): shared earnedFeats builder (events + unlocks)"
```

---

### Tasks 8-13: Wire each cockpit to capture data

Each cockpit currently: builds `events`/`eventsByIndex`, calls `awardGameEnd(...)`, and calls `StatsRecorder.recordGame(...)`. Change each to (1) keep the `awardGameEnd` return value, (2) build `earnedFeats`, (3) pass `throwHistory`, `gameConfig`, `durationSeconds`, `earnedFeatsByIndex` to `recordGame`.

**Shared pattern (apply per file):**

```dart
// 1. capture unlocks
final unlocks = AchievementService.instance.awardGameEnd(/* existing args */);
// 2. build feats (import ../utils/earned_feats_builder.dart)
final earnedFeats = buildEarnedFeats(
  eventsByIndex: events,         // the per-index events the screen already built
  unlocksByIndex: unlocks,
);
// 3. pass to recordGame (import ../models/dart_throw.dart not needed; throwHistory is in scope)
StatsRecorder.recordGame(
  // ... existing args ...
  gameConfig: <mode config string>,
  durationSeconds: <elapsed seconds or null>,
  throwHistory: List<DartThrow>.from(throwHistory),
  earnedFeatsByIndex: earnedFeats,
);
```

**Duration:** if a cockpit has no start timestamp, pass `null` (banner hides duration). Add a `final DateTime _gameStart = DateTime.now();` field initialized in `initState` only where trivial; otherwise leave `null` this round.

**gameConfig strings:**
- X01: `'${config.startingScore}${config.doubleOut ? " · Dobbel ut" : ""}'` (use the real config getters; check `lib/models/game_config.dart`).
- Cricket: `'Cricket'`.
- Killer: `'Killer · ${config.startingLives} liv'` (use real getter).
- Shanghai: `'Shanghai'`.
- ATC: `'Around the Clock'`.
- Splitscore: `'Splitscore'`.

> For each cockpit, verify the config getter names against the mode's config subclass before writing the string.

- [ ] **Task 8 — X01** (`lib/screens/game_screen.dart`): in `_awardMilestones` capture the return, build feats, and thread `earnedFeats` out to where `StatsRecorder.recordGame` is called (~725). Note `events` is local to `_awardMilestones` — return `earnedFeats` from it or hoist the call. Commit: `feat(history): X01 captures throwHistory + feats`.
- [ ] **Task 9 — Cricket** (`lib/screens/cricket_game_screen.dart` ~584-614). Commit: `feat(history): Cricket captures throwHistory + feats`.
- [ ] **Task 10 — Killer** (`lib/screens/killer_game_screen.dart` ~726-767). Commit: `feat(history): Killer captures throwHistory + feats`.
- [ ] **Task 11 — Shanghai** (`lib/screens/shanghai_game_screen.dart` ~300-331). Commit: `feat(history): Shanghai captures throwHistory + feats`.
- [ ] **Task 12 — ATC** (`lib/screens/around_the_clock_game_screen.dart` ~949-988). Commit: `feat(history): ATC captures throwHistory + feats`.
- [ ] **Task 13 — Splitscore** (`lib/screens/halve_it_game_screen.dart` ~527-569). Commit: `feat(history): Splitscore captures throwHistory + feats`.

For each: after editing, run `flutter analyze <file>` (expect no issues) and `flutter test` (existing tests still pass). There is no unit test per cockpit; correctness is verified end-to-end in Task 24.

---

## PHASE 2 — Derivation logic (pure, tested)

### Task 14: ModeProgression interface + X01

**Files:**
- Create: `lib/stats/mode_progression.dart`
- Test: `test/stats/mode_progression_x01_test.dart`

A progression maps a player's throws → one point per round (the value to plot), plus axis metadata.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/stats/mode_progression.dart';

DartThrow _t(int seg, int mul, {required int round, required int sst}) => DartThrow(
    playerIndex: 0, segment: seg, multiplier: mul, points: seg * mul,
    scoreBefore: sst, turnNumber: 0, scoreAtStartOfTurn: sst,
    turnId: round, roundNumber: round);

void main() {
  test('X01 progression is remaining score per round, racing to 0', () {
    final throws = [
      _t(20, 3, round: 1, sst: 501), // 441 left after R1
      _t(20, 3, round: 2, sst: 441), // 381 left after R2
    ];
    final p = X01Progression(startScore: 501);
    final series = p.seriesFor(throws, playerIndex: 0);
    expect(series.first, 501);     // start point
    expect(series, [501, 441, 381]);
    expect(p.descending, isTrue);
    expect(p.maxValue, 501);
  });
}
```

- [ ] **Step 2: Run test, verify it fails** → FAIL (missing).

- [ ] **Step 3: Create the interface + X01 impl**

```dart
import '../models/dart_throw.dart';

/// Maps a player's throws to one value per round for the SPILLFORLØP chart.
abstract class ModeProgression {
  /// Plotted values, index 0 = start, then one per completed round.
  List<num> seriesFor(List<DartThrow> throws, {required int playerIndex});
  num get maxValue;          // axis top
  bool get descending;       // true = race to 0 (X01/Killer), false = climb
  String get finishLabel;    // e.g. "✓ UT"
}

class X01Progression implements ModeProgression {
  X01Progression({required this.startScore});
  final int startScore;

  @override
  List<num> seriesFor(List<DartThrow> throws, {required int playerIndex}) {
    final mine = throws.where((t) => t.playerIndex == playerIndex).toList();
    final byRound = <int, List<DartThrow>>{};
    for (final t in mine) {
      (byRound[t.roundNumber] ??= []).add(t);
    }
    final rounds = byRound.keys.toList()..sort();
    final out = <num>[startScore];
    var remaining = startScore;
    for (final r in rounds) {
      final turn = byRound[r]!;
      if (turn.any((t) => t.isBust)) {
        out.add(remaining); // busted round: no change
      } else {
        remaining -= turn.fold<int>(0, (s, t) => s + t.points);
        out.add(remaining);
      }
    }
    return out;
  }

  @override
  num get maxValue => startScore;
  @override
  bool get descending => true;
  @override
  String get finishLabel => '✓ UT';
}
```

- [ ] **Step 4: Run test, verify it passes** → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/stats/mode_progression.dart test/stats/mode_progression_x01_test.dart
git commit -m "feat(stats): ModeProgression interface + X01 (race to 0)"
```

---

### Task 15: Progressions for the other 5 modes

**Files:**
- Modify: `lib/stats/mode_progression.dart`
- Test: `test/stats/mode_progression_others_test.dart`

Implement (each `seriesFor` groups throws by `roundNumber`, climbing unless noted):
- `CricketProgression` — cumulative points per round (`descending=false`, `maxValue` = max final score across the leg or a fixed cap; pass via ctor). Marks-based MPR optional; points is the natural race.
- `KillerProgression(startLives)` — lives remaining per round (`descending=true`); derive from throws is hard (lives depend on hits on own/opponent numbers), so **accept a precomputed per-round lives series via ctor** if throws alone are insufficient — see note below.
- `AtcProgression` — highest target reached per round (`descending=false`, `maxValue=20`).
- `ShanghaiProgression` — cumulative score per round (`descending=false`).
- `SplitscoreProgression` — running total per round; can DROP when halved (`descending=false`, non-monotonic).

> **Killer/Splitscore note:** lives and halving are engine/scoreboard state, not directly in `DartThrow`. For this round, derive what is derivable from throws; where a mode's true race needs engine state, plot the simplest faithful proxy (Killer: count of own-number hits as a lives proxy is wrong — instead, for Killer, plot **darts-on-target per round** and label the axis accordingly, OR defer Killer's chart to the round log only and show the empty-state chart line). Decide per mode during implementation and `log()` the choice in the PR description. The round log (Task 19/20) is always available for every mode regardless.

- [ ] **Step 1-4:** Write one test per mode (cumulative climb assertions analogous to Task 14), implement, verify pass.
- [ ] **Step 5: Commit** `feat(stats): progressions for cricket/killer/atc/shanghai/splitscore`.

---

### Task 16: Per-player grid stats from throwHistory

**Files:**
- Create: `lib/stats/game_detail_stats.dart`
- Test: `test/stats/game_detail_stats_test.dart`

Pure function: given a player's throws (X01), compute `{avg3, bestTurn, n180, n140, doublesPct, darts, checkoutCombo}`. For non-X01, return what their counters support. Fallback to stored `GameHistoryPlayer.stats` when `throwHistory == null`.

- [ ] **Step 1: Write the failing test** (X01):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/stats/game_detail_stats.dart';

void main() {
  test('X01 per-player grid derives avg/best/180/darts', () {
    // One 180 turn (T20 x3), then a 100 turn.
    final throws = <DartThrow>[
      for (var d = 0; d < 3; d++)
        DartThrow(playerIndex: 0, segment: 20, multiplier: 3, points: 60,
            scoreBefore: 501, turnNumber: d, scoreAtStartOfTurn: 501,
            turnId: 1, roundNumber: 1),
      for (var d = 0; d < 3; d++)
        DartThrow(playerIndex: 0, segment: 20, multiplier: d == 0 ? 2 : 1,
            points: d == 0 ? 40 : 20, scoreBefore: 321, turnNumber: d,
            scoreAtStartOfTurn: 321, turnId: 2, roundNumber: 2),
    ];
    final g = x01GridStats(throws, playerIndex: 0);
    expect(g.n180, 1);
    expect(g.bestTurn, 180);
    expect(g.darts, 6);
    expect(g.avg3, closeTo(140.0, 0.1)); // (180+100)/2 turns
    expect(g.doublesHit, 1);
  });
}
```

- [ ] **Step 2-4:** Implement `x01GridStats` (group by turnId, skip busts, sum/max/count). Define a small `GridStats` data class with the fields above. Verify pass.
- [ ] **Step 5: Commit** `feat(stats): per-player grid stats from throwHistory`.

---

## PHASE 3 — UI

> Visual reference: `DOSSEDART (4).zip → game-detail.jsx` (the artboards) is the source of truth for layout, spacing, and the exact arcade styling. Recreate with Flutter widgets + `DossedartTokens`; do not copy pixel values blindly — match the existing DOSSEDART cockpit/stats widgets' idioms. Colors: cyan=you, gold/silver/bronze=placement/tier, green/red=ΔELO, triple=cyan/double=magenta on dart chips.

### Task 17: GameDetailScreen scaffold (header + banner + standings)

**Files:**
- Create: `lib/screens/dossedart/game_detail_screen.dart`
- Test: `test/screens/game_detail_screen_test.dart`

- [ ] **Step 1: Write a widget test** that pumps `GameDetailScreen(entry: <x01 entry with 2 players>)` and asserts: title `KAMPDETALJER` present, both player names present, the winner's ΔELO shown, banner shows `gameConfig`.

```dart
testWidgets('renders standings + banner', (tester) async {
  final entry = /* build an X01 GameHistoryEntry with 2 players + ratings */;
  await tester.pumpWidget(MaterialApp(home: GameDetailScreen(entry: entry)));
  expect(find.text('KAMPDETALJER'), findsOneWidget);
  expect(find.text('Jonas'), findsWidgets);
  expect(find.textContaining('501'), findsWidgets); // banner config
});
```

- [ ] **Step 2: Run, verify it fails** → FAIL (missing).
- [ ] **Step 3: Implement** the screen scaffold: `Scaffold` with the DOSSEDART arcade chrome (reuse whatever the stats screen / cockpit uses — check `dossedart_stats_screen.dart` and `dossedart_crt_frame.dart`), a back button (`◀ HISTORIKK`), centered yellow `KAMPDETALJER`, `DEL ↗`. Then the banner (`gameConfig`, date, `VARIGHET·RUNDER·VINNER` from `durationSeconds`/`entry.rounds`/winner) and a `SLUTTSTILLING` section: one row per player sorted by `placement` — placement number (gold/silver/bronze via `DossedartTokens`), avatar (cyan if `you`), name, one-line summary (winner: checkout; else darts+avg), ΔELO with before→after. Build with small private widgets (`_StandingRow`, `_Banner`).
- [ ] **Step 4: Run, verify it passes** → PASS.
- [ ] **Step 5: Commit** `feat(stats): GameDetailScreen scaffold + standings`.

### Task 18: PRESTASJONER DENNE KAMPEN (feat chips)

- [ ] 2-col grid of `_FeatChip` from each player's `earnedFeats` (hexagon tinted by `tier`, `★` for `FeatKind.unlock` / `✦` for `feat`, player name + label + note). Reuse `achievement_medal.dart` styling idioms. Widget test: a player with one feat renders its label. Commit `feat(stats): earned-feats section`.

### Task 19: SPILLFORLØP chart

- [ ] `_LegProgressChart` `CustomPaint`: pick the `ModeProgression` for `entry.gameMode`, plot `seriesFor` per player (cyan=you, silver=opponent), gridlines, x-labels (START/R1…), finish flag when a series reaches 0 (descending modes). Widget/golden-free test: instantiate the painter and assert it builds without throwing for a 2-player X01 entry. Commit `feat(stats): leg-progression chart`.

### Task 20: Round log

- [ ] `_RoundLog`: group `throwHistory` by `roundNumber`; per round, per player show 3 `_ThrowChip` (`shortLabel`; triple=cyan/double=magenta/single=dim), round total (180 highlighted yellow), remaining/state. `VIS ALLE N RUNDER ›` expander (collapsed to ~5 rounds initially). Widget test asserts round 1 chips render. Commit `feat(stats): round-by-round throw log`.

### Task 21: PER SPILLER grid

- [ ] `_StatGrid`: rows = labels from `game_detail_stats.dart`; columns per player; highlight the better value green per comparable row. For old games (no throwHistory) fall back to `GameHistoryPlayer.stats`, `—` where missing. Widget test: two players, better avg is green. Commit `feat(stats): per-player comparison grid`.

### Task 22: Empty state for pre-throwHistory games

- [ ] When `entry.throwHistory == null`: render banner + standings + per-player(from stored stats) + feats(if any), and replace chart+round-log with a single line "forløp ikke lagret for denne kampen". Widget test: an entry with `throwHistory: null` shows the line and no chart. Commit `feat(stats): empty state for old matches`.

### Task 23: Make HISTORIKK rows tappable

**Files:**
- Modify: `lib/screens/dossedart/dossedart_stats_screen.dart` (`_buildHistorikk` ~311-315, `_HistoryRow` ~670)

- [ ] **Step 1:** Wrap the row in `_buildHistorikk` with an `InkWell`/`GestureDetector`:
```dart
itemBuilder: (ctx, i) => GestureDetector(
  behavior: HitTestBehavior.opaque,
  onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
      builder: (_) => GameDetailScreen(entry: sorted[i]))),
  child: _HistoryRow(entry: sorted[i]),
),
```
(import `game_detail_screen.dart`.)
- [ ] **Step 2:** Restyle `_HistoryRow` to add a trailing `DETALJER ›` affordance (and, if not already present, top-3 mini standings + your ΔELO per the spec). Keep within existing chrome.
- [ ] **Step 3:** Widget test: tapping a row pushes `GameDetailScreen`.
- [ ] **Step 4:** `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(stats): tappable history rows → KAMPDETALJER`.

### Task 24: Manual verification on tablet

- [ ] Run on the Galaxy Tab emulator (`project_emulator_target_device`). Play one short X01 game to completion → open HISTORIKK → tap the new game → verify banner, standings, feats, progression chart, round log, per-player grid. Tap an OLD game → verify empty-state line. Spot-check one non-X01 mode (e.g. Cricket) end-to-end. No commit (verification only); note findings.

---

## Self-review notes

- **Spec coverage:** model change (T1-T5) ✓; capture all 6 modes (T6-T13) ✓; per-mode progression (T14-T15) ✓; per-player grid + fallback (T16, T21) ✓; tappable rows (T23) ✓; detail sections banner/standings/feats/chart/log/grid (T17-T21) ✓; empty state (T22) ✓; retention (T5) ✓; tests throughout ✓.
- **Known soft spots flagged inline:** Killer/Splitscore progression can't be fully derived from `DartThrow` alone (T15 note) — implementer picks a faithful proxy or defers that mode's chart to the round log; the round log + standings + feats + grid still work for every mode. Package name (`dart_scoring`) and `SavedPlayer`/config-getter names must be confirmed against the codebase before writing literal references.
- **Type consistency:** `EarnedFeat`, `FeatKind`, `ModeProgression.seriesFor`, `GridStats`, `buildEarnedFeats`, `awardGameEnd → Map<int,List<Achievement>>` used consistently across tasks.
