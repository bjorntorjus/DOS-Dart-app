import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';
import 'one_up_life_pips.dart';

/// Which primary content the [DossedartOneUpActiveCard] shows.
enum OneUpCardMode {
  /// No target yet — this turn sets the bar (game open / new BEST round).
  free,

  /// Normal beat-the-target turn.
  normal,

  /// Turn total has already matched or beaten the target (tie counts).
  safe,

  /// Turn total can no longer reach the target even with a 180 finish.
  cantBeat,
}

/// One opponent's compact tile in the [DossedartOneUpActiveCard]'s
/// opponents strip.
class OneUpOpponentEntry {
  const OneUpOpponentEntry({
    required this.name,
    required this.accent,
    required this.lives,
    required this.maxLives,
    required this.eliminated,
  });

  final String name;
  final Color accent;
  final int lives;
  final int maxLives;
  final bool eliminated;
}

/// Active player card for the DOSSEDART 1UP cockpit.
///
/// Shows the current BEAT target (or SET THE TARGET / SAFE / CAN'T BEAT
/// state), the running turn total + dart pips, a status line explaining
/// what's needed, and a strip of every opponent's remaining lives.
class DossedartOneUpActiveCard extends StatelessWidget {
  const DossedartOneUpActiveCard({
    super.key,
    required this.playerName,
    required this.accentColor,
    required this.lives,
    required this.maxLives,
    required this.target,
    required this.turnTotal,
    required this.currentDartIndex,
    required this.cardMode,
    required this.lastLife,
    required this.variantChip,
    required this.isRoundFree,
    required this.opponents,
  });

  final String playerName;
  final Color accentColor;
  final int lives;
  final int maxLives;

  /// Null in free mode — there is nothing to beat yet.
  final int? target;
  final int turnTotal;
  final int currentDartIndex; // 0..3
  final OneUpCardMode cardMode;
  final bool lastLife;

  /// e.g. 'BEAT THE LAST' / 'BEAT THE BEST · R3'.
  final String variantChip;

  /// True when [cardMode] is [OneUpCardMode.free] because a new BEST round
  /// just started (rather than the very first throw of the game).
  final bool isRoundFree;

  final List<OneUpOpponentEntry> opponents;

  /// Same downscaling curve as the Gotcha active card's `_nameFontSize`.
  double _nameFontSize() {
    final len = playerName.length;
    if (len <= 6) return 17;
    if (len <= 10) return 14;
    if (len <= 16) return 11;
    return 9;
  }

  String get _initials {
    final letters = playerName.trim().replaceAll(RegExp(r'\s+'), '');
    if (letters.isEmpty) return '';
    return letters.substring(0, letters.length < 3 ? letters.length : 3)
        .toUpperCase();
  }

  bool get _danger => cardMode == OneUpCardMode.cantBeat || lastLife;

  Color get _frameColor {
    if (cardMode == OneUpCardMode.safe) return DossedartTokens.green;
    if (_danger) return DossedartTokens.red;
    return accentColor;
  }

  int get _need {
    if (target == null) return 0;
    final raw = target! - turnTotal;
    return raw <= 0 ? 0 : raw;
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frameColor;
    final nameSize = _nameFontSize();
    final dartsLeft = 3 - currentDartIndex;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  frame.withValues(alpha: 0.11),
                  frame.withValues(alpha: 0.02),
                ],
              ),
              border: Border.all(color: frame, width: 3),
              boxShadow: [
                BoxShadow(color: frame.withValues(alpha: 0.33), blurRadius: 20),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _HeaderRow(
                  initials: _initials,
                  playerName: playerName,
                  nameSize: nameSize,
                  accentColor: accentColor,
                  lives: lives,
                  maxLives: maxLives,
                  lastLife: lastLife,
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: _buildPrimaryBlock()),
                    const SizedBox(width: 16),
                    _TurnBlock(
                      turnTotal: turnTotal,
                      currentDartIndex: currentDartIndex,
                      color: cardMode == OneUpCardMode.safe
                          ? DossedartTokens.green
                          : accentColor,
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                _buildStatusLine(dartsLeft),
                if (opponents.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _OpponentsStrip(opponents: opponents),
                ],
              ],
            ),
          ),
          Positioned(
            top: -9,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: frame,
                boxShadow: [
                  BoxShadow(color: frame.withValues(alpha: 0.67), blurRadius: 8),
                ],
              ),
              child: Text(
                '▶ NOW THROWING',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 9,
                  letterSpacing: 1.5,
                  color: DossedartTokens.bg,
                ),
              ),
            ),
          ),
          Positioned(
            top: -9,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: DossedartTokens.bg,
                border: Border.all(color: DossedartTokens.lime, width: 2),
              ),
              child: Text(
                variantChip,
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  letterSpacing: 1,
                  color: DossedartTokens.lime,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryBlock() {
    switch (cardMode) {
      case OneUpCardMode.free:
        final secondary = isRoundFree
            ? 'FIRST THROW · NEW ROUND'
            : 'FREE THROW · NO TARGET';
        final headlineLine2 = isRoundFree ? 'ROUND TARGET' : 'TARGET';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              secondary,
              style: const TextStyle(
                fontFamily: 'VT323',
                fontSize: 17,
                color: Colors.white54,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'SET THE',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 22,
                color: DossedartTokens.lime,
                letterSpacing: 1,
                height: 1.15,
                shadows: [
                  Shadow(
                    color: DossedartTokens.lime.withValues(alpha: 0.67),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
            Text(
              headlineLine2,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 22,
                color: DossedartTokens.lime,
                letterSpacing: 1,
                height: 1.15,
                shadows: [
                  Shadow(
                    color: DossedartTokens.lime.withValues(alpha: 0.67),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
          ],
        );

      case OneUpCardMode.safe:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SAFE',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 26,
                    color: DossedartTokens.green,
                    letterSpacing: 1,
                    shadows: [
                      Shadow(
                        color: DossedartTokens.green,
                        blurRadius: 16,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '✓',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 20,
                    color: DossedartTokens.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'NEW TARGET · ',
                  style: TextStyle(
                    fontFamily: 'VT323',
                    fontSize: 18,
                    color: Colors.white70,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  '$turnTotal',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 16,
                    color: DossedartTokens.yellow,
                  ),
                ),
                const Text(
                  ' · building…',
                  style: TextStyle(
                    fontFamily: 'VT323',
                    fontSize: 18,
                    color: Colors.white38,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ],
        );

      case OneUpCardMode.normal:
      case OneUpCardMode.cantBeat:
        final danger = _danger;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'BEAT',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 13,
                color: danger ? DossedartTokens.red : Colors.white60,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${target ?? 0}',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 54,
                color: danger ? DossedartTokens.red : Colors.white,
                letterSpacing: -2,
                height: 0.95,
                shadows: [
                  Shadow(
                    color: (danger ? DossedartTokens.red : accentColor)
                        .withValues(alpha: 0.53),
                    blurRadius: 18,
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }

  Widget _buildStatusLine(int dartsLeft) {
    final Color tint;
    final Widget content;

    switch (cardMode) {
      case OneUpCardMode.free:
        tint = Colors.white.withValues(alpha: 0.14);
        content = Text(
          '▸ YOUR 3-DART TOTAL SETS THE BAR FOR EVERYONE',
          style: TextStyle(
            fontFamily: 'VT323',
            fontSize: 16,
            color: DossedartTokens.cyan,
            letterSpacing: 1,
          ),
        );
        break;

      case OneUpCardMode.safe:
        tint = DossedartTokens.green;
        content = Text(
          'BEAT $target · REMAINING DARTS PAD THE NEW TARGET',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: DossedartTokens.green,
            letterSpacing: 1,
            shadows: [
              Shadow(color: DossedartTokens.green, blurRadius: 6),
            ],
          ),
        );
        break;

      case OneUpCardMode.cantBeat:
        tint = DossedartTokens.red;
        final maxPossible = 60 * dartsLeft;
        content = Row(
          children: [
            Text(
              "CAN'T BEAT",
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 11,
                color: DossedartTokens.red,
                letterSpacing: 1,
                shadows: [
                  Shadow(color: DossedartTokens.red, blurRadius: 8),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '· LIFE AT RISK · need $_need, max $maxPossible',
                style: const TextStyle(
                  fontFamily: 'VT323',
                  fontSize: 16,
                  color: Color(0xFFFF8FA6),
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        );
        break;

      case OneUpCardMode.normal:
        tint = lastLife
            ? DossedartTokens.red
            : Colors.white.withValues(alpha: 0.14);
        content = Row(
          children: [
            Text(
              'NEED $_need MORE',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 11,
                color: lastLife ? DossedartTokens.red : DossedartTokens.yellow,
                letterSpacing: 1,
                shadows: [
                  Shadow(
                    color:
                        (lastLife ? DossedartTokens.red : DossedartTokens.yellow)
                            .withValues(alpha: 0.53),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                lastLife
                    ? '· FAIL = ELIMINATED'
                    : '· $dartsLeft dart${dartsLeft != 1 ? 's' : ''} left',
                style: TextStyle(
                  fontFamily: 'VT323',
                  fontSize: 16,
                  color: lastLife
                      ? DossedartTokens.red
                      : Colors.white.withValues(alpha: 0.45),
                  letterSpacing: 1,
                  shadows: lastLife
                      ? [Shadow(color: DossedartTokens.red, blurRadius: 8)]
                      : null,
                ),
              ),
            ),
          ],
        );
        break;
    }

    final tinted = cardMode == OneUpCardMode.safe ||
        cardMode == OneUpCardMode.cantBeat ||
        lastLife;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: tinted
            ? tint.withValues(alpha: 0.09)
            : Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: tinted ? tint : Colors.white.withValues(alpha: 0.14),
          width: 2,
        ),
      ),
      child: content,
    );
  }
}

/// Header row: avatar box · name (downscaled) · life pips, plus the
/// LAST LIFE tag when the player is on their final heart.
class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.initials,
    required this.playerName,
    required this.nameSize,
    required this.accentColor,
    required this.lives,
    required this.maxLives,
    required this.lastLife,
  });

  final String initials;
  final String playerName;
  final double nameSize;
  final Color accentColor;
  final int lives;
  final int maxLives;
  final bool lastLife;

  @override
  Widget build(BuildContext context) {
    final pipColor = lastLife ? DossedartTokens.red : accentColor;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: DossedartTokens.bg,
            border: Border.all(color: accentColor, width: 3),
            boxShadow: [
              BoxShadow(color: accentColor.withValues(alpha: 0.33), blurRadius: 12),
            ],
          ),
          child: Text(
            initials,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 13,
              color: accentColor,
              shadows: [
                Shadow(color: accentColor.withValues(alpha: 0.67), blurRadius: 8),
              ],
            ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                playerName.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: nameSize,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              OneUpLifePips(lives: lives, max: maxLives, color: pipColor),
            ],
          ),
        ),
        if (lastLife) ...[
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'LAST',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: DossedartTokens.red,
                  letterSpacing: 1,
                  shadows: [
                    Shadow(color: DossedartTokens.red, blurRadius: 8),
                  ],
                ),
              ),
              Text(
                'LIFE',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: DossedartTokens.red,
                  letterSpacing: 1,
                  shadows: [
                    Shadow(color: DossedartTokens.red, blurRadius: 8),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Right-side "THIS TURN" block: running total + three dart pips.
class _TurnBlock extends StatelessWidget {
  const _TurnBlock({
    required this.turnTotal,
    required this.currentDartIndex,
    required this.color,
  });

  final int turnTotal;
  final int currentDartIndex;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'THIS TURN',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 9,
            color: Colors.white.withValues(alpha: 0.5),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$turnTotal',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 32,
            color: color,
            height: 1,
            letterSpacing: -1,
            shadows: [
              Shadow(color: color.withValues(alpha: 0.67), blurRadius: 14),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: i < currentDartIndex ? color : Colors.transparent,
                  border: Border.all(color: color, width: 2),
                  boxShadow: i < currentDartIndex
                      ? [BoxShadow(color: color.withValues(alpha: 0.67), blurRadius: 6)]
                      : null,
                ),
              ),
              if (i < 2) const SizedBox(width: 5),
            ],
          ],
        ),
      ],
    );
  }
}

/// Compact opponent tiles: name + life pips, or a dimmed skull + OUT tag
/// once eliminated.
class _OpponentsStrip extends StatelessWidget {
  const _OpponentsStrip({required this.opponents});

  final List<OneUpOpponentEntry> opponents;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final o in opponents) ...[
            _OpponentTile(entry: o),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _OpponentTile extends StatelessWidget {
  const _OpponentTile({required this.entry});

  final OneUpOpponentEntry entry;

  @override
  Widget build(BuildContext context) {
    final dead = entry.eliminated;
    final color = dead ? Colors.white.withValues(alpha: 0.25) : entry.accent;
    return Opacity(
      opacity: dead ? 0.5 : 1,
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: dead
              ? Colors.white.withValues(alpha: 0.02)
              : entry.accent.withValues(alpha: 0.05),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dead)
              const Text('💀', style: TextStyle(fontSize: 13, height: 1)),
            Text(
              entry.name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'VT323',
                fontSize: 14,
                color: Colors.white.withValues(alpha: dead ? 0.6 : 1),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            if (dead)
              Text(
                'OUT',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  color: DossedartTokens.red,
                  letterSpacing: 1,
                ),
              )
            else
              OneUpLifePips(
                lives: entry.lives,
                max: entry.maxLives,
                color: entry.accent,
                size: 13,
              ),
          ],
        ),
      ),
    );
  }
}
