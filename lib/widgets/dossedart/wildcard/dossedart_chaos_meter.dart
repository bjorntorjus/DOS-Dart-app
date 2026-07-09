import 'package:flutter/material.dart';
import '../../../models/wildcard_events.dart';

/// The WILDCARD cockpit's always-visible chaos meter — the centerpiece.
///
/// Ten heat segments plus a big level number (0–10); colour and label
/// escalate with [wcChaosColor]/[wcChaosLabel]. At max (level >= 9) the
/// whole card gains a permanent danger pulse on its glow, driven by an
/// [AnimationController] that respects `MediaQuery.disableAnimations` —
/// same lifecycle as the Gotcha climb-bar's danger pulse.
class DossedartChaosMeter extends StatefulWidget {
  const DossedartChaosMeter({super.key, required this.level});

  /// 0–10 inclusive.
  final int level;

  @override
  State<DossedartChaosMeter> createState() => _DossedartChaosMeterState();
}

class _DossedartChaosMeterState extends State<DossedartChaosMeter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _reduceMotion = false;

  bool get _isMax => widget.level >= 9;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      // 550ms per direction → 1.1s full cycle per the wcMaxPulse keyframe
      duration: const Duration(milliseconds: 550),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant DossedartChaosMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    final shouldRun = _isMax && !_reduceMotion;
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

  @override
  Widget build(BuildContext context) {
    final level = widget.level;
    final color = wcChaosColor(level);
    final label = wcChaosLabel(level);
    final max = _isMax;
    final footer = 'events @ ${wcModifierChancePct(level)}%${max ? ' · 2 JOKERS' : ''}';

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        // Mirrors the JSX wcMaxPulse keyframe: outer glow 20→36px @
        // .33→.67 alpha, inset glow 24→34px @ .2→.33 alpha. At rest
        // (t=0, or reduced motion / not max) this collapses to the same
        // static values the non-pulsing card uses.
        final t = _pulse.value;
        final outerBlur = max ? 20 + t * 16 : 20.0;
        final outerAlpha = max ? 0.33 + t * 0.34 : 0.33;
        final shadows = <BoxShadow>[
          BoxShadow(color: color.withValues(alpha: outerAlpha), blurRadius: outerBlur),
          if (max)
            BoxShadow(
              color: color.withValues(alpha: 0.2 + t * 0.13),
              blurRadius: 24 + t * 10,
              blurStyle: BlurStyle.inner,
            ),
        ];

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 13),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.11),
                color.withValues(alpha: 0.02),
              ],
            ),
            boxShadow: shadows,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CHAOS',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 10,
                      color: color,
                      letterSpacing: 2,
                      shadows: [Shadow(color: color, blurRadius: 6)],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$level',
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 42,
                          color: color,
                          height: 0.9,
                          letterSpacing: -2,
                          shadows: [Shadow(color: color, blurRadius: 16)],
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '/10',
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 26,
                      child: Row(
                        children: [
                          for (int n = 1; n <= 10; n++) ...[
                            if (n > 1) const SizedBox(width: 4),
                            Expanded(child: _HeatCell(level: level, n: n)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 10,
                            color: color,
                            letterSpacing: 1.5,
                            shadows: [
                              Shadow(
                                color: color.withValues(alpha: 0.53),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          footer,
                          style: const TextStyle(
                            fontFamily: 'VT323',
                            fontSize: 14,
                            color: Colors.white54,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One of the ten heat segments in the chaos meter.
class _HeatCell extends StatelessWidget {
  const _HeatCell({required this.level, required this.n});

  final int level;
  final int n;

  @override
  Widget build(BuildContext context) {
    final on = n <= level;
    final lead = n == level;
    final segColor = wcChaosColor(n);

    return Container(
      decoration: BoxDecoration(
        color: on ? segColor : Colors.white.withValues(alpha: 0.07),
        border: Border.all(
          color: on ? segColor : Colors.white.withValues(alpha: 0.12),
        ),
        boxShadow: !on
            ? null
            : lead
                ? [
                    BoxShadow(color: segColor, blurRadius: 12),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.4),
                      blurRadius: 6,
                      blurStyle: BlurStyle.inner,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: segColor.withValues(alpha: 0.53),
                      blurRadius: 5,
                    ),
                  ],
      ),
    );
  }
}
