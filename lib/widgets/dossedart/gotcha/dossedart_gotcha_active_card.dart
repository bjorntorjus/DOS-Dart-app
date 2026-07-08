import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';
import '../dossedart_player_avatar.dart';

/// One opponent's position on the climb-to-target bar.
///
/// A tick turns red + skull ('💀') when [danger] is true — the active
/// player is exactly one dart from landing on that opponent's score (the
/// KILL helper made spatial).
class GotchaOpponentTick {
  const GotchaOpponentTick({
    required this.initial,
    required this.total,
    required this.danger,
  });

  /// First letter of the opponent's name, shown above the tick when not
  /// in danger.
  final String initial;
  final int total;
  final bool danger;
}

/// One dart-to-opponent kill suggestion shown in the KILL helper bar.
class GotchaKillChip {
  const GotchaKillChip({required this.dart, required this.name});

  final String dart;
  final String name;
}

/// Active player card for the DOSSEDART Gotcha cockpit.
///
/// Compact header (avatar + name + dart pips + inline LAST) on top, a
/// slim climb-to-target bar showing every opponent as a tick, and two
/// always-present helper bars (CHECKOUT / KILL) that dim rather than
/// disappear when empty — so the card height, and therefore the board
/// below it, never jumps.
class DossedartGotchaActiveCard extends StatelessWidget {
  const DossedartGotchaActiveCard({
    super.key,
    required this.playerName,
    required this.avatarPath,
    required this.accentColor,
    required this.total,
    required this.target,
    required this.currentDartIndex,
    required this.lastTurnLabel,
    required this.lastTurnSum,
    required this.checkoutRoute,
    required this.kills,
    required this.opponents,
  });

  final String playerName;
  final String? avatarPath;
  final Color accentColor;
  final int total;
  final int target;
  final int currentDartIndex; // 0..3
  final String? lastTurnLabel; // e.g. 'S20 · S20 · S20' (null = no turn yet)
  final int? lastTurnSum;
  final String? checkoutRoute; // e.g. 'T20 › D15'; null → dim helper
  final List<GotchaKillChip> kills; // empty → dim helper
  final List<GotchaOpponentTick> opponents;

  /// Same downscaling curve as the X01 active card (`_nameFontSize`),
  /// shifted down to the Gotcha header's smaller 17px base size.
  double _nameFontSize() {
    final len = playerName.length;
    if (len <= 6) return 17;
    if (len <= 10) return 14;
    if (len <= 16) return 11;
    return 9;
  }

  @override
  Widget build(BuildContext context) {
    final nameSize = _nameFontSize();
    final toGo = target - total;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
            decoration: BoxDecoration(
              color: DossedartTokens.surface,
              border: Border.all(color: accentColor, width: 3),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.25),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Compact header — LAST folded inline, no full-width row.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    DossedartPlayerAvatar(
                      avatarPath: avatarPath,
                      size: 52,
                      borderColor: accentColor,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            playerName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: nameSize,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              for (int i = 0; i < 3; i++) ...[
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: i < currentDartIndex
                                        ? accentColor
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: accentColor,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                'DART $currentDartIndex/3',
                                style: const TextStyle(
                                  fontFamily: 'VT323',
                                  fontSize: 14,
                                  color: Colors.white54,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Text(
                                '·',
                                style: TextStyle(
                                  fontFamily: 'VT323',
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.28),
                                ),
                              ),
                              const SizedBox(width: 9),
                              const Text(
                                'LAST',
                                style: TextStyle(
                                  fontFamily: 'VT323',
                                  fontSize: 14,
                                  color: Colors.white54,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  lastTurnLabel ?? '—',
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'VT323',
                                    fontSize: 16,
                                    color: DossedartTokens.yellow,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              if (lastTurnSum != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '=$lastTurnSum',
                                  style: const TextStyle(
                                    fontFamily: 'PressStart2P',
                                    fontSize: 10,
                                    color: DossedartTokens.yellow,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'SCORE',
                              style: TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 9,
                                color: Colors.white54,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$total',
                              style: TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 46,
                                color: accentColor,
                                height: 1,
                                letterSpacing: -2,
                                shadows: [
                                  Shadow(
                                    color:
                                        accentColor.withValues(alpha: 0.67),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'TO GO · ',
                              style: TextStyle(
                                fontFamily: 'VT323',
                                fontSize: 16,
                                color: DossedartTokens.yellow,
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              '$toGo',
                              style: const TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 11,
                                color: DossedartTokens.yellow,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ClimbBar(
                  score: total,
                  target: target,
                  accent: accentColor,
                  opponents: opponents,
                ),
                _HelperBar(
                  tag: 'CHECKOUT',
                  tagColor: DossedartTokens.green,
                  icon: '🎯',
                  active: checkoutRoute != null,
                  emptyText: 'NO ROUTE · > 3 DARTS',
                  child: checkoutRoute == null
                      ? null
                      : Row(
                          children: [
                            Expanded(
                              child: Text(
                                checkoutRoute!,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'PressStart2P',
                                  fontSize: 13,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                  shadows: [
                                    Shadow(
                                      color: DossedartTokens.green
                                          .withValues(alpha: 0.4),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'WIN ▶',
                              style: TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 9,
                                color: DossedartTokens.green,
                                letterSpacing: 1,
                                shadows: const [
                                  Shadow(
                                    color: DossedartTokens.green,
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
                _HelperBar(
                  tag: 'KILL',
                  tagColor: DossedartTokens.red,
                  icon: '💀',
                  active: kills.isNotEmpty,
                  emptyText: 'NONE WITHIN 1 DART',
                  child: kills.isEmpty
                      ? null
                      : Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            for (final k in kills)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: DossedartTokens.red
                                      .withValues(alpha: 0.13),
                                  border: Border.all(
                                    color: DossedartTokens.red
                                        .withValues(alpha: 0.53),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      k.dart,
                                      style: const TextStyle(
                                        fontFamily: 'PressStart2P',
                                        fontSize: 10,
                                        color: DossedartTokens.red,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '→ ${k.name.toUpperCase()}',
                                      style: const TextStyle(
                                        fontFamily: 'VT323',
                                        fontSize: 16,
                                        color: Colors.white,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
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
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: accentColor,
                boxShadow: [
                  BoxShadow(color: accentColor.withValues(alpha: 0.67), blurRadius: 8),
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
        ],
      ),
    );
  }
}

/// Slim climb-to-target bar: the active player's score as a filled track
/// with a bright leading edge, and every opponent placed as a tick at
/// their own score. A tick turns red + '💀' and pulses when [danger] is
/// true (the active player is exactly one dart from landing on it).
///
/// This is the only stateful piece of the card — it owns the pulse
/// animation and must stop (and never start) when the platform requests
/// reduced motion.
class _ClimbBar extends StatefulWidget {
  const _ClimbBar({
    required this.score,
    required this.target,
    required this.accent,
    required this.opponents,
  });

  final int score;
  final int target;
  final Color accent;
  final List<GotchaOpponentTick> opponents;

  @override
  State<_ClimbBar> createState() => _ClimbBarState();
}

class _ClimbBarState extends State<_ClimbBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _reduceMotion = false;

  bool get _hasDanger => widget.opponents.any((o) => o.danger);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _ClimbBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    final shouldRun = _hasDanger && !_reduceMotion;
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

  double _fraction(int value) {
    if (widget.target <= 0) return 0;
    return (value / widget.target).clamp(0.0, 1.0);
  }

  TextStyle _labelStyle(Color color) => TextStyle(
        fontFamily: 'VT323',
        fontSize: 12,
        letterSpacing: 1,
        color: color,
      );

  Widget _buildTick(GotchaOpponentTick o, double width, double pulseOpacity) {
    final dead = o.total <= 0;
    final color = dead
        ? Colors.white.withValues(alpha: 0.18)
        : o.danger
            ? DossedartTokens.red
            : DossedartTokens.phosphor;
    final left = (_fraction(o.total) * width - 10).clamp(-10.0, width - 10.0);
    final label = o.danger ? '💀' : (o.initial.isEmpty ? '' : o.initial[0]);
    final opacity = o.danger ? pulseOpacity : 1.0;
    return Positioned(
      left: left,
      top: 0,
      width: 20,
      height: 32,
      child: Opacity(
        opacity: opacity,
        // Fixed-height rows (rather than letting the label's intrinsic
        // text height decide) keep this tick's total height exactly the
        // 32px the parent Positioned reserves, regardless of the label's
        // actual glyph metrics (e.g. no bundled font in widget tests).
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 14,
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'VT323',
                    fontSize: 12,
                    height: 1,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 2,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                boxShadow: o.danger
                    ? [BoxShadow(color: DossedartTokens.red, blurRadius: 6)]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scoreFraction = _fraction(widget.score);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 32,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final pulseOpacity = 1.0 - _pulse.value * 0.6;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 9,
                        height: 14,
                        child: Container(
                          decoration: BoxDecoration(
                            color: DossedartTokens.bg,
                            border: Border.all(
                              color: widget.accent.withValues(alpha: 0.27),
                              width: 2,
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: scoreFraction,
                              heightFactor: 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      widget.accent.withValues(alpha: 0.33),
                                      widget.accent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.accent
                                          .withValues(alpha: 0.67),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: (scoreFraction * width - 1.5)
                            .clamp(0.0, width - 3.0),
                        top: 6,
                        height: 20,
                        width: 3,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(color: Colors.white, blurRadius: 6),
                            ],
                          ),
                        ),
                      ),
                      for (final o in widget.opponents)
                        _buildTick(o, width, pulseOpacity),
                    ],
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0', style: _labelStyle(Colors.white.withValues(alpha: 0.45))),
            Text(
              'CLIMB TO TARGET',
              style: _labelStyle(Colors.white.withValues(alpha: 0.6)),
            ),
            Text(
              '${widget.target}',
              style: _labelStyle(DossedartTokens.yellow),
            ),
          ],
        ),
      ],
    );
  }
}

/// Generic labelled, always-present strip used by the CHECKOUT and KILL
/// helpers. Dims (border/bg/glow fall back to a neutral low-alpha white,
/// [emptyText] shown instead of [child]) rather than disappearing, so the
/// card's height never changes based on whether a helper has content.
class _HelperBar extends StatelessWidget {
  const _HelperBar({
    required this.tag,
    required this.tagColor,
    required this.icon,
    required this.active,
    required this.emptyText,
    required this.child,
  });

  final String tag;
  final Color tagColor;
  final String icon;
  final bool active;
  final String emptyText;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        active ? tagColor : Colors.white.withValues(alpha: 0.14);
    return Opacity(
      opacity: active ? 1.0 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        constraints: const BoxConstraints(minHeight: 46),
        decoration: BoxDecoration(
          color: active
              ? tagColor.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.02),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: active
              ? [BoxShadow(color: tagColor.withValues(alpha: 0.25), blurRadius: 14)]
              : null,
        ),
        // IntrinsicHeight gives the Row a definite height to stretch its
        // children into — without it, CrossAxisAlignment.stretch nested in
        // this unbounded-height Container throws "forces an infinite
        // height" during layout.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: active
                      ? tagColor.withValues(alpha: 0.13)
                      : Colors.transparent,
                  border:
                      Border(right: BorderSide(color: borderColor, width: 2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(icon,
                        style: const TextStyle(fontSize: 15, height: 1)),
                    const SizedBox(width: 7),
                    Text(
                      tag,
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 9,
                        letterSpacing: 1,
                        color: active
                            ? tagColor
                            : Colors.white.withValues(alpha: 0.4),
                        shadows:
                            active ? [Shadow(color: tagColor, blurRadius: 6)] : null,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: active && child != null
                        ? child!
                        : Text(
                            emptyText,
                            style: TextStyle(
                              fontFamily: 'VT323',
                              fontSize: 15,
                              letterSpacing: 1,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
