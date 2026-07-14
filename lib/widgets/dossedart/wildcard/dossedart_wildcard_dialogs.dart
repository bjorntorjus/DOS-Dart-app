import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/dossedart_tokens.dart';

/// Full-screen scrim + centred content for a WILDCARD moment (modifier
/// announcement, joker reveal, instant event, CUT!, REWIND, bull choice,
/// winner). Meant to be placed directly as a child of the game screen's
/// `Stack` — it renders `Positioned.fill` internally so it always covers
/// the whole surface regardless of the stack's other children.
///
/// Deviation from the JSX `WCOverlay`: the fasit also applies
/// `backdropFilter: blur(3px)` to the scrim. `BackdropFilter` is expensive
/// to recomposite every frame on tablet-class hardware, so it is
/// deliberately skipped here — the darker radial gradient (tint@.15 →
/// near-black bg@.9) compensates visually without the perf cost.
class WildcardOverlay extends StatelessWidget {
  const WildcardOverlay({
    super.key,
    required this.tint,
    required this.child,
    this.onTap,
  });

  /// Radial-gradient tint colour — the moment's accent.
  final Color tint;
  final Widget child;

  /// When set, the whole scrim becomes tappable ("tap anywhere to
  /// continue"). Left `null` for moments with their own explicit choices
  /// (e.g. [BullChoiceDialog]'s ignite/calm panels) so no gesture layer
  /// sits over the dialog competing with those taps.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  tint.withValues(alpha: 0.15),
                  DossedartTokens.bg.withValues(alpha: 0.9),
                ],
                stops: const [0.0, 0.72],
              ),
            ),
          ),
        ),
        Center(child: child),
      ],
    );

    return Positioned.fill(
      child: onTap == null
          ? content
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: content,
            ),
    );
  }
}

/// Generic WILDCARD moment dialog — the JSX `WCDialog`, used for the
/// modifier announcement, joker reveal, instant event, CUT!, REWIND and
/// winner overlays. Width is `600`, clamped to `86%` of the surrounding
/// frame (the JSX's `width:600; max-width:86%`), 3px [accent] border, a
/// big outer glow plus a soft inner one, and an [icon] that either
/// pops in once (default) or spins continuously (REWIND's `⟲`, [spin]).
class WildcardDialog extends StatelessWidget {
  const WildcardDialog({
    super.key,
    required this.accent,
    required this.icon,
    required this.title,
    this.titleSize = 46,
    this.spin = false,
    this.onTap,
    required this.children,
  });

  final Color accent;
  final String icon;
  final String title;
  final double titleSize;

  /// True for REWIND's `⟲` — continuous 1.1s linear rotation instead of
  /// the one-shot pop-in.
  final bool spin;

  /// When set, the whole scrim becomes tappable ("tap anywhere to
  /// continue") — threaded straight through to [WildcardOverlay.onTap].
  /// Left `null` for moments that must not be dismissed by an incidental
  /// tap (none currently — the WINNER overlay wires this to the post-game
  /// navigation, since the overlay itself IS the celebration moment).
  final VoidCallback? onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return WildcardOverlay(
      tint: accent,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final frameWidth =
              constraints.maxWidth.isFinite ? constraints.maxWidth : 600.0;
          final width = math.min(600.0, frameWidth * 0.86);

          return SizedBox(
            width: width,
            child: Container(
              padding: const EdgeInsets.fromLTRB(30, 26, 30, 28),
              decoration: BoxDecoration(
                color: DossedartTokens.bg,
                border: Border.all(color: accent, width: 3),
                boxShadow: [
                  BoxShadow(color: accent.withValues(alpha: 0.47), blurRadius: 34),
                  BoxShadow(
                    color: accent.withValues(alpha: 0.09),
                    blurRadius: 30,
                    blurStyle: BlurStyle.inner,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _MomentIcon(icon: icon, spin: spin),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: titleSize,
                      color: accent,
                      letterSpacing: 2,
                      height: 1.12,
                      shadows: [
                        Shadow(color: accent, blurRadius: 22),
                        // JSX `4px 4px 0 ${MAGENTA}` — a hard, unblurred
                        // offset shadow for the 8-bit "pressed" look.
                        const Shadow(
                          color: DossedartTokens.magenta,
                          offset: Offset(4, 4),
                        ),
                      ],
                    ),
                  ),
                  ...children,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The moment icon: pops in once (ease-out scale+fade, ~JSX `wcPop`), or
/// spins continuously when [spin] is true (JSX `wcSpin`, REWIND's `⟲`).
/// Only the spinning variant needs a disposable [AnimationController] —
/// the pop-in is a one-shot [TweenAnimationBuilder], which manages its
/// own ticker internally.
class _MomentIcon extends StatelessWidget {
  const _MomentIcon({required this.icon, required this.spin});

  final String icon;
  final bool spin;

  @override
  Widget build(BuildContext context) {
    if (spin) return _SpinningIcon(icon: icon);

    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, t, child) {
        final clamped = t.clamp(0.0, 1.0);
        return Opacity(
          opacity: clamped,
          child: Transform.scale(scale: 0.5 + 0.5 * clamped, child: child),
        );
      },
      child: Text(icon, style: const TextStyle(fontSize: 42, height: 1)),
    );
  }
}

/// Continuous 1.1s linear rotation for [WildcardDialog]'s `spin` icon
/// (REWIND's `⟲`) — same disposable-`AnimationController`,
/// `disableAnimations`-aware lifecycle as the chaos meter's danger pulse
/// and the scorecard's dart-slot pulse.
class _SpinningIcon extends StatefulWidget {
  const _SpinningIcon({required this.icon});

  final String icon;

  @override
  State<_SpinningIcon> createState() => _SpinningIconState();
}

class _SpinningIconState extends State<_SpinningIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncSpin();
  }

  void _syncSpin() {
    if (!_reduceMotion) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (_controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: child,
        );
      },
      child: Text(widget.icon, style: const TextStyle(fontSize: 42, height: 1)),
    );
  }
}

/// The bull-choice dialog (JSX `BullDialog`) — the player picks whether
/// hitting bull ignites (+[magnitude]) or calms (-[magnitude]) the chaos
/// meter. [magnitude] is `3` for double bull, `1` for single bull.
///
/// Colour note: the JSX sub-labels use literal light tints (`#ff9db0` /
/// `#a9ecff`) rather than the pure red/cyan accents, to sit legibly on the
/// dark panel fill. Tokens-only means we can't reuse those literals, so
/// they're approximated here as `DossedartTokens.red`/`cyan` at ~62%
/// alpha over the dark background — close in perceived brightness without
/// introducing new hex values.
class BullChoiceDialog extends StatelessWidget {
  const BullChoiceDialog({
    super.key,
    required this.magnitude,
    required this.onIgnite,
    required this.onCalm,
  });

  final int magnitude;
  final VoidCallback onIgnite;
  final VoidCallback onCalm;

  @override
  Widget build(BuildContext context) {
    final title = magnitude == 3 ? 'DOUBLE BULL · 50' : 'BULL · 25';

    return WildcardOverlay(
      tint: DossedartTokens.yellow,
      child: Container(
        width: 560,
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
        decoration: BoxDecoration(
          color: DossedartTokens.bg,
          border: Border.all(color: DossedartTokens.yellow, width: 3),
          boxShadow: [
            BoxShadow(
              color: DossedartTokens.yellow.withValues(alpha: 0.4),
              blurRadius: 32,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 20,
                color: DossedartTokens.yellow,
                letterSpacing: 2,
                shadows: [
                  Shadow(color: DossedartTokens.yellow, blurRadius: 12),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'YOU CONTROL THE CHAOS — CHOOSE ±$magnitude',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'VT323',
                fontSize: 20,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _BullPanel(
                    color: DossedartTokens.red,
                    headline: '▲ +$magnitude',
                    subLabel: 'IGNITE · MORE CHAOS',
                    subColor: DossedartTokens.red.withValues(alpha: 0.62),
                    onTap: onIgnite,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _BullPanel(
                    color: DossedartTokens.cyan,
                    headline: '▼ −$magnitude',
                    subLabel: 'CALM · COOL IT DOWN',
                    subColor: DossedartTokens.cyan.withValues(alpha: 0.62),
                    onTap: onCalm,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'LEADERS COOL · TRAILERS IGNITE · BULL SCORES EITHER WAY',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'VT323',
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.45),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One "before → after" reveal row's data — a player's score/points
/// snapshot around an instant WILDCARD event or REWIND.
class WcRevealRow {
  const WcRevealRow({
    required this.name,
    required this.before,
    required this.after,
    required this.accent,
  });

  final String name;
  final int before;
  final int after;
  final Color accent;
}

/// Renders one "NAME  before → after" line per involved player under a
/// WILDCARD moment dialog (e.g. an instant event or REWIND). The `after`
/// value is tinted [DossedartTokens.green] when it moved favourably
/// (`after >= before`) or [DossedartTokens.red] otherwise. Static —
/// the parent [WildcardDialog]/[WildcardOverlay] already animates the
/// whole moment in, so no animation lives here.
class WcBeforeAfterRows extends StatelessWidget {
  const WcBeforeAfterRows({super.key, required this.rows});

  final List<WcRevealRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows) _RevealRow(row: row),
      ],
    );
  }
}

/// One row of [WcBeforeAfterRows].
class _RevealRow extends StatelessWidget {
  const _RevealRow({required this.row});

  final WcRevealRow row;

  @override
  Widget build(BuildContext context) {
    final afterColor =
        row.after >= row.before ? DossedartTokens.green : DossedartTokens.red;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            row.name,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 12,
              color: row.accent,
            ),
          ),
          const Spacer(),
          Text(
            '${row.before}',
            style: const TextStyle(
              fontFamily: 'VT323',
              fontSize: 22,
              color: Colors.white,
            ),
          ),
          const Text(
            ' → ',
            style: TextStyle(
              fontFamily: 'VT323',
              fontSize: 22,
              color: Colors.white54,
            ),
          ),
          Text(
            '${row.after}',
            style: TextStyle(
              fontFamily: 'VT323',
              fontSize: 22,
              color: afterColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// One tappable ignite/calm panel in [BullChoiceDialog].
class _BullPanel extends StatelessWidget {
  const _BullPanel({
    required this.color,
    required this.headline,
    required this.subLabel,
    required this.subColor,
    required this.onTap,
  });

  final Color color;
  final String headline;
  final String subLabel;
  final Color subColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          color: color.withValues(alpha: 0.09),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.27), blurRadius: 16),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              headline,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 26,
                color: color,
                shadows: [Shadow(color: color, blurRadius: 12)],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'VT323',
                fontSize: 17,
                color: subColor,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
