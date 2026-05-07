import 'dart:math';
import 'package:flutter/material.dart';

/// Heatmap gradient — DO NOT migrate to colorScheme. These are data-viz
/// colors selected to be perceptually distinct and color-blind tolerant.
class _HeatmapPalette {
  static const cold = Color(0xFF1565C0);    // blue
  static const cool = Color(0xFF00ACC1);    // teal
  static const mid = Color(0xFF4CAF50);     // green
  static const warm = Color(0xFFFFB300);    // amber
  static const hot = Color(0xFFE53935);     // red
  static const empty = Color(0xFF1A1A1A);   // empty cell
  static const board = Color(0xFF2C2C2C);   // board background
  static const wireframe = Color(0xFFA0A0A0); // grid lines
}

/// A non-interactive dart board that colors segments based on hit frequency.
/// Accepts a counters map with keys like 'seg_20', 'seg_20_t', 'seg_20_d', 'seg_20_s'.
class HeatmapBoard extends StatelessWidget {
  final Map<String, int> counters;
  final String? playerName;

  const HeatmapBoard({super.key, required this.counters, this.playerName});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (playerName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              playerName!,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        AspectRatio(
          aspectRatio: 1,
          child: CustomPaint(
            painter: _HeatmapPainter(counters: counters),
          ),
        ),
      ],
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  static const double doubleBullR = 0.06;
  static const double bullR = 0.14;
  static const double innerSingleEndR = 0.46;
  static const double tripleEndR = 0.64;
  static const double outerSingleEndR = 0.86;
  static const double doubleEndR = 1.0;

  static const sectors = [
    20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5
  ];

  final Map<String, int> counters;

  _HeatmapPainter({required this.counters});

  /// Get hit count for a specific segment+zone combination.
  int _getHits(int segment, String suffix) {
    return counters['seg_${segment}_$suffix'] ?? 0;
  }

  int _getSegmentTotal(int segment) {
    return counters['seg_$segment'] ?? 0;
  }

  /// Returns a color from cold (blue) to hot (red) based on intensity 0.0-1.0.
  Color _heatColor(double intensity) {
    if (intensity <= 0) return _HeatmapPalette.empty.withAlpha(180);
    // Blue -> Cyan -> Green -> Yellow -> Red
    final clamped = intensity.clamp(0.0, 1.0);
    if (clamped < 0.25) {
      return Color.lerp(
        _HeatmapPalette.cold,
        _HeatmapPalette.cool,
        clamped / 0.25,
      )!.withAlpha(200);
    } else if (clamped < 0.5) {
      return Color.lerp(
        _HeatmapPalette.cool,
        _HeatmapPalette.mid,
        (clamped - 0.25) / 0.25,
      )!.withAlpha(200);
    } else if (clamped < 0.75) {
      return Color.lerp(
        _HeatmapPalette.mid,
        _HeatmapPalette.warm,
        (clamped - 0.5) / 0.25,
      )!.withAlpha(200);
    } else {
      return Color.lerp(
        _HeatmapPalette.warm,
        _HeatmapPalette.hot,
        (clamped - 0.75) / 0.25,
      )!.withAlpha(220);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final boardRadius = min(size.width, size.height) / 2 * 0.88;
    final sectorAngle = 2 * pi / 20;

    // Compute max hits per zone type for normalization
    int maxSingle = 0, maxDouble = 0, maxTriple = 0, maxBull = 0;
    for (int seg = 1; seg <= 20; seg++) {
      final s = _getHits(seg, 's');
      final d = _getHits(seg, 'd');
      final t = _getHits(seg, 't');
      if (s > maxSingle) maxSingle = s;
      if (d > maxDouble) maxDouble = d;
      if (t > maxTriple) maxTriple = t;
    }
    final bullSingle = _getHits(25, 's');
    final bullDouble = _getHits(25, 'd');
    maxBull = max(bullSingle, bullDouble);

    // Use overall max for consistent coloring
    final maxHits = [maxSingle, maxDouble, maxTriple, maxBull]
        .reduce((a, b) => a > b ? a : b);
    if (maxHits == 0) {
      // No data — draw greyed-out board
      _drawEmptyBoard(canvas, center, boardRadius, sectorAngle);
      return;
    }

    // Background
    canvas.drawCircle(
      center,
      boardRadius * 1.12,
      Paint()..color = _HeatmapPalette.board,
    );
    canvas.drawCircle(
      center,
      boardRadius * doubleEndR,
      Paint()..color = _HeatmapPalette.empty,
    );

    // Draw heatmap sectors
    for (int i = 0; i < 20; i++) {
      final seg = sectors[i];
      final startAngle = -pi / 2 + i * sectorAngle - sectorAngle / 2;

      final singleHits = _getHits(seg, 's');
      final doubleHits = _getHits(seg, 'd');
      final tripleHits = _getHits(seg, 't');

      // Double ring
      _drawSectorRing(canvas, center, boardRadius, doubleEndR, outerSingleEndR,
          startAngle, sectorAngle, _heatColor(doubleHits / maxHits));
      // Outer single (counts as single)
      _drawSectorRing(canvas, center, boardRadius, outerSingleEndR, tripleEndR,
          startAngle, sectorAngle, _heatColor(singleHits / maxHits * 0.5));
      // Triple ring
      _drawSectorRing(canvas, center, boardRadius, tripleEndR, innerSingleEndR,
          startAngle, sectorAngle, _heatColor(tripleHits / maxHits));
      // Inner single
      _drawSectorRing(canvas, center, boardRadius, innerSingleEndR, bullR,
          startAngle, sectorAngle, _heatColor(singleHits / maxHits * 0.5));
    }

    // Bull zones
    canvas.drawCircle(center, boardRadius * bullR,
        Paint()..color = _heatColor(bullSingle / maxHits));
    canvas.drawCircle(center, boardRadius * doubleBullR,
        Paint()..color = _heatColor(bullDouble / maxHits));

    // Wire lines
    _drawWires(canvas, center, boardRadius, sectorAngle);

    // Segment numbers with hit counts
    for (int i = 0; i < 20; i++) {
      final angle = -pi / 2 + i * sectorAngle;
      final numberRadius = boardRadius * 1.06;
      final pos = center + Offset(cos(angle), sin(angle)) * numberRadius;
      final total = _getSegmentTotal(sectors[i]);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${sectors[i]}',
          style: TextStyle(
            color: Colors.white,
            fontSize: boardRadius * 0.065,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        pos - Offset(textPainter.width / 2, textPainter.height / 2),
      );

      // Small count below number
      if (total > 0) {
        final countPainter = TextPainter(
          text: TextSpan(
            text: '$total',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: boardRadius * 0.04,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        countPainter.layout();
        final countPos = center +
            Offset(cos(angle), sin(angle)) * (boardRadius * 1.06 + boardRadius * 0.06);
        countPainter.paint(
          canvas,
          countPos - Offset(countPainter.width / 2, countPainter.height / 2),
        );
      }
    }
  }

  void _drawEmptyBoard(
      Canvas canvas, Offset center, double boardRadius, double sectorAngle) {
    canvas.drawCircle(
      center,
      boardRadius * 1.12,
      Paint()..color = _HeatmapPalette.board,
    );
    canvas.drawCircle(
      center,
      boardRadius * doubleEndR,
      Paint()..color = _HeatmapPalette.empty.withAlpha(180),
    );

    for (int i = 0; i < 20; i++) {
      final startAngle = -pi / 2 + i * sectorAngle - sectorAngle / 2;
      final color = _HeatmapPalette.empty.withAlpha(180);
      _drawSectorRing(canvas, center, boardRadius, doubleEndR, outerSingleEndR,
          startAngle, sectorAngle, color);
      _drawSectorRing(canvas, center, boardRadius, outerSingleEndR, tripleEndR,
          startAngle, sectorAngle, color);
      _drawSectorRing(canvas, center, boardRadius, tripleEndR, innerSingleEndR,
          startAngle, sectorAngle, color);
      _drawSectorRing(canvas, center, boardRadius, innerSingleEndR, bullR,
          startAngle, sectorAngle, color);
    }
    canvas.drawCircle(
        center, boardRadius * bullR, Paint()..color = _HeatmapPalette.empty.withAlpha(180));
    canvas.drawCircle(
        center, boardRadius * doubleBullR, Paint()..color = _HeatmapPalette.empty.withAlpha(180));

    _drawWires(canvas, center, boardRadius, sectorAngle);

    // Numbers
    for (int i = 0; i < 20; i++) {
      final angle = -pi / 2 + i * sectorAngle;
      final pos =
          center + Offset(cos(angle), sin(angle)) * (boardRadius * 1.06);
      final tp = TextPainter(
        text: TextSpan(
          text: '${sectors[i]}',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: boardRadius * 0.065,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    // "No data" text
    final noDataPainter = TextPainter(
      text: TextSpan(
        text: 'No data',
        style: TextStyle(color: Colors.grey[500], fontSize: boardRadius * 0.1),
      ),
      textDirection: TextDirection.ltr,
    );
    noDataPainter.layout();
    noDataPainter.paint(
      canvas,
      center - Offset(noDataPainter.width / 2, noDataPainter.height / 2),
    );
  }

  void _drawWires(
      Canvas canvas, Offset center, double boardRadius, double sectorAngle) {
    final wirePaint = Paint()
      ..color = _HeatmapPalette.wireframe.withAlpha(100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 0; i < 20; i++) {
      final angle = -pi / 2 + i * sectorAngle - sectorAngle / 2;
      final inner =
          center + Offset(cos(angle), sin(angle)) * boardRadius * bullR;
      final outer =
          center + Offset(cos(angle), sin(angle)) * boardRadius * doubleEndR;
      canvas.drawLine(inner, outer, wirePaint);
    }
    for (final r in [
      doubleBullR, bullR, innerSingleEndR, tripleEndR, outerSingleEndR, doubleEndR
    ]) {
      canvas.drawCircle(center, boardRadius * r, wirePaint);
    }
  }

  void _drawSectorRing(
    Canvas canvas,
    Offset center,
    double boardRadius,
    double outerR,
    double innerR,
    double startAngle,
    double sweepAngle,
    Color color,
  ) {
    final path = Path();
    final outerRect =
        Rect.fromCircle(center: center, radius: boardRadius * outerR);
    final innerRect =
        Rect.fromCircle(center: center, radius: boardRadius * innerR);

    path.arcTo(outerRect, startAngle, sweepAngle, true);
    final innerEndAngle = startAngle + sweepAngle;
    path.lineTo(
      center.dx + cos(innerEndAngle) * boardRadius * innerR,
      center.dy + sin(innerEndAngle) * boardRadius * innerR,
    );
    path.arcTo(innerRect, innerEndAngle, -sweepAngle, false);
    path.close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) =>
      oldDelegate.counters != counters;
}
