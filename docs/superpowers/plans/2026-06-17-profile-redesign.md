# Spillerprofil — utvidet PROFIL-fane Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add four new sections to the DOSSEDART PROFIL tab — Form (recent results), Streaks & rating peak, Records/PB, and per-mode depth — plus a nemesis marker, all from data already stored.

**Architecture:** Pure derivation functions in a new `lib/stats/profile_stats.dart` (unit-tested), consumed by new private widgets added to `DossedartStatsScreen._buildProfil()`. No new storage, no recorder changes. Colours from `DossedartTokens` only.

**Tech Stack:** Flutter (Dart), `flutter_test`. Reuses `SavedPlayer`/`ModeStats`/`GameHistoryEntry`.

**Spec:** `docs/superpowers/specs/2026-06-17-profile-redesign-design.md`
**Mockup:** `docs/design/profile-redesign/dossedart-profile-mockup.html`

**Decision (locked):** ATC record = treff-rate (not fastest-finish); Killer record = career kills. No counter changes this round.

**Test command:** `flutter test test/<file>_test.dart` (single: append `--plain-name "<name>"`).

---

## PHASE 0 — Pure derivations (tested)

### Task 1: Recent form

**Files:**
- Create: `lib/stats/profile_stats.dart`
- Test: `test/stats/profile_stats_form_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/stats/profile_stats.dart';

GameHistoryEntry _g(String id, DateTime d, List<(String pid, int place, double db, double da)> ps) =>
    GameHistoryEntry(
      id: id, gameMode: 'x01', date: d,
      players: [
        for (final (pid, place, db, da) in ps)
          GameHistoryPlayer(
              name: pid, savedPlayerId: pid, placement: place,
              stats: const {}, ratingBefore: db, ratingAfter: da),
      ],
    );

void main() {
  test('recentForm returns newest-first W/L/draw with ΔELO', () {
    final history = [
      _g('1', DateTime(2026, 1, 1), [('me', 1, 1000, 1010), ('x', 2, 1000, 990)]),
      _g('2', DateTime(2026, 1, 2), [('me', 2, 1010, 1003), ('x', 1, 990, 998)]),
      _g('3', DateTime(2026, 1, 3), [('me', 1, 1003, 1003), ('x', 1, 998, 998)]), // shared 1st = draw
    ];
    final form = recentForm(history, 'me', limit: 8);
    expect(form.map((f) => f.outcome).toList(),
        [FormOutcome.draw, FormOutcome.loss, FormOutcome.win]); // newest first
    expect(form.first.ratingDelta, 0); // 1003→1003
    expect(form.last.ratingDelta, 10); // 1000→1010
  });

  test('recentForm skips games the player did not play and honours limit', () {
    final history = [
      for (var i = 0; i < 12; i++)
        _g('$i', DateTime(2026, 1, 1).add(Duration(days: i)),
            [('me', 1, 1000, 1005), ('x', 2, 1000, 995)]),
      _g('z', DateTime(2026, 2, 1), [('other', 1, 1000, 1005)]), // me absent
    ];
    final form = recentForm(history, 'me', limit: 8);
    expect(form.length, 8);
    expect(form.every((f) => f.outcome == FormOutcome.win), isTrue);
  });
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `flutter test test/stats/profile_stats_form_test.dart`
Expected: FAIL — `profile_stats.dart` / `recentForm` missing.

- [ ] **Step 3: Create `lib/stats/profile_stats.dart`**

```dart
import '../models/game_history.dart';
import '../models/saved_player.dart';

enum FormOutcome { win, loss, draw }

class FormResult {
  final FormOutcome outcome;
  final double? ratingDelta;
  final String gameMode;
  const FormResult(
      {required this.outcome, this.ratingDelta, required this.gameMode});
}

/// The player's most-recent [limit] games (newest first). A game is a win when
/// the player has the sole best placement, a draw when the best placement is
/// shared, otherwise a loss.
List<FormResult> recentForm(
    List<GameHistoryEntry> history, String savedPlayerId,
    {int limit = 8}) {
  final sorted = [...history]..sort((a, b) => b.date.compareTo(a.date));
  final out = <FormResult>[];
  for (final e in sorted) {
    final me =
        e.players.where((p) => p.savedPlayerId == savedPlayerId).firstOrNull;
    if (me == null) continue;
    final best = e.players.map((p) => p.placement).reduce((a, b) => a < b ? a : b);
    final sharedBest = e.players.where((p) => p.placement == best).length > 1;
    final FormOutcome o;
    if (me.placement == best && !sharedBest) {
      o = FormOutcome.win;
    } else if (me.placement == best) {
      o = FormOutcome.draw;
    } else {
      o = FormOutcome.loss;
    }
    out.add(FormResult(
        outcome: o, ratingDelta: me.ratingDelta, gameMode: e.gameMode));
    if (out.length >= limit) break;
  }
  return out;
}
```

- [ ] **Step 4: Run test, verify it passes** → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/stats/profile_stats.dart test/stats/profile_stats_form_test.dart
git commit -m "feat(profile): recent-form derivation from game history"
```

---

### Task 2: Records, rating peak, best rank, nemesis

**Files:**
- Modify: `lib/stats/profile_stats.dart`
- Test: `test/stats/profile_stats_records_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/stats/profile_stats.dart';

SavedPlayer _p() => SavedPlayer(
      id: 'p', name: 'P', createdAt: DateTime(2026),
      ratingHistory: [
        RatingSnapshot(date: DateTime(2026, 1, 1), rating: 1200, placement: 3),
        RatingSnapshot(date: DateTime(2026, 1, 2), rating: 1361, placement: 1),
        RatingSnapshot(date: DateTime(2026, 1, 3), rating: 1342, placement: 2),
      ],
      modeStats: {
        'x01': ModeStats(played: 50, won: 34, counters: {
          'highestTurn': 180, 'bestCheckout': 121, 'totalTurnScore': 2920,
          'totalTurns': 50, 'turnsOver100': 12,
        }),
        'aroundTheClock': ModeStats(played: 8, won: 4, counters: {
          'totalHits': 92, 'totalDarts': 100,
        }),
      },
      headToHead: {
        'amund': H2HRecord(wins: 14, losses: 9),
        'stian': H2HRecord(wins: 8, losses: 11), // deficit 3 → nemesis
        'bo': H2HRecord(wins: 6, losses: 3),
      },
    );

void main() {
  test('careerRecords picks max: counters and ATC hit-rate, skips unplayed', () {
    final recs = careerRecords(_p());
    final byLabel = {for (final r in recs) r.label: r};
    expect(byLabel['høyeste runde']!.value, '180');
    expect(byLabel['beste checkout']!.value, '121');
    expect(byLabel['treff-rate']!.value, '92%'); // 92/100
    expect(recs.any((r) => r.mode == 'shanghai'), isFalse); // not played
  });

  test('peakRating, bestRank, nemesis', () {
    final p = _p();
    expect(peakRating(p), 1361);
    expect(bestRank(p), 1);
    expect(nemesisId(p), 'stian'); // largest loss surplus
  });
}
```

- [ ] **Step 2: Run test, verify it fails** → FAIL (functions missing).

- [ ] **Step 3: Append to `lib/stats/profile_stats.dart`**

```dart
class RecordTile {
  final String mode;  // mode key, drives the accent colour at the call site
  final String value; // pre-formatted display value
  final String label; // e.g. 'høyeste runde'
  const RecordTile({required this.mode, required this.value, required this.label});
}

ModeStats? _firstMode(SavedPlayer p, List<String> keys) {
  for (final k in keys) {
    final m = p.modeStats[k];
    if (m != null && m.played > 0) return m;
  }
  return null;
}

/// Career personal bests, one tile per available record. Only emits a tile when
/// the underlying counter exists (> 0) so unplayed modes are skipped.
List<RecordTile> careerRecords(SavedPlayer p) {
  final out = <RecordTile>[];
  final x01 = _firstMode(p, ['x01']);
  if (x01 != null && x01.get('highestTurn') > 0) {
    out.add(RecordTile(mode: 'x01', value: '${x01.get('highestTurn')}', label: 'høyeste runde'));
  }
  if (x01 != null && x01.get('bestCheckout') > 0) {
    out.add(RecordTile(mode: 'x01', value: '${x01.get('bestCheckout')}', label: 'beste checkout'));
  }
  final cri = _firstMode(p, ['cricket', 'cricket_cutthroat']);
  if (cri != null && cri.get('bestPoints') > 0) {
    out.add(RecordTile(mode: 'cricket', value: '${cri.get('bestPoints')}', label: 'beste poeng'));
  }
  final sh = _firstMode(p, ['shanghai']);
  if (sh != null && sh.get('bestScore') > 0) {
    out.add(RecordTile(mode: 'shanghai', value: '${sh.get('bestScore')}', label: 'beste score'));
  }
  final spl = _firstMode(p, ['halveIt']);
  if (spl != null && spl.get('biggestHalving') > 0) {
    out.add(RecordTile(mode: 'halveIt', value: '${spl.get('biggestHalving')}', label: 'største halvering'));
  }
  final kil = _firstMode(p, ['killer']);
  if (kil != null && kil.get('kills') > 0) {
    out.add(RecordTile(mode: 'killer', value: '${kil.get('kills')}', label: 'kills totalt'));
  }
  final atc = _firstMode(p, ['aroundTheClock']);
  if (atc != null && atc.get('totalDarts') > 0) {
    final rate = (atc.get('totalHits') * 100 / atc.get('totalDarts')).round();
    out.add(RecordTile(mode: 'aroundTheClock', value: '$rate%', label: 'treff-rate'));
  }
  return out;
}

double? peakRating(SavedPlayer p) => p.ratingHistory.isEmpty
    ? null
    : p.ratingHistory.map((s) => s.rating).reduce((a, b) => a > b ? a : b);

int? bestRank(SavedPlayer p) {
  final ranks = p.ratingHistory.map((s) => s.placement).whereType<int>();
  return ranks.isEmpty ? null : ranks.reduce((a, b) => a < b ? a : b);
}

/// Opponent the player has the worst record against (most losses over wins).
/// Null when no opponent has a losing surplus.
String? nemesisId(SavedPlayer p) {
  String? worst;
  var worstDeficit = 0;
  p.headToHead.forEach((id, r) {
    final deficit = r.losses - r.wins;
    if (deficit > 0 && deficit > worstDeficit) {
      worstDeficit = deficit;
      worst = id;
    }
  });
  return worst;
}
```

- [ ] **Step 4: Run test, verify it passes** → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/stats/profile_stats.dart test/stats/profile_stats_records_test.dart
git commit -m "feat(profile): records, rating peak, best rank, nemesis derivations"
```

---

## PHASE 1 — PROFIL sections (UI)

All Phase-1 tasks modify `lib/screens/dossedart/dossedart_stats_screen.dart`. Add the
import once (Task 3): `import '../../stats/profile_stats.dart';`. Widget tests use the
existing `test/screens/dossedart_stats_screen_test.dart` patterns (`_seed`, `ArcadeFrame.disableBeamForTest`).

Mode accent colours (define once near the top of the file, Task 6):
```dart
const _modeAccent = <String, Color>{
  'x01': DossedartTokens.yellow,
  'cricket': DossedartTokens.green,
  'cricket_cutthroat': DossedartTokens.green,
  'shanghai': DossedartTokens.cyan,
  'halveIt': DossedartTokens.purple,
  'killer': DossedartTokens.magenta,
  'aroundTheClock': DossedartTokens.orange,
};
```

### Task 3: Hero — add games count + member-since

**Files:**
- Modify: `lib/screens/dossedart/dossedart_stats_screen.dart` (`_ProfileHero` ~515-572, imports ~top)

- [ ] **Step 1: Add the import** at the top of the file (after the existing imports):

```dart
import '../../stats/profile_stats.dart';
```

- [ ] **Step 2: Write the failing test** — add to `test/screens/dossedart_stats_screen_test.dart`:

```dart
  testWidgets('hero shows games count and member-since', (tester) async {
    await _seed([_player('1', 'Ada', 1300)]); // _player sets gamesPlayed: 4
    await tester.pumpWidget(const MaterialApp(home: DossedartStatsScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('4 kamper'), findsOneWidget);
  });
```

- [ ] **Step 3: Run test, verify it fails** → FAIL (text absent).

- [ ] **Step 4: Add a month helper + the line.** In `_ProfileHero.build`, replace the
`RANK #$rank of $total` Text with a Row that also shows games + member-since:

```dart
                Row(
                  children: [
                    Text('RANK #$rank/$total',
                        style: TextStyle(
                            fontFamily: 'PressStart2P', fontSize: 9, color: rankColor)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '· ${player.gamesPlayed} kamper · siden ${_monthAbbr(player.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'VT323', fontSize: 13, color: DossedartTokens.phosphor),
                      ),
                    ),
                  ],
                ),
```

Add this top-level helper near the bottom of the file (file scope, not in a class):

```dart
const _months = [
  'jan', 'feb', 'mar', 'apr', 'mai', 'jun',
  'jul', 'aug', 'sep', 'okt', 'nov', 'des'
];
String _monthAbbr(DateTime d) => "${_months[d.month - 1]} '${d.year % 100}";
```

- [ ] **Step 5: Run test, verify it passes** → PASS. Run `flutter analyze lib/screens/dossedart/dossedart_stats_screen.dart` → clean.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/dossedart/dossedart_stats_screen.dart test/screens/dossedart_stats_screen_test.dart
git commit -m "feat(profile): hero shows games count + member-since"
```

---

### Task 4: FORM strip

**Files:**
- Modify: `lib/screens/dossedart/dossedart_stats_screen.dart` (`_buildProfil` ~130, add `_FormStrip`)

- [ ] **Step 1: Write the failing test** — add to the stats screen test:

```dart
  testWidgets('PROFIL shows FORM strip from game history', (tester) async {
    SharedPreferences.setMockInitialValues({
      'saved_players': jsonEncode([_player('1', 'Ada', 1300).toJson()]),
      'game_history_v1': GameHistoryEntry.encodeList([
        GameHistoryEntry(
          id: 'g', gameMode: 'x01', date: DateTime(2026, 6, 1),
          players: [
            GameHistoryPlayer(name: 'Ada', savedPlayerId: '1', placement: 1,
                stats: const {}, ratingBefore: 1290, ratingAfter: 1300),
            GameHistoryPlayer(name: 'Bo', placement: 2, stats: const {}),
          ],
        ),
      ]),
    });
    await tester.pumpWidget(const MaterialApp(home: DossedartStatsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('FORM'), findsOneWidget);
    expect(find.text('W'), findsWidgets);
  });
```

- [ ] **Step 2: Run test, verify it fails** → FAIL (no 'FORM').

- [ ] **Step 3: Insert the section** in `_buildProfil()`, immediately after the
`_ProfileHero(...)` line and its trailing `SizedBox`:

```dart
        if (_recentForm(p).isNotEmpty) ...[
          _SectionCard(
            title: 'FORM',
            child: _FormStrip(results: _recentForm(p)),
          ),
          const SizedBox(height: 14),
        ],
```

Add a memoised getter in `_DossedartStatsScreenState`:

```dart
  List<FormResult> _recentForm(SavedPlayer p) =>
      recentForm(_history, p.id, limit: 8);
```

Add the widget at file scope:

```dart
class _FormStrip extends StatelessWidget {
  const _FormStrip({required this.results});
  final List<FormResult> results;

  @override
  Widget build(BuildContext context) {
    (String, Color) cell(FormOutcome o) => switch (o) {
          FormOutcome.win => ('W', DossedartTokens.green),
          FormOutcome.loss => ('L', DossedartTokens.red),
          FormOutcome.draw => ('U', DossedartTokens.yellow),
        };
    // Oldest → newest reads left-to-right like a form guide.
    final ordered = results.reversed.toList();
    return Row(
      children: [
        for (final f in ordered) ...[
          Expanded(
            child: Builder(builder: (_) {
              final (letter, c) = cell(f.outcome);
              final d = f.ratingDelta;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.07),
                  border: Border.all(color: c.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Text(letter, style: TextStyle(fontFamily: 'PressStart2P', fontSize: 11, color: c)),
                    const SizedBox(height: 5),
                    Text(
                      d == null ? '–' : '${d >= 0 ? '+' : ''}${d.round()}',
                      style: TextStyle(fontFamily: 'VT323', fontSize: 13, color: c),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 4: Run test, verify it passes** → PASS. `flutter analyze` the file → clean.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/dossedart/dossedart_stats_screen.dart test/screens/dossedart_stats_screen_test.dart
git commit -m "feat(profile): FORM strip (last 8 results)"
```

---

### Task 5: STREAKS & TOPP card

**Files:**
- Modify: `lib/screens/dossedart/dossedart_stats_screen.dart` (`_buildProfil`, add `_StreaksCard`)

- [ ] **Step 1: Write the failing test**:

```dart
  testWidgets('PROFIL shows streaks & rating peak', (tester) async {
    await _seed([
      _player('1', 'Ada', 1300, history: [
        RatingSnapshot(date: DateTime(2026, 1, 1), rating: 1361, placement: 1),
        RatingSnapshot(date: DateTime(2026, 1, 2), rating: 1300, placement: 2),
      ]),
    ]);
    await tester.pumpWidget(const MaterialApp(home: DossedartStatsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('STREAKS & TOPP'), findsOneWidget);
    expect(find.textContaining('1361'), findsWidgets); // rating peak
  });
```

- [ ] **Step 2: Run test, verify it fails** → FAIL.

- [ ] **Step 3: Insert the section** in `_buildProfil()` after the FORM block:

```dart
        _SectionCard(title: 'STREAKS & TOPP', child: _StreaksCard(player: p)),
        const SizedBox(height: 14),
```

Add the widget at file scope:

```dart
class _StreaksCard extends StatelessWidget {
  const _StreaksCard({required this.player});
  final SavedPlayer player;

  @override
  Widget build(BuildContext context) {
    final onStreak = player.currentWinStreak > 0;
    final peak = peakRating(player);
    final best = bestRank(player);
    final tiles = <(String, String, Color)>[
      (
        'NÅ PÅ RAD',
        onStreak ? '🔥 ${player.currentWinStreak}' : '${player.currentLossStreak} tap',
        onStreak ? DossedartTokens.orange : DossedartTokens.red,
      ),
      ('BESTE STREAK', '${player.bestWinStreak}', DossedartTokens.green),
      ('RATING-TOPP', peak == null ? '–' : '${peak.round()}', DossedartTokens.yellow),
      ('BESTE RANK', best == null ? '–' : '#$best', DossedartTokens.silver),
    ];
    return Row(
      children: [
        for (final (k, v, c) in tiles)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              decoration: BoxDecoration(
                  border: Border.all(color: DossedartTokens.phosphor.withValues(alpha: 0.25))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k, style: const TextStyle(fontFamily: 'VT323', fontSize: 12, color: DossedartTokens.phosphor)),
                  const SizedBox(height: 6),
                  Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test, verify it passes** → PASS. `flutter analyze` → clean.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/dossedart/dossedart_stats_screen.dart test/screens/dossedart_stats_screen_test.dart
git commit -m "feat(profile): streaks & rating-peak card"
```

---

### Task 6: REKORDER grid

**Files:**
- Modify: `lib/screens/dossedart/dossedart_stats_screen.dart` (add `_modeAccent`, `_RecordsGrid`)

- [ ] **Step 1: Add `_modeAccent`** (the const map shown in the Phase-1 preamble) near the top
of the file, after the imports.

- [ ] **Step 2: Write the failing test**:

```dart
  testWidgets('PROFIL shows REKORDER tiles', (tester) async {
    await _seed([
      SavedPlayer(
        id: '1', name: 'Ada', createdAt: DateTime(2026), rating: 1300,
        gamesPlayed: 4, gamesWon: 2,
        modeStats: {
          'x01': ModeStats(played: 5, won: 3, counters: {'highestTurn': 180}),
        },
      ),
    ]);
    await tester.pumpWidget(const MaterialApp(home: DossedartStatsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('REKORDER'), findsOneWidget);
    expect(find.text('180'), findsWidgets);
    expect(find.text('høyeste runde'), findsOneWidget);
  });
```

> Add `import 'package:dart_scoring/models/saved_player.dart';` to the test if not present (it already imports it).

- [ ] **Step 3: Run test, verify it fails** → FAIL.

- [ ] **Step 4: Insert the section** in `_buildProfil()` after the STREAKS block:

```dart
        if (careerRecords(p).isNotEmpty) ...[
          _SectionCard(title: 'REKORDER', child: _RecordsGrid(records: careerRecords(p))),
          const SizedBox(height: 14),
        ],
```

Add the widget at file scope:

```dart
class _RecordsGrid extends StatelessWidget {
  const _RecordsGrid({required this.records});
  final List<RecordTile> records;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final r in records)
          _RecordCell(record: r, color: _modeAccent[r.mode] ?? DossedartTokens.phosphor),
      ],
    );
  }
}

class _RecordCell extends StatelessWidget {
  const _RecordCell({required this.record, required this.color});
  final RecordTile record;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      // 2-up grid.
      final w = (c.maxWidth - 10) / 2;
      return SizedBox(
        width: w,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.04),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                color: color,
                child: Text(record.mode.toUpperCase(),
                    style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 8, color: DossedartTokens.bg)),
              ),
              const SizedBox(height: 6),
              Text(record.value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 4),
              Text(record.label,
                  style: const TextStyle(fontFamily: 'VT323', fontSize: 14, color: DossedartTokens.phosphor)),
            ],
          ),
        ),
      );
    });
  }
}
```

> NOTE: `LayoutBuilder` inside `Wrap` children needs a bounded width; the `Wrap` provides
> `c.maxWidth` = the section width. If the cricket key stored is `cricket_cutthroat`, the
> accent map already maps both to green and `record.mode` is normalised to `'cricket'` by
> `careerRecords`, so the tag reads `CRICKET`.

- [ ] **Step 5: Run test, verify it passes** → PASS. `flutter analyze` → clean.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/dossedart/dossedart_stats_screen.dart test/screens/dossedart_stats_screen_test.dart
git commit -m "feat(profile): records / personal-best grid"
```

---

### Task 7: PER MODUS depth row

**Files:**
- Modify: `lib/screens/dossedart/dossedart_stats_screen.dart` (`_modeWinRow` ~175 → `_ModeDepthRow`)

- [ ] **Step 1: Write the failing test**:

```dart
  testWidgets('PER MODE row shows depth stats (avg/best) for X01', (tester) async {
    await _seed([
      SavedPlayer(
        id: '1', name: 'Ada', createdAt: DateTime(2026), rating: 1300,
        gamesPlayed: 5, gamesWon: 3,
        modeStats: {
          'x01': ModeStats(played: 5, won: 3, counters: {
            'highestTurn': 140, 'totalTurnScore': 250, 'totalTurns': 5,
          }),
        },
      ),
    ]);
    await tester.pumpWidget(const MaterialApp(home: DossedartStatsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('PER MODE'), findsOneWidget);
    expect(find.textContaining('best 140'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test, verify it fails** → FAIL (current row has no "best 140").

- [ ] **Step 3: Replace `_modeWinRow`** with a depth row. Change the call site in `_buildProfil`'s
`PER MODE` `_SectionCard` from `_modeWinRow(p, m)` to `_ModeDepthRow(player: p, mode: m)`, then
replace the `_modeWinRow` method with:

```dart
  Widget _ModeDepthRow(SavedPlayer p, (String, String) mode) {
    final ms = p.modeStats[mode.$1];
    final played = ms?.played ?? 0;
    if (played == 0) return const SizedBox.shrink();
    final won = ms?.won ?? 0;
    final pct = (won * 100 / played).round();
    final extras = _modeExtras(mode.$1, ms!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(mode.$2,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              Text('$pct% · $won/$played',
                  style: const TextStyle(color: DossedartTokens.cyan, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: LayoutBuilder(builder: (context, c) {
                return Container(
                  height: 6,
                  color: Colors.white.withValues(alpha: 0.08),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(width: c.maxWidth * pct / 100, color: DossedartTokens.green),
                  ),
                );
              }),
            ),
          ),
          if (extras.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(extras.join('   ·   '),
                style: const TextStyle(fontFamily: 'VT323', fontSize: 14, color: DossedartTokens.phosphor, letterSpacing: 1)),
          ],
        ],
      ),
    );
  }

  /// Per-mode key stats line. Reads only stored counters.
  List<String> _modeExtras(String modeKey, ModeStats ms) {
    switch (modeKey) {
      case 'x01':
        final avg = ms.get('totalTurns') > 0
            ? (ms.get('totalTurnScore') / ms.get('totalTurns')).toStringAsFixed(1)
            : '–';
        return ['snitt $avg', 'best ${ms.get('highestTurn')}', '100+ ${ms.get('turnsOver100')}'];
      case 'cricket':
        final mpr = ms.get('totalDarts') > 0
            ? (ms.get('marksScored') / (ms.get('totalDarts') / 3)).toStringAsFixed(1)
            : '–';
        return ['MPR $mpr', 'best ${ms.get('bestPoints')}'];
      case 'aroundTheClock':
        final rate = ms.get('totalDarts') > 0
            ? (ms.get('totalHits') * 100 / ms.get('totalDarts')).round()
            : 0;
        return ['treff $rate%'];
      case 'shanghai':
        final avg = ms.get('totalGames') > 0
            ? (ms.get('totalScore') / ms.get('totalGames')).toStringAsFixed(0)
            : '–';
        return ['best ${ms.get('bestScore')}', 'snitt $avg'];
      case 'halveIt':
        return ['best ${ms.get('bestScore')}', 'halvering ${ms.get('biggestHalving')}'];
      case 'killer':
        return ['kills ${ms.get('kills')}'];
      default:
        return const [];
    }
  }
```

- [ ] **Step 4: Run test, verify it passes** → PASS. `flutter analyze` → clean.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/dossedart/dossedart_stats_screen.dart test/screens/dossedart_stats_screen_test.dart
git commit -m "feat(profile): per-mode depth rows (winrate bar + key stats)"
```

---

### Task 8: Nemesis marker in HEAD-TO-HEAD

**Files:**
- Modify: `lib/screens/dossedart/dossedart_stats_screen.dart` (`_h2hRows` ~202)

- [ ] **Step 1: Write the failing test**:

```dart
  testWidgets('HEAD-TO-HEAD marks the nemesis', (tester) async {
    await _seed([
      SavedPlayer(
        id: '1', name: 'Ada', createdAt: DateTime(2026), rating: 1300,
        gamesPlayed: 20, gamesWon: 10,
        headToHead: {'2': H2HRecord(wins: 2, losses: 9)},
      ),
      _player('2', 'Bo', 1200),
    ]);
    await tester.pumpWidget(const MaterialApp(home: DossedartStatsScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('nemesis'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test, verify it fails** → FAIL.

- [ ] **Step 3: Mark the nemesis row.** In `_h2hRows`, compute the nemesis id once and append a
marker to the matching row. Change the method body's start to:

```dart
  List<Widget> _h2hRows(SavedPlayer p) {
    final nemesis = nemesisId(p);
    final entries = p.headToHead.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));
    return entries.take(4).map((e) {
      final name = _players.where((x) => x.id == e.key).firstOrNull?.name ?? '???';
      final r = e.value;
      final isNemesis = e.key == nemesis;
```

Then inside the row's `Row(children: [...])`, after the name `Expanded`, add:

```dart
            if (isNemesis)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text('· nemesis',
                    style: TextStyle(fontFamily: 'VT323', fontSize: 13, color: DossedartTokens.red)),
              ),
```

- [ ] **Step 4: Run test, verify it passes** → PASS. `flutter analyze` → clean.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/dossedart/dossedart_stats_screen.dart test/screens/dossedart_stats_screen_test.dart
git commit -m "feat(profile): nemesis marker in head-to-head"
```

---

### Task 9: Full-suite gate + manual tablet verification

- [ ] **Step 1:** Run the whole suite: `flutter test` → all green.
- [ ] **Step 2:** `flutter analyze` (whole project) → no issues.
- [ ] **Step 3:** Manual on Galaxy Tab emulator (`project_emulator_target_device`): open STATISTICS →
  PROFIL. Verify, top to bottom: hero (games + since), FORM strip, STREAKS & TOPP, rating graph,
  REKORDER, PER MODE depth rows, HEAD-TO-HEAD (+ nemesis), PRESTASJONER. Switch player via the
  selector and confirm sections update. Check a brand-new player (0 games) hides form/records/per-mode
  cleanly. No commit (verification only); note findings.

---

## Self-review notes

- **Spec coverage:** Form (T1, T4) ✓; Streaks & rating peak (T2, T5) ✓; Records/PB w/ exact counters
  + ATC hit-rate + Killer career kills (T2, T6) ✓; per-mode depth (T7) ✓; nemesis (T2, T8) ✓; hero
  extension (T3) ✓; colours from `DossedartTokens`/`_modeAccent` ✓; no recorder changes ✓.
- **Type consistency:** `recentForm`/`FormResult`/`FormOutcome`, `careerRecords`/`RecordTile`,
  `peakRating`/`bestRank`/`nemesisId` defined in Task 1-2 and used unchanged in Task 4-8.
- **Decision locked:** ATC = treff-rate, Killer = career kills (no `min:`/`max:bestKills` added).
- **Empty states:** FORM, REKORDER, and each PER MODE row guard on played/empty so a 0-game player
  renders only hero + (empty) sections without errors.
