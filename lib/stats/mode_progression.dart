import '../models/dart_throw.dart';

/// Maps a player's throws to one value per round for the MATCH FLOW chart.
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

/// Shanghai & Splitscore: cumulative points per round. Splitscore's halving is
/// engine state absent from throwHistory, so this line climbs monotonically —
/// the round log shows the actual per-round (incl. halved) totals.
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
