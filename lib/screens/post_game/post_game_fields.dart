import '../post_game_screen.dart' show vsParText;

/// One cell of the post-game stat grid.
class StatField {
  const StatField(this.label, this.value, {this.isZero = false});

  final String label;
  final String value;

  /// A conditional counter that resolved to zero. Rendered in place and
  /// dimmed with an em dash rather than removed, so two games of the same
  /// mode have identical grid geometry (design fasit 2026-08-10, grammar
  /// rule 2 — nothing grows or collapses at runtime).
  final bool isZero;
}

/// A mode's post-game presentation: the one number that goes in the standings
/// row header, plus the ordered list that fills the stat grid.
class PostGameFields {
  const PostGameFields({
    required this.headlineLabel,
    required this.headlineValue,
    required this.fields,
  });

  final String headlineLabel;
  final String headlineValue;
  final List<StatField> fields;
}

/// The mode's headline + its declared field order (design fasit 2026-08-10).
///
/// The ordering rule is the whole point of this function: **the headline never
/// enters the grid** — it lives in the row header — and the remaining fields
/// fill the 3-column grid left→right, top→bottom in exactly the order declared
/// below. A future wave-2 counter is appended to its mode's list and lands in
/// the next free slot, so no mode needs a design round to gain a stat.
///
/// Three states a stat can be in, and they are NOT the same thing:
///  - **absent** (`null` in [stats]) — the mode did not produce it this game;
///    skipped entirely.
///  - **present** — rendered normally.
///  - **conditionally zero** (Elims, Stolen, Rounds won, Shanghai!) — rendered
///    in place with `isZero`, so the grid keeps identical geometry between two
///    games of the same mode.
PostGameFields postGameFields(String gameMode, Map<String, dynamic> stats) {
  StatField? plain(String label, String key, {String Function(Object)? fmt}) {
    final v = stats[key];
    if (v == null) return null;
    return StatField(label, fmt != null ? fmt(v) : '$v');
  }

  /// A counter that is meaningful at zero only as "none happened" — kept in
  /// place and dimmed rather than removed.
  StatField? conditional(String label, String key) {
    final v = stats[key];
    if (v == null) return null;
    final isZero = v == 0 || v == false;
    return StatField(label, isZero ? '—' : '$v', isZero: isZero);
  }

  String headline(String key, {String Function(Object)? fmt}) {
    final v = stats[key];
    if (v == null) return '—';
    return fmt != null ? fmt(v) : '$v';
  }

  List<StatField> keep(List<StatField?> items) =>
      items.whereType<StatField>().toList();

  switch (gameMode) {
    case 'x01':
      return PostGameFields(
        headlineLabel: '3-DART AVG',
        headlineValue: headline('avgTurn',
            fmt: (v) => (v as double).toStringAsFixed(1)),
        fields: keep([
          plain('BEST', 'highestTurn'),
          plain('DARTS', 'darts'),
          plain('CHECKOUT', 'checkout'),
        ]),
      );
    case 'cricket':
      return PostGameFields(
        headlineLabel: 'POINTS',
        headlineValue: headline('points'),
        fields: keep([plain('CLOSED', 'closed')]),
      );
    case 'aroundTheClock':
      return PostGameFields(
        headlineLabel: 'REACHED',
        headlineValue: headline('reached'),
        fields: keep([plain('DARTS', 'darts')]),
      );
    case 'killer':
      return PostGameFields(
        headlineLabel: 'LIVES',
        headlineValue: headline('lives'),
        fields: const [],
      );
    case 'halveIt':
      return PostGameFields(
        headlineLabel: 'SCORE',
        headlineValue: headline('score'),
        fields: keep([plain('HALVED', 'halved')]),
      );
    case 'gotcha':
      return PostGameFields(
        headlineLabel: 'SCORE',
        headlineValue: headline('score'),
        fields: keep([
          plain('KILLS', 'kills'),
          plain('KILLED', 'timesKilled'),
          plain('BUSTS', 'busts'),
          plain('BEST', 'highestTurn'),
          plain('DARTS', 'darts'),
        ]),
      );
    case 'oneUp':
      return PostGameFields(
        headlineLabel: 'LIVES LOST',
        headlineValue: headline('livesLost'),
        fields: keep([
          plain('BEST', 'highestTurn'),
          plain('TARGETS', 'targetsSet'),
          plain('TURNS', 'turnsSurvived'),
          conditional('LAST-DART SAVES', 'lastDartSaves'),
          conditional('ROUNDS WON', 'roundsWon'),
          conditional('ELIMS', 'elimsDealt'),
        ]),
      );
    case 'golf':
      return PostGameFields(
        headlineLabel: 'STROKES',
        headlineValue: stats['strokes'] == null
            ? '—'
            : '${stats['strokes']} (${vsParText(stats['vsPar'])})',
        fields: keep([
          conditional('ACES', 'aces'),
          conditional('BOGEYS', 'bogeys'),
          plain('BEST HOLE', 'bestHole'),
          stats['holesPlayed'] == null
              ? null
              : StatField('1ST-DART',
                  '${stats['firstDartHits'] ?? 0}/${stats['holesPlayed']}'),
          plain('TERMS', 'termDist'),
        ]),
      );
    case 'shanghai':
      return PostGameFields(
        headlineLabel: 'SCORE',
        headlineValue: headline('score'),
        fields: keep([
          plain('BEST ROUND', 'bestRound'),
          // Shanghai! is a 0-or-1 flag, not a counter — an instant shanghai
          // ends the game, so it can never be 2.
          stats['shanghai'] == null
              ? null
              : StatField('SHANGHAI!', stats['shanghai'] == true ? 'YES' : '—',
                  isZero: stats['shanghai'] != true),
        ]),
      );
    case 'wildcard':
      return PostGameFields(
        headlineLabel: 'SCORE',
        headlineValue: headline('score'),
        fields: keep([
          plain('JOKERS', 'jokersHit'),
          conditional('PRIZES', 'windowPrizes'),
          conditional('STOLEN', 'pointsStolen'),
          plain('BEST', 'highestTurn'),
          plain('DARTS', 'darts'),
        ]),
      );
    default:
      // An unrecognised mode degrades to an empty card rather than throwing —
      // a result screen is the worst place to crash.
      return const PostGameFields(
        headlineLabel: 'RESULT',
        headlineValue: '—',
        fields: [],
      );
  }
}
