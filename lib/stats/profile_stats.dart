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

class RecordTile {
  final String mode;  // mode key, drives the accent colour at the call site
  final String value; // pre-formatted display value
  final String label; // e.g. 'highest turn'
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
  // Cross-cutting, so no mode key — the grid resolves an unknown key to
  // phosphor. Hidden at zero: an empty shame counter is not worth a tile.
  final slowTurns =
      p.modeStats.values.fold<int>(0, (sum, m) => sum + m.get('slowTurns'));
  if (slowTurns > 0) {
    out.add(RecordTile(mode: '', value: '$slowTurns', label: 'slow turns'));
  }
  final x01 = _firstMode(p, ['x01']);
  if (x01 != null && x01.get('highestTurn') > 0) {
    out.add(RecordTile(mode: 'x01', value: '${x01.get('highestTurn')}', label: 'highest turn'));
  }
  if (x01 != null && x01.get('bestCheckout') > 0) {
    out.add(RecordTile(mode: 'x01', value: '${x01.get('bestCheckout')}', label: 'best checkout'));
  }
  final cri = _firstMode(p, ['cricket', 'cricket_cutthroat']);
  if (cri != null && cri.get('bestPoints') > 0) {
    out.add(RecordTile(mode: 'cricket', value: '${cri.get('bestPoints')}', label: 'best points'));
  }
  final sh = _firstMode(p, ['shanghai']);
  if (sh != null && sh.get('bestScore') > 0) {
    out.add(RecordTile(mode: 'shanghai', value: '${sh.get('bestScore')}', label: 'best score'));
  }
  final spl = _firstMode(p, ['halveIt']);
  if (spl != null && spl.get('biggestHalving') > 0) {
    out.add(RecordTile(mode: 'halveIt', value: '${spl.get('biggestHalving')}', label: 'biggest halving'));
  }
  final kil = _firstMode(p, ['killer']);
  if (kil != null && kil.get('kills') > 0) {
    out.add(RecordTile(mode: 'killer', value: '${kil.get('kills')}', label: 'total kills'));
  }
  final atc = _firstMode(p, ['aroundTheClock']);
  if (atc != null && atc.get('totalDarts') > 0) {
    final rate = (atc.get('totalHits') * 100 / atc.get('totalDarts')).round();
    out.add(RecordTile(mode: 'aroundTheClock', value: '$rate%', label: 'hit rate'));
  }
  final got = _firstMode(p, ['gotcha']);
  if (got != null && got.get('highestTurn') > 0) {
    out.add(RecordTile(mode: 'gotcha', value: '${got.get('highestTurn')}', label: 'best turn'));
  }
  final wc = _firstMode(p, ['wildcard']);
  if (wc != null && wc.get('highestTurn') > 0) {
    out.add(RecordTile(mode: 'wildcard', value: '${wc.get('highestTurn')}', label: 'best turn'));
  }
  final oneUp = _firstMode(p, ['oneUp']);
  if (oneUp != null && oneUp.get('highestTurn') > 0) {
    out.add(RecordTile(mode: 'oneUp', value: '${oneUp.get('highestTurn')}', label: 'best turn'));
  }
  final golf = _firstMode(p, ['golf']);
  if (golf != null && (golf.get('bestRound18') > 0 || golf.get('bestRound9') > 0)) {
    final best = golf.get('bestRound18') > 0 ? golf.get('bestRound18') : golf.get('bestRound9');
    out.add(RecordTile(mode: 'golf', value: '$best', label: 'best round'));
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
