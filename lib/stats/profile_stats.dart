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
