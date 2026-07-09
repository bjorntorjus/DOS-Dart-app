import 'package:flutter/material.dart';
import '../../../models/wildcard_events.dart';

/// The WILDCARD cockpit's compact chaos+round strip.
///
/// QA round 3 declutter: the old ten-heat-segment meter (with its own
/// label word and "events @ N%" footer) is gone — this is now a single
/// slim line carrying CHAOS `<level>/10` on the left and ROUND `<x>/<N>`
/// on the right. Round used to render in three places on this cockpit
/// (top bar, meter footer area, scorecard ribbon); this strip is now the
/// ONLY place it shows. At max chaos (level >= 9) the level number's glow
/// gains a subtle danger pulse, driven by an [AnimationController] that
/// respects `MediaQuery.disableAnimations` — same lifecycle as the old
/// meter's (and the Gotcha climb-bar's) danger pulse.
class DossedartChaosMeter extends StatefulWidget {
  const DossedartChaosMeter({
    super.key,
    required this.level,
    required this.round,
    required this.rounds,
  });

  /// 0–10 inclusive.
  final int level;

  /// Current round, 1-indexed.
  final int round;

  /// Total rounds in the game.
  final int rounds;

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
      // 550ms per direction -> 1.1s full cycle — NOT the halving bug that
      // has slipped in twice before in this project.
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
    final max = _isMax;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value;
        // At rest (t=0, or reduced motion / not max) this collapses to the
        // static blur-12 glow; at max chaos it breathes on top of that.
        final glowBlur = max ? 12 + t * 8 : 12.0;
        final glowAlpha = max ? 0.6 + t * 0.4 : 0.6;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
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
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'CHAOS',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 9,
                  color: color,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$level/10',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 20,
                  color: color,
                  shadows: [
                    Shadow(
                      color: color.withValues(alpha: glowAlpha),
                      blurRadius: glowBlur,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'ROUND ${widget.round}/${widget.rounds}',
                style: const TextStyle(
                  fontFamily: 'VT323',
                  fontSize: 16,
                  color: Colors.white70,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
