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
