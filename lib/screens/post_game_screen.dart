import 'package:flutter/material.dart';
import '../models/game_result.dart';
import '../stats/mode_progression.dart';
import '../widgets/dossedart/golf/golf_scorecard.dart';
import '../widgets/dossedart/progression_chart.dart';
import '../widgets/player_avatar.dart';

/// Golf's vs-par display: 'E' at even, '+n' over, 'n' (with the leading '-'
/// already in the int's string form) under.
String vsParText(dynamic v) => v == null || v == 0 ? 'E' : (v > 0 ? '+$v' : '$v');

/// Per-player term-distribution for Golf's post-game stats: counts each
/// played hole's stroke score into ACE (1) / BIRDIE (2) / PAR (3) / BOGEY-
/// or-worse (4-6), omitting categories with zero count and ignoring
/// not-yet-played (`null`) holes. Returns null when nothing has been played
/// (nothing to show) — a pure, unit-testable helper so `golf_game_screen.dart`
/// can compute it into `PlayerResult.stats['termDist']` without duplicating
/// the counting logic.
String? golfTermDist(List<int?> card) {
  var aces = 0, birdies = 0, pars = 0, bogeyPlus = 0;
  for (final stroke in card) {
    if (stroke == null) continue;
    switch (stroke) {
      case 1:
        aces++;
      case 2:
        birdies++;
      case 3:
        pars++;
      default:
        bogeyPlus++;
    }
  }
  final parts = <String>[
    if (aces != 0) 'A$aces',
    if (birdies != 0) 'B$birdies',
    if (pars != 0) 'P$pars',
    if (bogeyPlus != 0) 'B+$bogeyPlus',
  ];
  return parts.isEmpty ? null : parts.join(' ');
}

class PostGameScreen extends StatelessWidget {
  final GameResult result;

  const PostGameScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sorted = List<PlayerResult>.from(result.results)
      ..sort((a, b) => a.placement.compareTo(b.placement));
    final winner = sorted.first;

    // Optional per-round progression chart (SCORE PER ROUND) — only when the
    // mode opted in (`throwHistory`/`progressionMode` both set, WILDCARD as
    // of 2026-07-09). `result.results`' own (unsorted) order is index-aligned
    // with each DartThrow's `playerIndex`, unlike `sorted` above.
    final progression = result.throwHistory != null &&
            result.progressionMode != null
        ? progressionForMode(result.progressionMode!, result.throwHistory!)
        : null;

    // Golf's embedded scorecard grid (post-game v2) — mode opt-in via
    // `modeExtras`, same shape it feeds `showGolfScoreSheet` in-game.
    final golfExtras =
        result.gameMode == 'golf' ? result.modeExtras : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Over'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Winner section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  cs.tertiary.withAlpha(40),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.emoji_events, size: 48, color: cs.tertiary),
                const SizedBox(height: 8),
                PlayerAvatar(
                  avatarPath: winner.avatarPath,
                  name: winner.name,
                  radius: 36,
                ),
                const SizedBox(height: 8),
                Text(
                  winner.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('Winner!',
                    style: TextStyle(color: cs.tertiary, fontSize: 16)),
              ],
            ),
          ),

          // Golf's SCORECARD section (post-game v2) — embeds the same grid
          // shown in-game via `showGolfScoreSheet`, between the winner banner
          // and the placements list.
          if (golfExtras != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SCORECARD',
                    style: TextStyle(
                      color: cs.tertiary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // GolfScoreGrid owns its own horizontal scroll for the
                  // hole-by-hole table (matches the in-game modal sheet) —
                  // an outer horizontal scroller here would hand it
                  // unbounded width and blow up its stretched Column.
                  GolfScoreGrid(
                    names: List<String>.from(golfExtras['names'] as List),
                    scorecards: (golfExtras['scorecards'] as List)
                        .map((row) => List<int?>.from(row as List))
                        .toList(),
                    totals: List<int>.from(golfExtras['totals'] as List),
                    vsPars: List<int>.from(golfExtras['vsPars'] as List),
                    skippedSeats:
                        Set<int>.from(golfExtras['skippedSeats'] as Set),
                  ),
                ],
              ),
            ),

          // Stats skipped notice
          if (result.statsSkipped)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.secondary.withAlpha(30),
                border: Border.all(color: cs.secondary.withAlpha(80)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: cs.secondary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Statistics not recorded (player list changed mid-game)',
                      style: TextStyle(color: cs.secondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Rankings, plus the per-round progression chart (mode opt-in
          // only) as a trailing list item — kept inside the same scrollable
          // region as the placements (rather than a fixed sibling below
          // Expanded) so the chart's own ~250px doesn't blow the Column's
          // budget and push "Finish Game" off small screens.
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: sorted.length + (progression != null ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < sorted.length) {
                  return _PlayerResultTile(
                    result: sorted[index],
                    gameMode: result.gameMode,
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SCORE PER ROUND',
                        style: TextStyle(
                          color: cs.tertiary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ProgressionChart(
                        progression: progression!,
                        throws: result.throwHistory!,
                        playerNames: result.results.map((p) => p.name).toList(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Action buttons: Back + Continue side by side, Finish Game wide bottom
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              children: [
                Row(
                  children: [
                    if (result.canUndo)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop('undo'),
                          child: const Text('↶ Back'),
                        ),
                      ),
                    if (result.canContinue) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              Navigator.of(context).pop('continue'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                          ),
                          child: const Text('▶ Continue'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop('home'),
                    child: const Text('Finish Game'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerResultTile extends StatelessWidget {
  final PlayerResult result;
  final String gameMode;

  const _PlayerResultTile({required this.result, required this.gameMode});

  Color _placementColor(int p, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (p) {
      case 1:
        return cs.tertiary;
      case 2:
        return cs.onSurface.withValues(alpha: 0.7);
      case 3:
        return Colors.brown[300]!;
      default:
        return cs.onSurface.withValues(alpha: 0.4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratingChange = result.ratingChange;
    final stats = result.stats;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Placement badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _placementColor(result.placement, context).withAlpha(40),
                border: Border.all(
                  color: _placementColor(result.placement, context),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '${result.placement}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _placementColor(result.placement, context),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Avatar
            PlayerAvatar(
              avatarPath: result.avatarPath,
              name: result.name,
              radius: 20,
            ),
            const SizedBox(width: 12),
            // Name and stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildStats(stats, context),
                ],
              ),
            ),
            // Rating change
            if (ratingChange != null)
              _buildRatingDelta(context, ratingChange),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(Map<String, dynamic> stats, BuildContext context) {
    final entries = <String>[];

    switch (gameMode) {
      case 'x01':
        if (stats['highestTurn'] != null) entries.add('Best: ${stats['highestTurn']}');
        if (stats['avgTurn'] != null) entries.add('Avg: ${(stats['avgTurn'] as double).toStringAsFixed(1)}');
        if (stats['darts'] != null) entries.add('Darts: ${stats['darts']}');
        if (stats['checkout'] != null) entries.add('Out: ${stats['checkout']}');
      case 'cricket':
        if (stats['points'] != null) entries.add('Pts: ${stats['points']}');
        if (stats['closed'] != null) entries.add('Closed: ${stats['closed']}');
      case 'aroundTheClock':
        if (stats['reached'] != null) entries.add('Reached: ${stats['reached']}');
        if (stats['darts'] != null) entries.add('Darts: ${stats['darts']}');
      case 'killer':
        if (stats['lives'] != null) entries.add('Lives: ${stats['lives']}');
      case 'halveIt':
        if (stats['score'] != null) entries.add('Score: ${stats['score']}');
        if (stats['halved'] != null) entries.add('Halved: ${stats['halved']}');
      case 'gotcha':
        if (stats['score'] != null) entries.add('Score: ${stats['score']}');
        if (stats['kills'] != null) entries.add('Kills: ${stats['kills']}');
        if (stats['timesKilled'] != null) entries.add('Killed: ${stats['timesKilled']}');
        if (stats['busts'] != null) entries.add('Busts: ${stats['busts']}');
        if (stats['highestTurn'] != null) entries.add('Best: ${stats['highestTurn']}');
        if (stats['darts'] != null) entries.add('Darts: ${stats['darts']}');
      case 'oneUp':
        if (stats['highestTurn'] != null) entries.add('Best: ${stats['highestTurn']}');
        if (stats['targetsSet'] != null) entries.add('Targets: ${stats['targetsSet']}');
        if (stats['livesLost'] != null) entries.add('Lives lost: ${stats['livesLost']}');
        if (stats['turnsSurvived'] != null) entries.add('Turns: ${stats['turnsSurvived']}');
        if (stats['lastDartSaves'] != null && stats['lastDartSaves'] != 0) {
          entries.add('Last-dart saves: ${stats['lastDartSaves']}');
        }
        if (stats['roundsWon'] != null && stats['roundsWon'] != 0) entries.add('Rounds won: ${stats['roundsWon']}');
        if (stats['elimsDealt'] != null && stats['elimsDealt'] != 0) entries.add('Elims: ${stats['elimsDealt']}');
      case 'golf':
        if (stats['strokes'] != null) {
          entries.add('Strokes: ${stats['strokes']} (${vsParText(stats['vsPar'])})');
        }
        if ((stats['aces'] ?? 0) != 0) entries.add('Aces: ${stats['aces']}');
        if ((stats['bogeys'] ?? 0) != 0) entries.add('Bogeys: ${stats['bogeys']}');
        if (stats['bestHole'] != null) entries.add('Best hole: ${stats['bestHole']}');
        if (stats['holesPlayed'] != null && stats['holesPlayed'] != 0) {
          entries.add('1st-dart: ${stats['firstDartHits'] ?? 0}/${stats['holesPlayed']}');
        }
        if (stats['termDist'] != null) entries.add('Terms: ${stats['termDist']}');
      case 'shanghai':
        if (stats['score'] != null) entries.add('Score: ${stats['score']}');
        if (stats['bestRound'] != null && stats['bestRound'] != 0) entries.add('Best round: ${stats['bestRound']}');
        if (stats['shanghai'] == true) entries.add('Shanghai!');
      case 'wildcard':
        if (stats['score'] != null) entries.add('Score: ${stats['score']}');
        if (stats['jokersHit'] != null) entries.add('Jokers: ${stats['jokersHit']}');
        if (stats['windowPrizes'] != null) entries.add('Prizes: ${stats['windowPrizes']}');
        // Only when ROBIN HOOD fired
        if (stats['pointsStolen'] != null && stats['pointsStolen'] != 0) entries.add('Stolen: ${stats['pointsStolen']}');
        if (stats['highestTurn'] != null) entries.add('Best: ${stats['highestTurn']}');
        if (stats['darts'] != null) entries.add('Darts: ${stats['darts']}');
    }

    if (entries.isEmpty) return const SizedBox.shrink();
    return Text(
      entries.join(' | '),
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12),
    );
  }

  Widget _buildRatingDelta(BuildContext context, double delta) {
    if (delta.abs() < 0.5) {
      return Text(
        '±0',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    final positive = delta > 0;
    final color = positive ? cs.primary : cs.error;
    final icon = positive ? Icons.arrow_upward : Icons.arrow_downward;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 2),
        Text(
          '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
