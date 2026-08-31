import 'package:flutter/material.dart';
import '../../../models/golf_engine.dart' show golfTerm;
import '../../../theme/dossedart_tokens.dart';
import 'golf_common.dart';

/// A single 36x36 per-dart result chip for the [GolfStatusPlate] — shows
/// the dart's zone label ('S7'/'D7'/'T7'/'25'/'50'/'✗') colour-coded by the
/// term it would score, or a dim '·' placeholder before that dart is
/// thrown. [onDark] renders the chip in `DossedartTokens.bg` ink instead —
/// used when the chip sits on the plate's own solid term-colour fill
/// (result mode), where a zone-coloured chip would disappear into a
/// same-hue background.
class GolfDartChip extends StatelessWidget {
  const GolfDartChip({super.key, this.label, this.onDark = false});

  /// 'S7'/'D7'/'T7'/'25'/'50'/'✗'. Null = unthrown → renders '·'.
  final String? label;
  final bool onDark;

  /// Zone-term colour for a dart label — independent of [golfTermColor]
  /// (which colours a *hole's total strokes*, not a single dart).
  Color get _zoneColor {
    final l = label;
    if (l == null) return Colors.transparent;
    if (l.startsWith('T') || l == '50') return DossedartTokens.cyan; // ACE
    if (l.startsWith('D') || l == '25') return DossedartTokens.green; // BIRDIE
    if (l == '✗') return DossedartTokens.red;
    return DossedartTokens.phosphor; // S... → PAR
  }

  @override
  Widget build(BuildContext context) {
    final hasLabel = label != null;

    if (onDark) {
      final ink = DossedartTokens.bg;
      final color = hasLabel ? ink : ink.withValues(alpha: 0.45);
      return Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: color, width: 2)),
        child: Text(
          hasLabel ? label! : '·',
          style: TextStyle(
            fontFamily: hasLabel ? 'PressStart2P' : 'VT323',
            fontSize: hasLabel ? 10 : 16,
            color: color,
          ),
        ),
      );
    }

    if (hasLabel) {
      final color = _zoneColor;
      return Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          border: Border.all(color: color, width: 2),
        ),
        child: Text(
          label!,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: color,
          ),
        ),
      );
    }

    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 2,
        ),
      ),
      child: Text(
        '·',
        style: TextStyle(
          fontFamily: 'VT323',
          fontSize: 16,
          color: Colors.white.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

/// The hero's "press-your-luck heartbeat" — tee-off prompt, mid-hole
/// miss count + darts-left countdown, or (during the 1s result window)
/// the finished hole's term + who throws next. Always renders the three
/// per-dart chips first.
enum GolfPlateMode { teeOff, mid, result }

class GolfStatusPlate extends StatelessWidget {
  const GolfStatusPlate({
    super.key,
    required this.mode,
    required this.dartLabels,
    this.lie,
    this.wash = false,
    this.nextPlayerName,
  });

  final GolfPlateMode mode;

  /// 0..3 zone labels for the displayed hole's darts, in throw order.
  final List<String> dartLabels;

  /// Mid-hole: misses so far this hole (null/0 before the first miss).
  /// Result: the just-finished hole's final stroke count.
  final int? lie;

  /// Result mode only — true when all 3 darts missed (the max stroke).
  final bool wash;

  /// Who throws next — result mode only.
  final String? nextPlayerName;

  @override
  Widget build(BuildContext context) {
    final onDark = mode == GolfPlateMode.result;
    late final Color borderColor;
    late final Color fillColor;
    late final Widget content;

    switch (mode) {
      case GolfPlateMode.teeOff:
        borderColor = Colors.white.withValues(alpha: 0.16);
        fillColor = Colors.white.withValues(alpha: 0.04);
        content = _teeOffContent();
        break;
      case GolfPlateMode.mid:
        if (lie != null && lie! > 0) {
          final color = golfTermColor(lie!);
          borderColor = color;
          fillColor = color.withValues(alpha: 0.09);
        } else {
          borderColor = Colors.white.withValues(alpha: 0.16);
          fillColor = Colors.white.withValues(alpha: 0.04);
        }
        content = _midContent();
        break;
      case GolfPlateMode.result:
        final color = golfTermColor(lie!);
        borderColor = color;
        fillColor = color;
        content = _resultContent();
        break;
    }

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: fillColor,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                GolfDartChip(
                  label: i < dartLabels.length ? dartLabels[i] : null,
                  onDark: onDark,
                ),
                if (i < 2) const SizedBox(width: 8),
              ],
              const SizedBox(width: 12),
              Expanded(child: content),
            ],
          ),
          if (mode == GolfPlateMode.result)
            Positioned(
              left: 0,
              right: 0,
              bottom: 2,
              child: Container(
                height: 4,
                color: DossedartTokens.bg.withValues(alpha: 0.18),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 0.62,
                  child: Container(
                    color: DossedartTokens.bg.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _teeOffContent() => Text.rich(
    TextSpan(
      style: const TextStyle(
        fontFamily: 'VT323',
        fontSize: 22,
        color: Colors.white70,
        letterSpacing: 1,
      ),
      children: const [
        TextSpan(text: '▸ TEE OFF · '),
        TextSpan(
          text: 'LAST DART COUNTS',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );

  Widget _midContent() {
    final left = 3 - dartLabels.length;
    Widget leftSide;
    if (lie != null && lie! > 0) {
      // Plain miss count, not golf jargon (2026-08-07 QA): "LYING n" read as
      // "laying" at the oche, and the term that sat next to it was the term
      // for the MISS COUNT — not for anything still reachable this hole
      // (2 misses + a triple scores 3 = PAR, never golfTerm(2) = BIRDIE), so
      // it was actively misleading. The plate's term colour still tracks the
      // lie as a heat signal.
      leftSide = Text(
        '$lie MISS${lie == 1 ? '' : 'ES'}',
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 15,
          color: Colors.white,
        ),
      );
    } else {
      leftSide = Text(
        'NO SCORE',
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      );
    }
    return Row(
      children: [
        leftSide,
        const Spacer(),
        Text(
          '$left DART${left == 1 ? '' : 'S'} LEFT',
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 12,
            color: DossedartTokens.yellow,
          ),
        ),
      ],
    );
  }

  Widget _resultContent() {
    const ink = DossedartTokens.bg;
    final term = golfTerm(lie!) + (wash ? ' · WASH' : '');
    return Row(
      children: [
        // The term alone is the result readout (2026-08-07 QA): the "LYING n"
        // stroke count that used to lead this row read as "laying" from the
        // oche and said nothing the term + dart chips don't already.
        Flexible(
          child: Text(
            term,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 15,
              color: ink,
            ),
          ),
        ),
        const Spacer(),
        if (nextPlayerName != null)
          Flexible(
            child: Text(
              'NEXT ▸ ${nextPlayerName!}',
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'VT323',
                fontSize: 21,
                color: ink,
              ),
            ),
          ),
      ],
    );
  }
}
