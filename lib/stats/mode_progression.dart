import '../models/dart_throw.dart';

/// Maps a player's throws to one value per round for the MATCH FLOW chart.
abstract class ModeProgression {
  /// Plotted values, index 0 = start, then one per completed round.
  List<num> seriesFor(List<DartThrow> throws, {required int playerIndex});
  num get maxValue;          // axis top
  bool get descending;       // true = race to 0 (X01/Killer), false = climb
  String get finishLabel;    // e.g. "✓ OUT"
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
  String get finishLabel => '✓ OUT';
}

/// Cumulative sum of [value] per round, starting from 0 and climbing.
List<num> _cumulativeByRound(
    List<DartThrow> throws, int playerIndex, int Function(DartThrow) value) {
  final mine = throws.where((t) => t.playerIndex == playerIndex);
  final byRound = <int, List<DartThrow>>{};
  for (final t in mine) {
    (byRound[t.roundNumber] ??= []).add(t);
  }
  final rounds = byRound.keys.toList()..sort();
  final out = <num>[0];
  var total = 0;
  for (final r in rounds) {
    for (final t in byRound[r]!) {
      total += value(t);
    }
    out.add(total);
  }
  return out;
}

/// Cricket: cumulative marks (multiplier on a target number) per round.
class CricketProgression implements ModeProgression {
  CricketProgression({required this.targets, required this.maxValue});
  final Set<int> targets;
  @override
  final num maxValue;

  @override
  List<num> seriesFor(List<DartThrow> throws, {required int playerIndex}) =>
      _cumulativeByRound(throws, playerIndex,
          (t) => targets.contains(t.segment) ? t.multiplier : 0);

  @override
  bool get descending => false;
  @override
  String get finishLabel => '✓';
}

/// Shanghai: cumulative points per round.
class CumulativeScoreProgression implements ModeProgression {
  CumulativeScoreProgression({required this.maxValue});
  @override
  final num maxValue;

  @override
  List<num> seriesFor(List<DartThrow> throws, {required int playerIndex}) =>
      _cumulativeByRound(throws, playerIndex, (t) => t.points);

  @override
  bool get descending => false;
  @override
  String get finishLabel => '✓';
}

/// Splitscore: replays the running total from the fixed 40-point start. The
/// halving itself is engine state absent from throwHistory, but it is fully
/// derivable: a hit always scores > 0, so a round whose darts sum to 0 is
/// exactly a no-hit round — the total halves (integer division, matching
/// _finishTurn in halve_it_game_screen.dart). This makes the MATCH FLOW line
/// dip on halved rounds instead of climbing monotonically.
class SplitscoreProgression implements ModeProgression {
  static const int _startScore = 40;

  @override
  List<num> seriesFor(List<DartThrow> throws, {required int playerIndex}) {
    final mine = throws.where((t) => t.playerIndex == playerIndex);
    final byRound = <int, int>{};
    for (final t in mine) {
      byRound[t.roundNumber] = (byRound[t.roundNumber] ?? 0) + t.points;
    }
    final rounds = byRound.keys.toList()..sort();
    final out = <num>[_startScore];
    var total = _startScore;
    for (final r in rounds) {
      final sum = byRound[r]!;
      total = sum > 0 ? total + sum : total ~/ 2;
      out.add(total);
    }
    return out;
  }

  @override
  num get maxValue => 0;
  @override
  bool get descending => false;
  @override
  String get finishLabel => '✓';
}

/// Around the Clock: sequential targets completed per round (0 → 20, +bull).
/// Replays the sequence from throws — a dart on the current target advances it.
/// Ignores multiples/own-number nuance (the round log shows exact darts).
class AtcProgression implements ModeProgression {
  AtcProgression({this.includeBull = false, this.reverse = false});
  final bool includeBull;
  final bool reverse;

  late final List<int> _sequence = () {
    final nums = [for (var n = 1; n <= 20; n++) n];
    final seq = reverse ? nums.reversed.toList() : nums;
    return includeBull ? [...seq, 25] : seq;
  }();

  @override
  List<num> seriesFor(List<DartThrow> throws, {required int playerIndex}) {
    final mine = throws.where((t) => t.playerIndex == playerIndex).toList();
    final byRound = <int, List<DartThrow>>{};
    for (final t in mine) {
      (byRound[t.roundNumber] ??= []).add(t);
    }
    final rounds = byRound.keys.toList()..sort();
    final out = <num>[0];
    var idx = 0; // count of targets completed
    for (final r in rounds) {
      for (final t in byRound[r]!) {
        if (idx < _sequence.length && t.segment == _sequence[idx]) idx++;
      }
      out.add(idx);
    }
    return out;
  }

  @override
  num get maxValue => includeBull ? 21 : 20;
  @override
  bool get descending => false;
  @override
  String get finishLabel => '✓';
}

/// Golf: cumulative vs-par after each hole. `DartThrow.points` is a
/// placeholder for this mode and is NEVER the real per-dart score — strokes
/// are derived by walking a hole's darts in throw order and stopping at the
/// first hole-terminating dart: a hit (`segment > 0`) scores
/// `(4 - multiplier) + missesSoFar` strokes (e.g. an ace = T-hit on the first
/// dart = 1 stroke; a hit after 2 misses via a double = 2 + 2 = 4 strokes),
/// or the 3rd miss is a wash worth 6 strokes. Any darts thrown after that
/// terminator within the same round are ignored — playoff darts share the
/// frozen final `roundNumber` and would otherwise contaminate the last hole.
/// A round with no terminator yet (still in progress) contributes nothing.
class GolfProgression implements ModeProgression {
  GolfProgression({required this.maxValue});
  @override
  final num maxValue;

  @override
  List<num> seriesFor(List<DartThrow> throws, {required int playerIndex}) {
    final mine = throws.where((t) => t.playerIndex == playerIndex).toList();
    final byRound = <int, List<DartThrow>>{};
    for (final t in mine) {
      (byRound[t.roundNumber] ??= []).add(t);
    }
    final rounds = byRound.keys.toList()..sort();
    final out = <num>[0];
    var vsPar = 0;
    for (final r in rounds) {
      final strokes = _strokesForHole(byRound[r]!);
      if (strokes == null) continue; // hole still in progress
      vsPar += strokes - 3;
      out.add(vsPar);
    }
    return out;
  }

  /// Walks one hole's darts in throw order, stopping at the first
  /// hole-terminating dart. Returns null when the hole has no terminator
  /// yet (in progress) — darts after the terminator (playoff contamination)
  /// are never reached because we return as soon as we find it.
  int? _strokesForHole(List<DartThrow> hole) {
    var misses = 0;
    for (final t in hole) {
      if (t.segment > 0) {
        return (4 - t.multiplier) + misses;
      }
      misses++;
      if (misses >= 3) return 6;
    }
    return null;
  }

  @override
  bool get descending => false;
  @override
  String get finishLabel => '⛳';
}

/// Maps a `gameMode` key + throw history to the [ModeProgression] that
/// builds the MATCH FLOW / SCORE PER ROUND chart's series, or null when the
/// mode has none (Killer & unknown). Moved out of game_detail_screen.dart
/// (2026-07-09) so PostGameScreen can reuse the same mapping without
/// depending on a screen file — game_detail's `progressionForEntry` is now a
/// thin delegate to this.
ModeProgression? progressionForMode(String modeKey, List<DartThrow> throws) {
  switch (modeKey) {
    case 'x01':
      final start = throws.fold<int>(
          0, (m, t) => t.scoreAtStartOfTurn > m ? t.scoreAtStartOfTurn : m);
      return X01Progression(startScore: start > 0 ? start : 501);
    case 'cricket':
    case 'cricket_cutthroat':
      return CricketProgression(
          targets: const {15, 16, 17, 18, 19, 20, 25}, maxValue: 0);
    case 'aroundTheClock':
      return AtcProgression();
    case 'golf':
      return GolfProgression(maxValue: 0);
    case 'shanghai':
      return CumulativeScoreProgression(maxValue: 0);
    case 'halveIt':
      return SplitscoreProgression();
    case 'gotcha':
      // Gotcha counts up like Shanghai/Splitscore, and DartThrow.points is the
      // thrower's true delta for every dart (bust darts carry the negative
      // revert back to the turn-start score), so cumulative-by-round tracks
      // the thrower's real running total exactly. What it can't show: a kill
      // resets the *victim's* total on the victim's own line, which this
      // series (built from the victim's own throws) has no way to see —
      // an accepted limitation (unlike Splitscore's halving, a kill is not
      // derivable from the victim's own throws); the round log carries the
      // true per-round totals.
      return CumulativeScoreProgression(maxValue: 0);
    case 'wildcard':
      // Wildcard is a points race and DartThrow.points is the effective
      // per-dart credit (after turn modifiers/multipliers), so the thrower's
      // own cumulative line is faithful. What it can't show: swap/steal/
      // rewind events change OTHER players' totals, and those effects are
      // invisible to per-throw data on the affected player's line — the same
      // accepted limitation as Gotcha's kills above.
      return CumulativeScoreProgression(maxValue: 0);
    default:
      return null; // Killer & unknown → round log only
  }
}
