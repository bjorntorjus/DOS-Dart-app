# Achievements Phase 1 — Framework + Storage + Retro (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use `- [ ]`.

**Goal:** The achievement framework — definition model, evaluation service (event / milestone / silent-retro), and `SavedPlayer` persistence — with zero badges wired yet, fully unit-tested with fakes.

**Architecture:** Pure-data `Achievement` definitions each carry either a `milestoneTest` predicate (evaluated at game-end + retro) or an `AchievementEvent` key (fired live in-game). `AchievementService` (singleton) routes the two, persists unlocks on `SavedPlayer`, and emits an `AchievementUnlock` stream the banner will consume. Retro evaluates milestone predicates with a null `GameOutcome`; per-game predicates null-check the outcome and return false, so retro only grants career-provable badges silently.

**Tech Stack:** Dart, Flutter, `flutter_test`. Package: `dart_scoring`.

**Spec:** `docs/superpowers/specs/2026-06-09-achievements-design.md`

---

### Task 1: Achievement definition model

**Files:**
- Create: `lib/models/achievement.dart`
- Create: `lib/models/achievement_event.dart`
- Create: `lib/models/game_outcome.dart`
- Test: `test/models/achievement_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/achievement.dart';

void main() {
  test('glyph holds an icon or an asset, not both', () {
    const g = AchievementGlyph.icon(Icons.star);
    expect(g.isAsset, isFalse);
    expect(g.icon, Icons.star);
    const a = AchievementGlyph.asset('assets/badges/x.png');
    expect(a.isAsset, isTrue);
    expect(a.assetPath, 'assets/badges/x.png');
  });

  test('milestone achievement carries a predicate, event is null', () {
    final ach = Achievement(
      id: 'test_volume',
      name: 'REGULAR',
      description: 'Play 25 games',
      tier: AchievementTier.silver,
      category: AchievementCategory.milestone,
      glyph: const AchievementGlyph.icon(Icons.videogame_asset),
      milestoneTest: (ctx) => ctx.player.gamesPlayed >= 25,
    );
    expect(ach.event, isNull);
    expect(ach.milestoneTest, isNotNull);
    expect(ach.mode, isNull); // cross-cutting
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/models/achievement_test.dart`
Expected: FAIL — `achievement.dart` not found.

- [ ] **Step 3: Implement the models**

`lib/models/achievement_event.dart`:
```dart
/// In-game moments that can unlock an event-type achievement. Fired from the
/// same points in game screens that already trigger sound/meme. Expanded in the
/// per-mode phases; this is the starter set.
enum AchievementEvent {
  // X01
  score180,
  bigCheckout,        // checkout >= 100
  bullFinish,
  // Cricket
  nineMarkTurn,
  // Shanghai
  instantShanghai,
  // Killer
  becameKiller,
  multiKill,
  // Splitscore
  clutchSave,
  // Cross-cutting / meme
  nice69,
  sixSeven,
  threeMisses,
}
```

`lib/models/game_outcome.dart`:
```dart
import 'game_mode.dart';

/// Per-game result handed to milestone evaluation at game-end. Career stats
/// live on SavedPlayer; this carries only this-game data + per-game flags.
class GameOutcome {
  final GameMode mode;
  final bool won;
  final int placement;          // 1-based
  final int playerCount;
  final double ratingBefore;
  final double ratingAfter;
  final List<double> opponentRatingsBefore;
  /// Per-game flags/counters computed at record time (e.g. 'bustCount',
  /// 'maxDeficitBehind', 'wireToWire', 'instantShanghai'). Per-mode phases fill this.
  final Map<String, int> gameCounters;

  const GameOutcome({
    required this.mode,
    required this.won,
    required this.placement,
    required this.playerCount,
    required this.ratingBefore,
    required this.ratingAfter,
    this.opponentRatingsBefore = const [],
    this.gameCounters = const {},
  });

  int counter(String key) => gameCounters[key] ?? 0;
}
```

`lib/models/achievement.dart`:
```dart
import 'package:flutter/widgets.dart';
import 'achievement_event.dart';
import 'game_outcome.dart';
import 'saved_player.dart';

enum AchievementTier { bronze, silver, gold }

enum AchievementCategory { scoring, milestone, streak, social, quirky }

/// A medal glyph: a Material icon today, swappable to a custom asset later
/// without touching the medal widget or call sites (spec decision #7).
class AchievementGlyph {
  final IconData? icon;
  final String? assetPath;
  const AchievementGlyph.icon(this.icon) : assetPath = null;
  const AchievementGlyph.asset(this.assetPath) : icon = null;
  bool get isAsset => assetPath != null;
}

/// Context for a milestone predicate. [outcome] is null during silent retro —
/// per-game predicates MUST null-check it and return false, so retro only ever
/// grants career-provable badges.
class AchievementContext {
  final SavedPlayer player;
  final GameOutcome? outcome;
  const AchievementContext({required this.player, this.outcome});
}

typedef MilestoneTest = bool Function(AchievementContext ctx);

class Achievement {
  final String id;
  final String name;        // globally unique (spec decision #1)
  final String description;
  final AchievementTier tier;
  final AchievementCategory category;
  final AchievementGlyph glyph;
  final String? mode;       // GameMode.name, or null for cross-cutting
  final MilestoneTest? milestoneTest; // threshold/career/per-game; null for pure events
  final AchievementEvent? event;      // in-game event; null for milestones

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.tier,
    required this.category,
    required this.glyph,
    this.mode,
    this.milestoneTest,
    this.event,
  });
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/models/achievement_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/achievement.dart lib/models/achievement_event.dart lib/models/game_outcome.dart test/models/achievement_test.dart
git commit -m "feat(achievements): definition model, event enum, game outcome"
```

---

### Task 2: Extend SavedPlayer with unlock storage + tracking fields

**Files:**
- Modify: `lib/models/saved_player.dart` (fields + toJson + fromJson)
- Test: `test/models/saved_player_achievements_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/saved_player.dart';

void main() {
  test('achievement fields round-trip through JSON', () {
    final p = SavedPlayer(id: '1', name: 'Ada', createdAt: DateTime(2020))
      ..unlockedAchievementIds.add('x01_maximum')
      ..achievementUnlockedAt['x01_maximum'] = DateTime(2026, 6, 9)
      ..achievementsRetroGranted = true
      ..currentWinStreak = 3
      ..bestWinStreak = 7
      ..currentLossStreak = 0;
    final back = SavedPlayer.fromJson(p.toJson());
    expect(back.unlockedAchievementIds, contains('x01_maximum'));
    expect(back.achievementUnlockedAt['x01_maximum'], DateTime(2026, 6, 9));
    expect(back.achievementsRetroGranted, isTrue);
    expect(back.currentWinStreak, 3);
    expect(back.bestWinStreak, 7);
  });

  test('defaults are empty/zero for a fresh player', () {
    final p = SavedPlayer(id: '1', name: 'Ada', createdAt: DateTime(2020));
    expect(p.unlockedAchievementIds, isEmpty);
    expect(p.achievementsRetroGranted, isFalse);
    expect(p.currentWinStreak, 0);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/models/saved_player_achievements_test.dart`
Expected: FAIL — `unlockedAchievementIds` undefined.

- [ ] **Step 3: Add fields + serialization to `SavedPlayer`**

Add these fields to the `SavedPlayer` class body (after `gamesLeftMidway`):
```dart
  Set<String> unlockedAchievementIds;
  Map<String, DateTime> achievementUnlockedAt;
  bool achievementsRetroGranted;
  int currentWinStreak;
  int bestWinStreak;
  int currentLossStreak;
```
Add to the constructor parameter list (with defaults) before the `: modeStats` initializer:
```dart
    Set<String>? unlockedAchievementIds,
    Map<String, DateTime>? achievementUnlockedAt,
    this.achievementsRetroGranted = false,
    this.currentWinStreak = 0,
    this.bestWinStreak = 0,
    this.currentLossStreak = 0,
```
and in the initializer list:
```dart
        unlockedAchievementIds = unlockedAchievementIds ?? {},
        achievementUnlockedAt = achievementUnlockedAt ?? {},
```
Add to `toJson()` map:
```dart
        'unlockedAchievementIds': unlockedAchievementIds.toList(),
        'achievementUnlockedAt': achievementUnlockedAt
            .map((k, v) => MapEntry(k, v.toIso8601String())),
        'achievementsRetroGranted': achievementsRetroGranted,
        'currentWinStreak': currentWinStreak,
        'bestWinStreak': bestWinStreak,
        'currentLossStreak': currentLossStreak,
```
Add to `fromJson` constructor call:
```dart
        unlockedAchievementIds:
            (json['unlockedAchievementIds'] as List<dynamic>?)
                    ?.map((e) => e as String)
                    .toSet() ??
                {},
        achievementUnlockedAt:
            (json['achievementUnlockedAt'] as Map<String, dynamic>?)?.map(
                  (k, v) => MapEntry(k, DateTime.parse(v as String)),
                ) ??
                {},
        achievementsRetroGranted:
            json['achievementsRetroGranted'] as bool? ?? false,
        currentWinStreak: json['currentWinStreak'] as int? ?? 0,
        bestWinStreak: json['bestWinStreak'] as int? ?? 0,
        currentLossStreak: json['currentLossStreak'] as int? ?? 0,
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/models/saved_player_achievements_test.dart`
Expected: PASS. Also run the existing `flutter test` to confirm no regressions.

- [ ] **Step 5: Commit**

```bash
git add lib/models/saved_player.dart test/models/saved_player_achievements_test.dart
git commit -m "feat(achievements): SavedPlayer unlock storage + streak fields"
```

---

### Task 3: AchievementService (event / milestone / silent retro)

**Files:**
- Create: `lib/services/achievement_service.dart`
- Test: `test/services/achievement_service_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/achievement.dart';
import 'package:dart_scoring/models/achievement_event.dart';
import 'package:dart_scoring/models/game_mode.dart';
import 'package:dart_scoring/models/game_outcome.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/achievement_service.dart';

Achievement _milestone(String id, MilestoneTest t) => Achievement(
      id: id, name: id.toUpperCase(), description: '', tier: AchievementTier.bronze,
      category: AchievementCategory.milestone,
      glyph: const AchievementGlyph.icon(Icons.star), milestoneTest: t);

Achievement _event(String id, AchievementEvent e) => Achievement(
      id: id, name: id.toUpperCase(), description: '', tier: AchievementTier.gold,
      category: AchievementCategory.scoring,
      glyph: const AchievementGlyph.icon(Icons.star), event: e);

GameOutcome _outcome({bool won = true, Map<String, int> c = const {}}) => GameOutcome(
      mode: GameMode.x01, won: won, placement: won ? 1 : 2, playerCount: 2,
      ratingBefore: 1200, ratingAfter: 1210, gameCounters: c);

void main() {
  late SavedPlayer player;
  setUp(() => player = SavedPlayer(id: '1', name: 'Ada', createdAt: DateTime(2020)));

  test('milestone unlocks once and is idempotent', () {
    final svc = AchievementService.forTest([
      _milestone('played1', (ctx) => ctx.player.gamesPlayed >= 1),
    ]);
    player.gamesPlayed = 1;
    expect(svc.evaluateMilestones(player, _outcome()).map((a) => a.id), ['played1']);
    // second eval: already unlocked, nothing new
    expect(svc.evaluateMilestones(player, _outcome()), isEmpty);
    expect(player.unlockedAchievementIds, contains('played1'));
  });

  test('event unlocks matching event badges and emits on the stream', () async {
    final svc = AchievementService.forTest([_event('max', AchievementEvent.score180)]);
    final emitted = <String>[];
    svc.unlocks.listen((u) => emitted.add(u.achievement.id));
    final newly = svc.checkEvent(AchievementEvent.score180, player);
    expect(newly.map((a) => a.id), ['max']);
    await Future<void>.delayed(Duration.zero);
    expect(emitted, ['max']);
  });

  test('retro grants career badges silently, skips per-game predicates', () async {
    final svc = AchievementService.forTest([
      _milestone('career', (ctx) => ctx.player.gamesWon >= 1),
      _milestone('pergame', (ctx) {
        final o = ctx.outcome;
        if (o == null) return false; // per-game: not retro-grantable
        return o.won;
      }),
    ]);
    player.gamesWon = 1;
    final emitted = <String>[];
    svc.unlocks.listen((u) => emitted.add(u.achievement.id));
    svc.retroGrantSilently(player);
    expect(player.unlockedAchievementIds, contains('career'));
    expect(player.unlockedAchievementIds, isNot(contains('pergame')));
    expect(player.achievementsRetroGranted, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(emitted, isEmpty); // silent — no banner
    // running again is a no-op (guard)
    svc.retroGrantSilently(player);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/services/achievement_service_test.dart`
Expected: FAIL — `achievement_service.dart` not found.

- [ ] **Step 3: Implement the service**

`lib/services/achievement_service.dart`:
```dart
import 'dart:async';
import '../models/achievement.dart';
import '../models/achievement_event.dart';
import '../models/game_outcome.dart';
import '../models/saved_player.dart';

class AchievementUnlock {
  final SavedPlayer player;
  final Achievement achievement;
  const AchievementUnlock(this.player, this.achievement);
}

/// Routes the two unlock paths (live in-game events vs game-end milestones),
/// persists unlocks on the SavedPlayer, and emits a stream the banner consumes.
/// Persistence of the mutated player is the caller's responsibility (the game
/// screen already saves the player after recording stats).
class AchievementService {
  AchievementService._(this._catalog);
  static final AchievementService instance = AchievementService._(const []);

  /// Test constructor with an explicit catalog and a private stream.
  factory AchievementService.forTest(List<Achievement> catalog) =>
      AchievementService._(catalog);

  List<Achievement> _catalog;
  void registerCatalog(List<Achievement> catalog) => _catalog = catalog;

  final _unlockController = StreamController<AchievementUnlock>.broadcast();
  Stream<AchievementUnlock> get unlocks => _unlockController.stream;

  bool _unlock(SavedPlayer player, Achievement a, {required bool emit}) {
    if (player.unlockedAchievementIds.contains(a.id)) return false;
    player.unlockedAchievementIds.add(a.id);
    player.achievementUnlockedAt[a.id] = DateTime.now();
    if (emit) _unlockController.add(AchievementUnlock(player, a));
    return true;
  }

  /// Live in-game event → unlock matching event badges, emit banner.
  List<Achievement> checkEvent(AchievementEvent event, SavedPlayer player) {
    final newly = <Achievement>[];
    for (final a in _catalog) {
      if (a.event == event && _unlock(player, a, emit: true)) newly.add(a);
    }
    return newly;
  }

  /// Game-end milestone evaluation against the updated player + outcome.
  List<Achievement> evaluateMilestones(SavedPlayer player, GameOutcome outcome) {
    final ctx = AchievementContext(player: player, outcome: outcome);
    final newly = <Achievement>[];
    for (final a in _catalog) {
      if (a.milestoneTest != null &&
          a.milestoneTest!(ctx) &&
          _unlock(player, a, emit: true)) {
        newly.add(a);
      }
    }
    return newly;
  }

  /// One-time silent retro grant: unlock career-provable milestone badges with
  /// no banner. Per-game predicates see a null outcome and return false.
  void retroGrantSilently(SavedPlayer player) {
    if (player.achievementsRetroGranted) return;
    final ctx = AchievementContext(player: player, outcome: null);
    for (final a in _catalog) {
      if (a.milestoneTest != null && a.milestoneTest!(ctx)) {
        _unlock(player, a, emit: false);
      }
    }
    player.achievementsRetroGranted = true;
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/services/achievement_service_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/achievement_service.dart test/services/achievement_service_test.dart
git commit -m "feat(achievements): evaluation service (event/milestone/silent-retro)"
```

---

## Self-Review

- **Spec coverage (Phase 1 slice):** model + glyph (Task 1) ✓; storage + tracking fields (Task 2) ✓; service with 3 entry points (Task 3) ✓; one-time idempotency ✓; silent retro ✓. UI, catalog, wiring, per-mode tracking = later phases (own plans).
- **Type consistency:** `AchievementContext`, `MilestoneTest`, `GameOutcome`, `AchievementEvent`, `AchievementUnlock` used identically across tasks. `forTest` vs `instance` both call private `_(catalog)`.
- **Placeholder scan:** none.
- **Note:** `Date.now()` is fine in app code (the workflow-script ban does not apply here).
