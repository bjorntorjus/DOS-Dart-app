import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';
import 'dart_zone.dart';

/// Standard dart segment order starting at 20 (top), going clockwise.
const List<int> kSegmentOrder = [
  20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5,
];

// TWILIGHT board palette (board-specific felt/ring colors — not part of the
// global role palette in DossedartTokens). Singles alternate dark/light purple
// felt; triple+double rings alternate cyan/magenta, keyed on (i % 2): dark
// segments get the cyan ring, light segments the magenta ring.
const Color _twiSingleDark = Color(0xFF1E0C40);
const Color _twiSingleLight = Color(0xFF321760);
const Color _twiRingCyan = Color(0xFF1FB0C9);
const Color _twiRingMagenta = Color(0xFFC72E94);

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
  const DossedartX01Dartboard({super.key, required this.onTap});

  final ValueChanged<DartZone> onTap;

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
            child: CustomPaint(painter: _DartboardPainter()),
          ),
        );
      },
    );
  }
}

class _DartboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);

    // Board background → solid arcade black (#0A0014), not surface-purple, so
    // the twilight felt reads as clean segments. Glow comes from the parent
    // BoxDecoration; the painter draws no border ring of its own.
    final bg = Paint()..color = DossedartTokens.bg;
    canvas.drawCircle(c, r, bg);

    const slice = math.pi * 2 / 20;
    for (int i = 0; i < 20; i++) {
      final start = -slice / 2 + i * slice - math.pi / 2;
      final end = start + slice;
      // Singles = twilight purple felt; triple + double = cyan/magenta ring.
      final singleCol = (i % 2 == 0) ? _twiSingleDark : _twiSingleLight;
      final ringCol = (i % 2 == 0) ? _twiRingCyan : _twiRingMagenta;

      _wedge(canvas, c, r * kBullR, r * kInnerSingleR, start, end, singleCol);
      _wedge(canvas, c, r * kInnerSingleR, r * kTripleR, start, end, ringCol);
      _wedge(canvas, c, r * kTripleR, r * kOuterSingleR, start, end, singleCol);
      _wedge(canvas, c, r * kOuterSingleR, r * kDoubleR, start, end, ringCol);
      _wedge(canvas, c, r * kDoubleR, r, start, end, DossedartTokens.bg);

      // Segment number label, placed in the outer band.
      final midAng = (start + end) / 2;
      final lx = c.dx + math.cos(midAng) * r * 0.975;
      final ly = c.dy + math.sin(midAng) * r * 0.975;
      final n = kSegmentOrder[i];
      final tp = TextPainter(
        text: TextSpan(
          text: '$n',
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 11,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
    }

    // Bull / D-Bull — the one bright pop on the board.
    canvas.drawCircle(c, r * kBullR, Paint()..color = DossedartTokens.yellow);
    canvas.drawCircle(c, r * kDBullR, Paint()..color = DossedartTokens.red);

    // Bull edge = orange, D-Bull edge = yellow.
    canvas.drawCircle(
      c,
      r * kBullR,
      Paint()
        ..color = DossedartTokens.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      c,
      r * kDBullR,
      Paint()
        ..color = DossedartTokens.yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // No painter border ring — the frame is a single glow on the parent.
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

  @override
  bool shouldRepaint(_DartboardPainter oldDelegate) => false;
}
