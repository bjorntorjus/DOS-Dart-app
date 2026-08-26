import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';
import '../overview/dossedart_overview_header.dart';
import '../overview/dossedart_standings_rail.dart';
import 'one_up_life_pips.dart';
import 'one_up_status_plate.dart';

/// Which primary content the [DossedartOneUpActiveCard] shows.
enum OneUpCardMode {
  /// No target yet — this turn sets the bar (game open / new SURVIVOR round).
  free,

  /// Normal beat-the-target turn.
  normal,

  /// Turn total has already matched or beaten the target (tie counts).
  safe,

  /// Turn total can no longer reach the target even with a 180 finish.
  cantBeat,
}

/// One row of 1UP standings data (throw order — the card never sorts).
class OneUpStanding {
  const OneUpStanding({
    required this.name,
    required this.accent,
    required this.lives,
    required this.maxLives,
    this.eliminated = false,
    this.outOfRound = false,
    this.isActive = false,
  });

  final String name;
  final Color accent;
  final int lives;
  final int maxLives;

  /// Out of lives entirely.
  final bool eliminated;

  /// SURVIVOR only: knocked out of the current round (fail cost a life but
  /// the game goes on) — distinct from [eliminated].
  final bool outOfRound;
  final bool isActive;
}

/// 1UP overview card — A+ fasit (design_handoff_1up_overview, approved
/// 2026-07-22). Fixed 250px card in a 272px zone (margins 12/10): grammar
/// header + BEAT/SET THE TARGET primary block · rule line (SURVIVOR round
/// label + hairline) · left column THIS TURN row + [OneUpStatusPlate]
/// (always rendered, the dedicated state channel) · standings rail with
/// per-row life pips / OUT and the TARGET BY bottom row. The
/// frame stays player accent regardless of state — identity and state never
/// share a channel.
class DossedartOneUpActiveCard extends StatelessWidget {
  const DossedartOneUpActiveCard({
    super.key,
    required this.playerName,
    required this.avatarPath,
    required this.accentColor,
    required this.lives,
    required this.maxLives,
    required this.target,
    required this.turnTotal,
    required this.currentDartIndex,
    required this.cardMode,
    required this.survivor,
    required this.roundNumber,
    required this.targetBy,
    required this.standings,
    this.hitSuggestion,
  });

  final String playerName;
  final String? avatarPath;
  final Color accentColor;
  final int lives;
  final int maxLives;

  /// Null in free-throw — there is nothing to beat yet.
  final int? target;
  final int turnTotal;
  final int currentDartIndex; // darts thrown this turn, 0..3
  final OneUpCardMode cardMode;

  /// True in the SURVIVOR variant (drives the rule-line round label).
  final bool survivor;
  final int roundNumber;

  /// Name of the player who set the current target; null in free-throw.
  final String? targetBy;

  /// Throw order, including the active thrower — the card never sorts.
  final List<OneUpStanding> standings;
  final String? hitSuggestion;

  @override
  Widget build(BuildContext context) {
    final pipColor = lives == 1 ? DossedartTokens.red : accentColor;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      height: 250,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: DossedartTokens.surface,
        border: Border.all(color: accentColor, width: 3),
        boxShadow: [
          BoxShadow(color: accentColor.withValues(alpha: 0.25), blurRadius: 14),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DossedartOverviewHeader(
            playerName: playerName,
            avatarPath: avatarPath,
            accent: accentColor,
            dartsThrown: currentDartIndex,
            besideName: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OneUpLifePips(lives: lives, max: maxLives, color: pipColor, size: 17),
                if (lives == 1) ...[
                  const SizedBox(width: 6),
                  _lastLifeTag(),
                ],
              ],
            ),
            trailing: _primaryBlock(),
          ),
          _ruleLine(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // flex:37 vs. the rail's flex:25 below reproduces the exact
                // 444/300 tablet split (both sides tuned against the 758px
                // row width — 820px card minus margin/padding/border — at
                // the 820px fasit; same ratio as the X01 card, same Row
                // geometry) — see the rail's comment.
                Expanded(
                  flex: 37,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _thisTurnRow(),
                      OneUpStatusPlate(
                        mode: cardMode,
                        target: target,
                        turnTotal: turnTotal,
                        dartsThrown: currentDartIndex,
                        survivor: survivor,
                        hitSuggestion: hitSuggestion,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Below tablet width the rail can no longer claim its full
                // 300px unconditionally: Flexible lets it shrink under
                // squeeze while the ConstrainedBox pins the max so the
                // 820px look is unchanged (same idiom as
                // DossedartActiveStrip's modeSlot, db085a9, and the X01
                // card above). flex:25 is tuned so the allocated share is
                // exactly 300 at the 820px fasit width — no wasted
                // allocation, no gap before the card's right edge.
                Flexible(
                  flex: 25,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                        maxWidth: DossedartStandingsRail.width),
                    child: DossedartStandingsRail(
                      entries: [
                        for (final s in standings)
                          DossedartRailEntry(
                            name: s.name,
                            accent: s.accent,
                            isActive: s.isActive,
                            dimmed: s.eliminated || s.outOfRound,
                            trailing: _railTrailing(s),
                          ),
                      ],
                      bottomLabel: 'TARGET',
                      bottomValue: targetBy != null ? 'BY ${targetBy!.toUpperCase()}' : '—',
                      bottomDim: targetBy == null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// LAST LIFE tag next to the header's life pips — only shown at [lives] == 1.
  Widget _lastLifeTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(border: Border.all(color: DossedartTokens.red, width: 1)),
      child: const Text(
        'LAST LIFE',
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 7,
          color: DossedartTokens.red,
          letterSpacing: 1,
        ),
      ),
    );
  }

  /// The header's right-aligned primary block: BEAT the standing target, or
  /// SET THE TARGET when this is the free throw that sets it.
  Widget _primaryBlock() {
    if (target == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'FREE THROW',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 8,
              color: Colors.white.withValues(alpha: 0.55),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'SET THE\nTARGET',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 22,
              color: DossedartTokens.lime,
              height: 1.15,
              letterSpacing: 1,
              shadows: [
                Shadow(color: DossedartTokens.lime.withValues(alpha: 0.67), blurRadius: 14),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'BEAT',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 8,
            color: Colors.white.withValues(alpha: 0.55),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$target',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 60,
            color: accentColor,
            height: 1,
            letterSpacing: -2,
            shadows: [
              Shadow(color: accentColor.withValues(alpha: 0.66), blurRadius: 16),
            ],
          ),
        ),
      ],
    );
  }

  /// Full-width rule line: SURVIVOR round label (when [survivor]) + a
  /// hairline that always fills the remaining width — no label at all in
  /// BEAT THE LAST (KISS).
  Widget _ruleLine() {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 10),
      child: Row(
        children: [
          if (survivor) ...[
            Text(
              'SURVIVOR · RND $roundNumber',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 6,
                color: DossedartTokens.lime,
                letterSpacing: 1,
                shadows: [
                  Shadow(color: DossedartTokens.lime.withValues(alpha: 0.6), blurRadius: 6),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
          ),
        ],
      ),
    );
  }

  /// Left column's top row: running turn total against the standing target,
  /// dimmed to 0.34 before the first dart of the turn lands.
  Widget _thisTurnRow() {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            'THIS TURN',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.5),
              letterSpacing: 1,
            ),
          ),
        ),
        Flexible(
          child: Text(
            '$turnTotal',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'VT323',
              fontSize: 38,
              color: accentColor,
              height: 1,
              shadows: [
                Shadow(color: accentColor.withValues(alpha: 0.53), blurRadius: 10),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '/ ${target ?? '—'}',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'VT323',
              fontSize: 28,
              height: 1,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
        ),
      ],
    );
    return Opacity(opacity: currentDartIndex == 0 ? 0.34 : 1, child: content);
  }

  /// The standings rail's per-row trailing widget: eliminated shows OUT;
  /// otherwise life pips — also for a player who is out of the current round
  /// (the row itself is dimmed for that; what people want to read there is
  /// how many lives are left, not that the round is over for them).
  Widget _railTrailing(OneUpStanding s) {
    if (s.eliminated) {
      return Text(
        '💀 OUT',
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 7,
          color: Colors.white.withValues(alpha: 0.3),
          letterSpacing: 0.5,
        ),
      );
    }
    return OneUpLifePips(
      lives: s.lives,
      max: s.maxLives,
      color: s.lives == 1 ? DossedartTokens.red : s.accent,
      size: 13,
    );
  }
}
