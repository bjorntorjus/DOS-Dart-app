import 'package:flutter/material.dart';
import '../models/game_result.dart';
import '../stats/mode_progression.dart';
import '../screens/dossedart/game_detail_screen.dart';
import '../theme/dossedart_tokens.dart';
import '../utils/dossedart_player_accents.dart';
import '../utils/join_seed.dart';
import '../widgets/dossedart/dossedart_crt_frame.dart';
import '../widgets/dossedart/golf/golf_scorecard.dart';
import '../widgets/dossedart/post_game/dossedart_match_summary.dart';
import '../widgets/dossedart/post_game/dossedart_placement_card.dart';
import '../widgets/dossedart/post_game/dossedart_post_game_actions.dart';
import '../widgets/dossedart/post_game/dossedart_winner_spotlight.dart';
import '../widgets/dossedart/post_game/post_game_type.dart';
import '../widgets/dossedart/progression_chart.dart';
import 'post_game/match_summary.dart';
import 'post_game/post_game_fields.dart';

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

/// Human label for the mode key, shown in the top bar's left slot.
String _modeLabel(String gameMode) => switch (gameMode) {
      'x01' => 'X01',
      'cricket' => 'CRICKET',
      'aroundTheClock' => 'ATC',
      'killer' => 'KILLER',
      'halveIt' => 'SPLITSCORE',
      'gotcha' => 'GOTCHA',
      'oneUp' => '1UP',
      'golf' => 'GOLF',
      'shanghai' => 'SHANGHAI',
      'wildcard' => 'WILDCARD',
      _ => gameMode.toUpperCase(),
    };

/// The DOSSEDART result screen (design round 2026-08-10).
///
/// Four zones, and only the middle one scrolls:
/// `TOPBAR 52 · WINNER 196 · SCROLL flex · ACTIONS 134`. The action bar is a
/// SIBLING of the scroll view, never its last item — the old Material screen
/// put the chart inside the placements list and floated the buttons under it,
/// which is how they could be pushed off a short frame.
class PostGameScreen extends StatelessWidget {
  final GameResult result;

  const PostGameScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    // Seat order breaks placement ties (join-fairness 2026-08-10): a mid-game
    // joiner holds the last seat, so on an exact tie they are listed BELOW the
    // player they were seeded from. `result.results` is in seat order.
    final seats = List.generate(result.results.length, (i) => i)
      ..sort(withSeatTiebreak((a, b) =>
          result.results[a].placement.compareTo(result.results[b].placement)));

    // Optional per-round progression chart — only when the mode opted in.
    final progression =
        result.throwHistory != null && result.progressionMode != null
            ? progressionForMode(result.progressionMode!, result.throwHistory!)
            : null;

    // Golf's embedded scorecard grid, same shape it feeds the in-game sheet.
    final golfExtras = result.gameMode == 'golf' ? result.modeExtras : null;

    final showDetails = result.detailEntry != null && !result.statsSkipped;

    final summary = matchSummaryFrom(
      durationSeconds: result.durationSeconds,
      throws: result.throwHistory,
      playerNames: [for (final p in result.results) p.name],
      // BIGGEST LEAD reads the same series the chart draws, so the number can
      // never disagree with the picture above it. Null for 1UP and Killer,
      // which have no series — that dims one cell, not the zone.
      seriesFor: progression == null
          ? null
          : (seat) => progression.seriesFor(result.throwHistory!,
              playerIndex: seat),
    );

    if (result.results.isEmpty) {
      // Defensive: a result screen is the worst place to crash.
      return DossedartCrtFrame(
        child: Scaffold(
          backgroundColor: DossedartTokens.bg,
          body: SafeArea(
            child: Column(
              children: [
                _TopBar(mode: _modeLabel(result.gameMode)),
                const Spacer(),
                DossedartPostGameActions(
                  canUndo: false,
                  canPlayAgain: false,
                  canShowDetails: false,
                  onBack: () {},
                  onPlayAgain: () {},
                  onDetails: () {},
                  onFinish: () => Navigator.of(context).pop('home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final winnerSeat = seats.first;
    final winner = result.results[winnerSeat];
    final winnerFields = postGameFields(result.gameMode, winner.stats);
    // WILDCARD never rates; the column still holds its width and dims.
    final rates = result.results.any((p) => p.ratingChange != null);

    return DossedartCrtFrame(
      child: Scaffold(
        backgroundColor: DossedartTokens.bg,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(mode: _modeLabel(result.gameMode)),
              DossedartWinnerSpotlight(
                name: winner.name,
                headlineLabel: winnerFields.headlineLabel,
                headlineValue: winnerFields.headlineValue,
                avatarPath: winner.avatarPath,
                ratingChange: winner.ratingChange,
                showElo: rates,
                showStats: true,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (result.statsSkipped) ...[
                        const _RosterNotice(),
                        const SizedBox(height: 16),
                      ],
                      PostGameSectionLabel('FINAL STANDINGS',
                          note: '· ${result.results.length} players'),
                      for (final seat in seats) ...[
                        DossedartPlacementCard(
                          placement: result.results[seat].placement,
                          name: result.results[seat].name,
                          // Accent is indexed by SEAT, not rank, so a player
                          // keeps one colour between here and the chart.
                          accent: dossedartAccent(seat),
                          fields: postGameFields(
                              result.gameMode, result.results[seat].stats),
                          avatarPath: result.results[seat].avatarPath,
                          ratingChange: result.results[seat].ratingChange,
                          showElo: rates,
                          showStats: true,
                          isTied: result.results.where((p) =>
                                  p.placement ==
                                  result.results[seat].placement).length >
                              1,
                        ),
                        if (seat != seats.last) const SizedBox(height: 8),
                      ],
                      if (golfExtras != null) ...[
                        const SizedBox(height: 16),
                        const PostGameSectionLabel('SCORECARD'),
                        // GolfScoreGrid owns its own horizontal scroll — an
                        // outer scroller would hand it unbounded width.
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
                      if (progression != null) ...[
                        const SizedBox(height: 16),
                        const PostGameSectionLabel('SCORE PER ROUND'),
                        ProgressionChart(
                          progression: progression,
                          throws: result.throwHistory!,
                          playerNames: [
                            for (final p in result.results) p.name
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      DossedartMatchSummary(summary: summary),
                    ],
                  ),
                ),
              ),
              DossedartPostGameActions(
                canUndo: result.canUndo,
                canPlayAgain: true,
                canShowDetails: showDetails,
                onBack: () => Navigator.of(context).pop('undo'),
                onPlayAgain: () => Navigator.of(context).pop('again'),
                onDetails: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GameDetailScreen(entry: result.detailEntry!),
                  ),
                ),
                onFinish: () => Navigator.of(context).pop('home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The result screen's own 52 px bar.
///
/// Deliberately NOT [DossedartTopBar], despite the handover listing it under
/// "reused verbatim": that widget hard-requires an `onExit` and renders a
/// `◀ EXIT` control, and post-game must not offer one — stats recording is
/// deferred until FINISH GAME, so leaving by any other route would silently
/// drop the game. Same height, same magenta rule, no exit.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.mode});

  final String mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
            bottom: BorderSide(color: DossedartTokens.magenta, width: 2)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(mode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PostGameType.vtStyle(18,
                    color: Colors.white.withValues(alpha: 0.5),
                    letterSpacing: 2,
                    height: 1)),
          ),
          Expanded(
            child: Text(
              'GAME OVER',
              textAlign: TextAlign.center,
              style: PostGameType.psStyle(13,
                  color: DossedartTokens.yellow,
                  letterSpacing: 3,
                  glow: DossedartTokens.yellow,
                  height: 1),
            ),
          ),
          // Right slot stays empty: mirroring the duration here is PROPOSAL 1
          // in the design round, parked by default.
          const SizedBox(width: 120),
        ],
      ),
    );
  }
}

class _RosterNotice extends StatelessWidget {
  const _RosterNotice();

  @override
  Widget build(BuildContext context) {
    const orange = DossedartTokens.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: orange.withValues(alpha: 0.07),
        border: Border.all(color: orange, width: 2),
      ),
      child: Row(
        children: [
          Text('!',
              style: PostGameType.psStyle(14, color: orange, glow: orange)),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'STATISTICS NOT RECORDED — PLAYER LIST CHANGED MID-GAME',
              style: PostGameType.vtStyle(18,
                  color: orange, letterSpacing: 1, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}
