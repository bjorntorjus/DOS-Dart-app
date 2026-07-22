import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';
import 'dart_zone.dart';

/// Standard dart segment order starting at 20 (top), going clockwise.
const List<int> kSegmentOrder = [
  20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5,
];

// TWILIGHT board palette — BALANSERT (board-specific felt/ring colors, not part
// of the global role palette in DossedartTokens). Full neon hues with brightness
// dialed down. Singles alternate dark/light purple felt; triple+double rings
// alternate magenta/cyan, keyed on (i % 2) to mirror a real bristle board:
// segment 20 (i == 0) is the DARK felt and carries the MAGENTA ring; light
// segments carry the CYAN ring.
const Color _twiBase = Color(0xFF05000E); // disc/surround behind the felt
const Color _twiSingleDark = Color(0xFF190B32);
const Color _twiSingleLight = Color(0xFF3C2472);
const Color _twiRingCyan = Color(0xFF2FC4DD);
const Color _twiRingMagenta = Color(0xFFE637A8);

// WILDCARD dim states — non-scoring segments during a restriction render in
// these near-black/low-alpha tones instead of the twilight felt/ring/number
// colors above. Bull/D-Bull dim too, but only under HOLY TRINITY — every
// other predicate reports segment 25 as scoring (see paint() and
// WildcardEngine.dimPredicate, the single source of truth for that
// carve-out).
const Color _dimSingle = Color(0xFF0B0618);
const Color _dimRing = Color(0xFF140A24);
const Color _dimNumber = Color(0x38D9D2C2); // phosphor @ ~0.22 alpha

// Radius thresholds as fractions of board radius.
// Visual = hit-test (no surprise misses).
const double kDBullR = 0.05;
const double kBullR = 0.12;
const double kInnerSingleR = 0.47;
const double kTripleR = 0.58;
const double kOuterSingleR = 0.82;
const double kDoubleR = 0.95;

/// Resolve a tap at polar (r, angleDeg) — r as a fraction of board
/// radius, angleDeg measured clockwise from 12 o'clock — to a DartZone.
DartZone zoneForPolar(double r, double angleDeg) {
  if (r <= kDBullR) return const DartZone.dBull();
  if (r <= kBullR) return const DartZone.bull();
  if (r > kDoubleR) return const DartZone.miss();

  // Normalise angle to [0, 360).
  double a = angleDeg % 360;
  if (a < 0) a += 360;
  // Each segment is 18°, centred on its number. Segment 0 (the "20"
  // segment) spans [-9°, 9°). So shift by +9° to make segment 0 start at 0°.
  final segIdx = ((a + 9) % 360 / 18).floor();
  final n = kSegmentOrder[segIdx];

  if (r <= kInnerSingleR) return DartZone.single(n);
  if (r <= kTripleR) return DartZone.triple(n);
  if (r <= kOuterSingleR) return DartZone.single(n);
  return DartZone.double_(n);
}

/// Renders the DOSSEDART arcade dartboard and reports taps as DartZones.
/// The widget fills its available space; wrap in an AspectRatio(1) to
/// keep it square.
class DossedartX01Dartboard extends StatelessWidget {
  const DossedartX01Dartboard({super.key, required this.onTap, this.isDim});

  final ValueChanged<DartZone> onTap;

  /// WILDCARD: optional predicate marking a (segment, multiplier) dart as
  /// non-scoring during a restriction, so that ring renders dimmed. Called
  /// once per band with that band's multiplier (inner/outer single = 1,
  /// triple = 3, double = 2), so a value-based restriction can dim only
  /// some of a segment's rings. Null (default) preserves today's rendering
  /// exactly — hit-testing is never affected, dimmed segments stay fully
  /// tappable.
  final bool Function(int segment, int multiplier)? isDim;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          // Opaque so the whole square reports taps — corner taps outside the
          // board circle resolve to a miss instead of falling through.
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final centre = Offset(size / 2, size / 2);
            final offset = details.localPosition - centre;
            final boardRadius = size / 2;
            final r = offset.distance / boardRadius;
            final angleRad = math.atan2(offset.dx, -offset.dy); // 12 o'clock = 0, CW positive
            final angleDeg = angleRad * 180 / math.pi;
            onTap(zoneForPolar(r, angleDeg));
          },
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(painter: _DartboardPainter(isDim)),
          ),
        );
      },
    );
  }
}

class _DartboardPainter extends CustomPainter {
  _DartboardPainter(this.isDim);

  final bool Function(int segment, int multiplier)? isDim;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);

    // Board background → BALANSERT disc (#05000E), darker than the app bg, so
    // the twilight felt reads as clean segments. Glow comes from the circular
    // BoxDecoration the cockpits wrap the board in (game_screen /
    // killer_game_screen); the painter draws no border ring of its own.
    final bg = Paint()..color = _twiBase;
    canvas.drawCircle(c, r, bg);

    const slice = math.pi * 2 / 20;
    for (int i = 0; i < 20; i++) {
      final start = -slice / 2 + i * slice - math.pi / 2;
      final end = start + slice;
      // Singles = twilight purple felt; triple + double = magenta/cyan ring.
      // Dark felt (i even, e.g. segment 20) → magenta ring; light felt → cyan.
      final n = kSegmentOrder[i];
      // Per-ring dimming: value-based restrictions (e.g. ONLY EVENS) can dim
      // a segment's single band while leaving its double/triple band lit
      // (D5 = 10 scores under ONLY EVENS even though S5 does not), so each
      // band is evaluated with its own multiplier.
      final dimmedSingle = isDim?.call(n, 1) == true;
      final dimmedTriple = isDim?.call(n, 3) == true;
      final dimmedDouble = isDim?.call(n, 2) == true;
      final singleCol = dimmedSingle
          ? _dimSingle
          : ((i % 2 == 0) ? _twiSingleDark : _twiSingleLight);
      final tripleRingCol = dimmedTriple
          ? _dimRing
          : ((i % 2 == 0) ? _twiRingMagenta : _twiRingCyan);
      final doubleRingCol = dimmedDouble
          ? _dimRing
          : ((i % 2 == 0) ? _twiRingMagenta : _twiRingCyan);

      _wedge(canvas, c, r * kBullR, r * kInnerSingleR, start, end, singleCol);
      _wedge(
          canvas, c, r * kInnerSingleR, r * kTripleR, start, end, tripleRingCol);
      _wedge(canvas, c, r * kTripleR, r * kOuterSingleR, start, end, singleCol);
      _wedge(
          canvas, c, r * kOuterSingleR, r * kDoubleR, start, end, doubleRingCol);
      _wedge(canvas, c, r * kDoubleR, r, start, end, _twiBase);

      // Segment number label, placed in the outer band.
      final midAng = (start + end) / 2;
      final lx = c.dx + math.cos(midAng) * r * 0.975;
      final ly = c.dy + math.sin(midAng) * r * 0.975;
      final tp = TextPainter(
        text: TextSpan(
          text: '$n',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 11,
            // Label dim follows the SINGLE-band (multiplier 1) result: for any
            // value-based restriction, this equals the "majority of bands" rule
            // (single + single bands both agree). 'All bands agree' is degenerate:
            // EVENS never dims any double band (doubles are always even), so a
            // label would never dim under that logic.
            color: dimmedSingle ? _dimNumber : Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
    }

    // Bull / D-Bull — normally the one bright pop on the board, but under
    // HOLY TRINITY the engine carve-out zeroes it (spec §4/§10: trinity is
    // about exactly {20, 5, 1}, so bull is deliberately excluded from the
    // blanket bull-exemption every other modifier gets) — a lit bull that
    // banks nothing is a silent trap, so it must dim like any other
    // non-scoring segment. isDim is called with multiplier 1 for bull/D-Bull
    // alike (WildcardEngine.dimPredicate ignores multiplier for segment 25,
    // mirroring applyDart's own id check) — this is safe for every other
    // predicate too, because dimPredicate already reports segment 25 as
    // scoring (false) for anything that isn't HOLY TRINITY, so ONLY EVENS/
    // ODDS and the rest of the WILDCARD modifiers (plus X01/Gotcha/Killer's
    // null predicate) never dim bull here.
    final dimmedBull = isDim?.call(25, 1) == true;
    canvas.drawCircle(
      c,
      r * kBullR,
      Paint()..color = dimmedBull ? _dimRing : DossedartTokens.yellow,
    );
    canvas.drawCircle(
      c,
      r * kDBullR,
      Paint()..color = dimmedBull ? _dimSingle : DossedartTokens.red,
    );

    // Bull edge = orange, D-Bull edge = yellow (dimmed: same dim family as
    // their respective fills, so a dimmed bull reads as a flat off disc
    // instead of keeping a bright ring outline).
    canvas.drawCircle(
      c,
      r * kBullR,
      Paint()
        ..color = dimmedBull ? _dimRing : DossedartTokens.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      c,
      r * kDBullR,
      Paint()
        ..color = dimmedBull ? _dimSingle : DossedartTokens.yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // No painter border ring — the frame is the single glow from the circular
    // BoxDecoration the cockpits wrap the board in (game_screen /
    // killer_game_screen).
  }

  void _wedge(Canvas canvas, Offset c, double rInner, double rOuter,
      double startAng, double endAng, Color fill) {
    final path = Path()
      ..moveTo(c.dx + math.cos(startAng) * rInner, c.dy + math.sin(startAng) * rInner)
      ..lineTo(c.dx + math.cos(startAng) * rOuter, c.dy + math.sin(startAng) * rOuter)
      ..arcTo(
        Rect.fromCircle(center: c, radius: rOuter),
        startAng, endAng - startAng, false,
      )
      ..lineTo(c.dx + math.cos(endAng) * rInner, c.dy + math.sin(endAng) * rInner)
      ..arcTo(
        Rect.fromCircle(center: c, radius: rInner),
        endAng, -(endAng - startAng), false,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
  }

  // Identity comparison on `isDim` won't detect a same-instance closure whose
  // captured state changed (e.g. a restriction predicate that now excludes a
  // different segment), so any non-null predicate opts into repainting on
  // every rebuild — cheap for a board this size, and a static board with a
  // null predicate keeps the old zero-repaint behaviour.
  @override
  bool shouldRepaint(_DartboardPainter oldDelegate) =>
      oldDelegate.isDim != isDim || isDim != null;
}
