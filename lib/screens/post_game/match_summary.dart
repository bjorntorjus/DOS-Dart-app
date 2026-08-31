import '../../models/cricket_engine.dart';
import '../../models/dart_throw.dart';

/// The six game-level numbers under the post-game standings — about the
/// MATCH, not about a player (design fasit 2026-08-10).
///
/// Every field except [duration] is nullable, and null is the render
/// instruction: the widget dims that cell and shows an em dash. Two different
/// situations produce nulls, and both are normal rather than error states:
///
///  - **Whole zone** — `throwHistory` is suppressed after a mid-game roster
///    change (the chart's lines index by seat and would mislabel), so five of
///    six cells go null and [degraded] is true. Duration survives because it
///    comes from the clock, not the throws.
///  - **One cell** — 1UP and Killer have no progression series yet, so only
///    [biggestLead] is null while everything else renders.
class MatchSummary {
  const MatchSummary({
    required this.duration,
    required this.degraded,
    this.rounds,
    this.darts,
    this.bestTurn,
    this.bestTurnBy,
    this.bestTurnLabel = 'BEST TURN',
    this.hitDistribution,
    this.biggestLead,
  });

  final String duration;
  final String? rounds;
  final String? darts;
  final String? bestTurn;

  /// Cell label: 'BEST TURN' where a points sum is the game (X01, Splitscore,
  /// Shanghai, Gotcha, Wildcard, 1UP, Cricket), 'BEST ROUND' where hits are
  /// what count (ATC, Killer, Golf).
  final String bestTurnLabel;

  /// Sub-line under BEST TURN: `NAME · Rn`.
  final String? bestTurnBy;
  final String? hitDistribution;
  final String? biggestLead;

  /// True when the throw history was unavailable, so the zone renders at full
  /// size with five dimmed cells and the section label gains a note.
  final bool degraded;
}

String _formatDuration(int? seconds) {
  if (seconds == null) return '—';
  final d = Duration(seconds: seconds);
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  if (d.inHours > 0) {
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '${d.inHours}:$m:$s';
  }
  return '${d.inMinutes}:$s';
}

/// Modes where the cell reports hits in a round rather than a points sum.
const _hitModes = {'aroundTheClock', 'killer', 'golf'};

String _bestTurnLabelFor(String? gameMode) =>
    _hitModes.contains(gameMode) ? 'BEST ROUND' : 'BEST TURN';

/// Targets a turn cleared in ATC: a hit advances by its multiplier when the
/// game counts multiples, clamped on the finishing dart to the targets that
/// actually remained (a T19 from 19 clears 2, not 3).
int _atcTurnTargets(
    List<DartThrow> turn, List<int>? sequence, bool countMultiples) {
  var cleared = 0;
  for (final t in turn) {
    if (t.multiplier <= 0) continue;
    var steps = countMultiples ? t.multiplier : 1;
    if (sequence != null) {
      final idx = sequence.indexOf(t.scoreBefore);
      if (idx >= 0 && sequence.length - idx < steps) {
        steps = sequence.length - idx;
      }
    }
    cleared += steps;
  }
  return cleared;
}

/// Replays the throws through Cricket's scoring rules and returns the points
/// each turn actually scored: only overflow marks past the third, and only
/// while the number was still open somewhere (dead numbers score nothing).
///
/// Cutthroat needs no branch: overflow means the thrower just closed the
/// number, so "closed by all" and "no open opponent" are the same check, and
/// the points dealt equal the points a standard game would have scored.
Map<int, int> _cricketTurnPoints(
  List<DartThrow> throws, {
  required int playerCount,
  required List<int> targets,
}) {
  final marks = List.generate(
      playerCount, (_) => <int, int>{for (final t in targets) t: 0});
  bool closedByAll(int seg) => marks.every((m) => (m[seg] ?? 0) >= 3);

  final byTurn = <int, int>{};
  for (final t in throws) {
    if (t.multiplier <= 0 ||
        !targets.contains(t.segment) ||
        t.playerIndex >= playerCount) {
      continue;
    }
    final current = marks[t.playerIndex][t.segment] ?? 0;
    final overflow = CricketEngine.computeOverflow(current, t.multiplier);
    // Own marks land before the dead-number check, same order as the engine:
    // the dart that closes your last open number scores nothing when every
    // opponent had already closed it.
    marks[t.playerIndex][t.segment] = current + t.multiplier;
    if (overflow <= 0 || closedByAll(t.segment)) continue;
    byTurn[t.turnId] = (byTurn[t.turnId] ?? 0) + t.segment * overflow;
  }
  return byTurn;
}

/// Derives the MATCH SUMMARY from what the result screen already holds.
///
/// [seriesFor] returns a player's plotted progression values, or null when the
/// mode has no series — it is the same source the chart draws, so BIGGEST LEAD
/// can never disagree with the picture above it.
///
/// [gameMode] selects the best-turn metric; [modeExtras] carries the config
/// bits the metric needs (cricket's target list, ATC's countMultiples and
/// target sequence). Both nullable — without them the cell falls back to the
/// points sum.
MatchSummary matchSummaryFrom({
  required int? durationSeconds,
  List<DartThrow>? throws,
  List<String> playerNames = const [],
  List<num>? Function(int seat)? seriesFor,
  String? gameMode,
  Map<String, dynamic>? modeExtras,
}) {
  final duration = _formatDuration(durationSeconds);
  final bestTurnLabel = _bestTurnLabelFor(gameMode);
  if (throws == null || throws.isEmpty) {
    return MatchSummary(
        duration: duration, degraded: true, bestTurnLabel: bestTurnLabel);
  }

  final rounds = throws.map((t) => t.roundNumber).toSet().length;

  // Best turn: group by turnId (unique per turn even when the score does not
  // change), value each turn by the mode's metric, take the biggest.
  final byTurn = <int, List<DartThrow>>{};
  for (final t in throws) {
    (byTurn[t.turnId] ??= []).add(t);
  }

  final isCricket = gameMode == 'cricket' || gameMode == 'cricket_cutthroat';
  final cricketPoints = isCricket
      ? _cricketTurnPoints(
          throws,
          playerCount: playerNames.length,
          targets: [
            for (final t in (modeExtras?['targets'] as List?) ??
                const [15, 16, 17, 18, 19, 20, 25])
              t as int
          ],
        )
      : null;

  int valueOf(List<DartThrow> group) {
    if (cricketPoints != null) return cricketPoints[group.first.turnId] ?? 0;
    if (gameMode == 'aroundTheClock') {
      return _atcTurnTargets(
        group,
        (modeExtras?['sequence'] as List?)?.cast<int>(),
        (modeExtras?['countMultiples'] as bool?) ?? true,
      );
    }
    if (_hitModes.contains(gameMode)) {
      return group.where((t) => t.multiplier > 0).length;
    }
    return group.fold<int>(0, (a, t) => a + t.points);
  }

  int bestSum = 0;
  List<DartThrow>? bestGroup;
  for (final group in byTurn.values) {
    final sum = valueOf(group);
    if (bestGroup == null || sum > bestSum) {
      bestSum = sum;
      bestGroup = group;
    }
  }

  // Killer and golf render as hits over darts thrown that round; ATC renders
  // the cleared-target count alone (a double can push it past 3).
  final bestDisplay = (gameMode == 'killer' || gameMode == 'golf')
      ? '$bestSum/${bestGroup?.length ?? 3}'
      : '$bestSum';
  String? bestBy;
  if (bestGroup != null) {
    final seat = bestGroup.first.playerIndex;
    final name = seat < playerNames.length
        ? playerNames[seat].toUpperCase()
        : 'P${seat + 1}';
    bestBy = '$name · R${bestGroup.first.roundNumber + 1}';
  }

  // Bull is checked FIRST: a double bull is a bull, not also a double.
  var triples = 0, doubles = 0, bulls = 0, misses = 0;
  for (final t in throws) {
    if (t.multiplier == 0) {
      misses++;
    } else if (t.segment == 25) {
      bulls++;
    } else if (t.multiplier == 3) {
      triples++;
    } else if (t.multiplier == 2) {
      doubles++;
    }
  }

  String? lead;
  if (seriesFor != null && playerNames.length > 1) {
    final series = <List<num>>[];
    for (var seat = 0; seat < playerNames.length; seat++) {
      final s = seriesFor(seat);
      if (s != null && s.isNotEmpty) series.add(s);
    }
    if (series.length > 1) {
      // Only rounds every seat has reached — a joiner's series is shorter, and
      // reading past its end would report the leader's whole total as a lead.
      final shared = series.map((s) => s.length).reduce((a, b) => a < b ? a : b);
      num widest = 0;
      for (var i = 0; i < shared; i++) {
        final at = [for (final s in series) s[i]];
        final gap = at.reduce((a, b) => a > b ? a : b) -
            at.reduce((a, b) => a < b ? a : b);
        if (gap > widest) widest = gap;
      }
      if (widest > 0) {
        lead = widest is int ? '$widest' : widest.toStringAsFixed(0);
      }
    }
  }

  return MatchSummary(
    duration: duration,
    degraded: false,
    rounds: '$rounds',
    darts: '${throws.length}',
    bestTurn: bestDisplay,
    bestTurnBy: bestBy,
    bestTurnLabel: bestTurnLabel,
    hitDistribution: 'T $triples · D $doubles · B $bulls · ✗ $misses',
    biggestLead: lead,
  );
}
