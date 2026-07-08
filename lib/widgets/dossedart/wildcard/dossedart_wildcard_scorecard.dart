import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';

/// One player's row in the demoted [Standings] strip — already ranked by
/// the caller (highest total first).
class WcStandingEntry {
  const WcStandingEntry({
    required this.name,
    required this.accent,
    required this.total,
    required this.isActive,
    this.flagText,
    this.flagGood = false,
  });

  final String name;
  final Color accent;
  final int total;

  /// True for the player currently throwing — gets the highlighted cell.
  final bool isActive;

  /// A Robin-Hood event tag (e.g. `+50 STEAL`, `-50 ROBBED`). When set, it
  /// replaces the leader crown / last-place marker for this cell.
  final String? flagText;

  /// Green styling for [flagText] when true, red when false.
  final bool flagGood;
}

/// THIS TURN directive content — built by the screen from engine state
/// (window > modifier > open throw, in priority order).
class WcDirective {
  const WcDirective({
    required this.icon,
    required this.color,
    required this.head,
    required this.sub,
  });

  final String icon;
  final Color color;
  final String head;
  final String sub;
}

/// The DOSSEDART WILDCARD scorecard — the one surface that grows.
///
/// Active-player detail on top (avatar, per-dart breakdown, TURN/GAME +
/// rank), the dominant THIS TURN directive band, then the demoted
/// standings strip. Colours are tokens-only: [accent] drives the
/// player-specific chrome (avatar, dart slots, TURN value); the outer
/// card frame switches to [DossedartTokens.purple] whenever
/// [modifierActive] is true, matching the JSX `themed` colour.
class DossedartWildcardScorecard extends StatelessWidget {
  const DossedartWildcardScorecard({
    super.key,
    required this.playerName,
    required this.handle,
    required this.accent,
    required this.round,
    required this.rounds,
    required this.dartLabels,
    required this.turnPoints,
    required this.gameTotal,
    required this.rank,
    required this.toLead,
    required this.directive,
    required this.standings,
    required this.modifierActive,
  });

  final String playerName;

  /// 3-letter avatar handle (e.g. `JON`), already uppercased by the caller.
  final String handle;
  final Color accent;
  final int round;
  final int rounds;

  /// Length-3 list: `'T19'`/`'20'`/`'DBL'`/`'—'` for a thrown dart (a miss
  /// is represented by `'—'`), or `null` for a dart not yet reached.
  final List<String?> dartLabels;
  final int turnPoints;
  final int gameTotal;
  final int rank;

  /// Points behind the leader; `0` renders as `LEADER`.
  final int toLead;
  final WcDirective directive;

  /// Already ranked (highest total first).
  final List<WcStandingEntry> standings;

  /// True → outer card frame themes purple instead of [accent].
  final bool modifierActive;

  /// Same downscaling approach as the Gotcha active card's
  /// `_nameFontSize`, shifted to this card's smaller 15px base.
  double _nameFontSize() {
    final len = playerName.length;
    if (len <= 6) return 15;
    if (len <= 10) return 12;
    if (len <= 16) return 9;
    return 7;
  }

  @override
  Widget build(BuildContext context) {
    final themed = modifierActive ? DossedartTokens.purple : accent;
    final nameSize = _nameFontSize();
    final toLeadText = toLead == 0 ? 'LEADER' : '-$toLead TO LEAD';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
          decoration: BoxDecoration(
            border: Border.all(color: themed, width: 3),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                themed.withValues(alpha: 0.086),
                themed.withValues(alpha: 0.02),
              ],
            ),
            boxShadow: [
              BoxShadow(color: themed.withValues(alpha: 0.27), blurRadius: 18),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar — always the player's own accent, not themed.
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: DossedartTokens.bg,
                      border: Border.all(color: accent, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.33),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Text(
                      handle,
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 12,
                        color: accent,
                        shadows: [
                          Shadow(
                            color: accent.withValues(alpha: 0.67),
                            blurRadius: 8,
                          ),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: nameSize,
                            color: Colors.white,
                            letterSpacing: 2,
                            height: 1,
                          ),
                        ),
                        _DartSlots(dartLabels: dartLabels, accent: accent),
                      ],
                    ),
                  ),
                  const SizedBox(width: 13),
                  // TURN column.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'TURN',
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 9,
                          color: Colors.white.withValues(alpha: 0.5),
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$turnPoints',
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 30,
                          color: accent,
                          height: 1,
                          shadows: [
                            Shadow(
                              color: accent.withValues(alpha: 0.67),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // GAME column, divided from TURN.
                  Container(
                    margin: const EdgeInsets.only(left: 14),
                    padding: const EdgeInsets.only(left: 14),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'GAME',
                          style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 9,
                            color: DossedartTokens.yellow,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$gameTotal',
                          style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 32,
                            color: Colors.white,
                            height: 1,
                            shadows: [
                              Shadow(
                                color: DossedartTokens.yellow
                                    .withValues(alpha: 0.4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '#$rank · $toLeadText',
                          style: TextStyle(
                            fontFamily: 'VT323',
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.55),
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              _ThrowDirectiveBand(directive: directive),
              _StandingsStrip(standings: standings),
            ],
          ),
        ),
        Positioned(
          top: -9,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: themed,
              boxShadow: [
                BoxShadow(color: themed.withValues(alpha: 0.67), blurRadius: 8),
              ],
            ),
            child: Text(
              '▶ SCORECARD · R$round/$rounds',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 9,
                letterSpacing: 1.5,
                color: DossedartTokens.bg,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The per-dart breakdown row: three fixed-size slots (thrown / miss /
/// current-pulsing / empty) plus the trailing `DART n/3` counter.
///
/// The current slot's `▸` glyph is the only animated piece in this whole
/// card — a single [AnimationController] that starts/stops based on
/// whether there is a current slot to point at, and on
/// `MediaQuery.disableAnimations`, following the Gotcha climb-bar
/// lifecycle. 450ms per direction with `repeat(reverse: true)` yields the
/// 0.9s **full** cycle the design calls for — halving that duration is a
/// bug that has slipped in twice before in this project.
class _DartSlots extends StatefulWidget {
  const _DartSlots({required this.dartLabels, required this.accent});

  final List<String?> dartLabels;
  final Color accent;

  @override
  State<_DartSlots> createState() => _DartSlotsState();
}

class _DartSlotsState extends State<_DartSlots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _reduceMotion = false;

  int get _thrown => widget.dartLabels.where((d) => d != null).length;
  bool get _hasCurrent => _thrown < 3;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _DartSlots oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    final shouldRun = _hasCurrent && !_reduceMotion;
    if (shouldRun) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _slot(int index, double pulseOpacity) {
    final value = widget.dartLabels[index];
    final has = value != null;
    final miss = value == '—';
    final current = index == _thrown && _thrown < 3;

    final Color borderColor;
    Color? fillColor;
    List<BoxShadow>? glow;
    final Widget content;

    if (has && !miss) {
      borderColor = widget.accent;
      fillColor = widget.accent.withValues(alpha: 0.12);
      glow = [
        BoxShadow(color: widget.accent.withValues(alpha: 0.33), blurRadius: 8),
      ];
      content = Text(
        value,
        style: const TextStyle(
          fontFamily: 'VT323',
          fontSize: 19,
          letterSpacing: 1,
          color: Colors.white,
        ),
      );
    } else if (has) {
      // Miss: no fill, dimmer border/text.
      borderColor = Colors.white.withValues(alpha: 0.28);
      content = Text(
        value,
        style: TextStyle(
          fontFamily: 'VT323',
          fontSize: 19,
          letterSpacing: 1,
          color: Colors.white.withValues(alpha: 0.45),
        ),
      );
    } else if (current) {
      borderColor = widget.accent;
      glow = [
        BoxShadow(color: widget.accent.withValues(alpha: 0.4), blurRadius: 10),
      ];
      content = Opacity(
        opacity: pulseOpacity,
        child: Text(
          '▸',
          style: TextStyle(
            fontFamily: 'VT323',
            fontSize: 19,
            letterSpacing: 1,
            color: widget.accent,
          ),
        ),
      );
    } else {
      // Empty: the JSX uses a dashed border here. Flutter's Border has no
      // dashed style without a custom painter, so this is an accepted
      // deviation — solid, low-alpha white instead.
      borderColor = Colors.white.withValues(alpha: 0.16);
      content = Text(
        '·',
        style: TextStyle(
          fontFamily: 'VT323',
          fontSize: 19,
          color: Colors.white.withValues(alpha: 0.28),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 44),
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 2),
        color: fillColor,
        boxShadow: glow,
      ),
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final thrown = _thrown;
    final label = thrown < 3 ? thrown + 1 : 3;
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final pulseOpacity = 1.0 - _pulse.value * 0.65;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                _slot(i, pulseOpacity),
              ],
              const SizedBox(width: 8),
              Text(
                'DART $label/3',
                style: TextStyle(
                  fontFamily: 'VT323',
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 1,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The dominant THIS TURN directive band — what the active player must
/// throw this round (restriction / window / open), themed to
/// [WcDirective.color].
class _ThrowDirectiveBand extends StatelessWidget {
  const _ThrowDirectiveBand({required this.directive});

  final WcDirective directive;

  @override
  Widget build(BuildContext context) {
    final color = directive.color;
    return Padding(
      padding: const EdgeInsets.only(top: 13),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 3),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.149),
                  color.withValues(alpha: 0.043),
                ],
              ),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 20),
                BoxShadow(
                  color: color.withValues(alpha: 0.094),
                  blurRadius: 22,
                  blurStyle: BlurStyle.inner,
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(directive.icon, style: const TextStyle(fontSize: 34, height: 1)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        directive.head,
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 18,
                          color: Colors.white,
                          letterSpacing: 1,
                          height: 1.18,
                          shadows: [
                            Shadow(color: color, blurRadius: 12),
                            Shadow(color: color, blurRadius: 4),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        directive.sub,
                        style: TextStyle(
                          fontFamily: 'VT323',
                          fontSize: 19,
                          color: Colors.white.withValues(alpha: 0.78),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -9,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: color,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.67), blurRadius: 8),
                ],
              ),
              child: const Text(
                'THIS TURN',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  letterSpacing: 2,
                  color: DossedartTokens.bg,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Demoted standings strip — secondary to the THIS TURN band. One compact
/// cell per player, horizontally scrollable once there are more than
/// three players so the card never overflows a narrow surface.
class _StandingsStrip extends StatelessWidget {
  const _StandingsStrip({required this.standings});

  final List<WcStandingEntry> standings;

  @override
  Widget build(BuildContext context) {
    final leaderTotal = standings.isEmpty ? 0 : standings.first.total;
    final lastTotal = standings.isEmpty ? 0 : standings.last.total;
    final lastIndex = standings.length - 1;

    Widget cell(int index) {
      final entry = standings[index];
      final isLead = index == 0;
      final isLast = index == lastIndex && leaderTotal != lastTotal;

      Widget trailing;
      if (entry.flagText != null) {
        final flagColor =
            entry.flagGood ? DossedartTokens.green : DossedartTokens.red;
        trailing = Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(border: Border.all(color: flagColor)),
          child: Text(
            entry.flagText!,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 7,
              letterSpacing: 0.5,
              color: flagColor,
            ),
          ),
        );
      } else if (isLead) {
        trailing = const Text('👑', style: TextStyle(fontSize: 12));
      } else if (isLast) {
        trailing = const Text('▽', style: TextStyle(fontSize: 12));
      } else {
        trailing = const SizedBox.shrink();
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: entry.isActive
                ? entry.accent
                : Colors.white.withValues(alpha: 0.12),
          ),
          color: entry.isActive
              ? entry.accent.withValues(alpha: 0.071)
              : Colors.transparent,
        ),
        child: Opacity(
          opacity: entry.isActive ? 1.0 : 0.72,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${index + 1}',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  color: isLead
                      ? DossedartTokens.yellow
                      : Colors.white.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(width: 7),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: entry.accent,
                  boxShadow: [BoxShadow(color: entry.accent, blurRadius: 5)],
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  entry.name.toUpperCase(),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '${entry.total}',
                style: TextStyle(
                  fontFamily: 'VT323',
                  fontSize: 20,
                  color: entry.accent,
                  height: 1,
                  shadows: [
                    Shadow(
                      color: entry.accent.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              trailing,
            ],
          ),
        ),
      );
    }

    final caption = Row(
      children: [
        Text(
          'STANDINGS',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 7,
            color: Colors.white.withValues(alpha: 0.35),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ],
    );

    // Three or fewer players: fill the width evenly, no scroll needed.
    // More than that would overflow a narrow surface, so switch to a
    // horizontally scrolling row of fixed-width cells instead.
    final Widget row;
    if (standings.length <= 3) {
      row = Row(
        children: [
          for (int i = 0; i < standings.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: cell(i)),
          ],
        ],
      );
    } else {
      row = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < standings.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              SizedBox(width: 150, child: cell(i)),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          caption,
          const SizedBox(height: 6),
          row,
        ],
      ),
    );
  }
}
