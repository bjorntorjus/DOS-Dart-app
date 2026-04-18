import 'dart:math';
import 'package:flutter/material.dart';

class DartBoard extends StatefulWidget {
  final void Function(int segment, int multiplier) onHit;
  final VoidCallback? onOutsideTap;

  const DartBoard({super.key, required this.onHit, this.onOutsideTap});

  static const sectors = [
    20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5
  ];

  @override
  State<DartBoard> createState() => _DartBoardState();
}

class _DartBoardState extends State<DartBoard>
    with TickerProviderStateMixin {
  final Set<int> _activePointers = {};
  final List<_CloudAnimation> _clouds = [];

  @override
  void dispose() {
    for (final c in _clouds) {
      c.controller.dispose();
    }
    super.dispose();
  }

  void _showCloud(Offset position) {
    final controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    final cloud = _CloudAnimation(position: position, controller: controller);
    setState(() => _clouds.add(cloud));
    controller.forward().then((_) {
      controller.dispose();
      if (mounted) setState(() => _clouds.remove(cloud));
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
  }

  void _handlePointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
  }

  void _handleTap(TapDownDetails details, double size) {
    // Reject if multi-touch
    if (_activePointers.length > 1) return;

    final center = Offset(size / 2, size / 2);
    final tapPos = details.localPosition - center;
    final boardRadius = size / 2 * 0.88;

    final distance = tapPos.distance / boardRadius;

    // Angle: 0 = top, increasing clockwise
    var angle = atan2(tapPos.dx, -tapPos.dy);
    if (angle < 0) angle += 2 * pi;

    final sectorAngle = 2 * pi / 20;
    final sectorIndex =
        ((angle + sectorAngle / 2) % (2 * pi) / sectorAngle).floor();
    final segment = DartBoard.sectors[sectorIndex % 20];

    int hitSegment;
    int multiplier;

    if (distance <= 0.06) {
      hitSegment = 25;
      multiplier = 2; // Double bull
    } else if (distance <= 0.14) {
      hitSegment = 25;
      multiplier = 1; // Single bull
    } else if (distance <= 0.46) {
      hitSegment = segment;
      multiplier = 1; // Inner single
    } else if (distance <= 0.64) {
      hitSegment = segment;
      multiplier = 3; // Triple
    } else if (distance <= 0.86) {
      hitSegment = segment;
      multiplier = 1; // Outer single
    } else if (distance <= 1.0) {
      hitSegment = segment;
      multiplier = 2; // Double
    } else {
      // Outside the board
      if (widget.onOutsideTap != null) {
        _showCloud(details.localPosition);
        widget.onOutsideTap!();
      } else {
        hitSegment = 0;
        multiplier = 0;
        widget.onHit(hitSegment, multiplier);
      }
      return;
    }

    widget.onHit(hitSegment, multiplier);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: Listener(
            onPointerDown: _handlePointerDown,
            onPointerUp: _handlePointerUp,
            onPointerCancel: _handlePointerCancel,
            child: GestureDetector(
              onTapDown: (details) => _handleTap(details, size.toDouble()),
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _DartBoardPainter(),
                      ),
                    ),
                    // Cloud animations
                    ..._clouds.map((cloud) => _CloudWidget(cloud: cloud)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CloudAnimation {
  final Offset position;
  final AnimationController controller;
  _CloudAnimation({required this.position, required this.controller});
}

class _CloudWidget extends StatelessWidget {
  final _CloudAnimation cloud;
  const _CloudWidget({required this.cloud});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: cloud.controller,
      builder: (context, _) {
        final t = cloud.controller.value;
        final opacity = (1.0 - t).clamp(0.0, 1.0);
        final scale = 0.5 + t * 1.0;
        return Positioned(
          left: cloud.position.dx - 30 * scale,
          top: cloud.position.dy - 30 * scale,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withAlpha(120),
                      Colors.white.withAlpha(40),
                      Colors.white.withAlpha(0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DartBoardPainter extends CustomPainter {
  static const double doubleBullR = 0.06;
  static const double bullR = 0.14;
  static const double innerSingleEndR = 0.46;
  static const double tripleEndR = 0.64;
  static const double outerSingleEndR = 0.86;
  static const double doubleEndR = 1.0;

  static const sectors = [
    20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5
  ];

  static const boardBlack = Color(0xFF1A1A1A);
  static const boardCream = Color(0xFFF5E6CA);
  static const boardRed = Color(0xFFE53935);
  static const boardGreen = Color(0xFF2E7D32);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final boardRadius = min(size.width, size.height) / 2 * 0.88;
    final sectorAngle = 2 * pi / 20;

    // Background behind the board
    canvas.drawCircle(
      center,
      boardRadius * 1.12,
      Paint()..color = const Color(0xFF2C2C2C),
    );

    // Draw board base
    canvas.drawCircle(
      center,
      boardRadius * doubleEndR,
      Paint()..color = boardBlack,
    );

    // Draw each sector's rings
    for (int i = 0; i < 20; i++) {
      final startAngle = -pi / 2 + i * sectorAngle - sectorAngle / 2;

      final singleColor = i.isEven ? boardBlack : boardCream;
      final multiColor = i.isEven ? boardRed : boardGreen;

      // Double ring
      _drawSectorRing(canvas, center, boardRadius, doubleEndR, outerSingleEndR,
          startAngle, sectorAngle, multiColor);
      // Outer single
      _drawSectorRing(canvas, center, boardRadius, outerSingleEndR, tripleEndR,
          startAngle, sectorAngle, singleColor);
      // Triple ring
      _drawSectorRing(canvas, center, boardRadius, tripleEndR, innerSingleEndR,
          startAngle, sectorAngle, multiColor);
      // Inner single
      _drawSectorRing(canvas, center, boardRadius, innerSingleEndR, bullR,
          startAngle, sectorAngle, singleColor);
    }

    // Bull (outer bull - green)
    canvas.drawCircle(center, boardRadius * bullR, Paint()..color = boardGreen);
    // Double bull (inner bull - red)
    canvas.drawCircle(
        center, boardRadius * doubleBullR, Paint()..color = boardRed);

    // Wire lines
    final wirePaint = Paint()
      ..color = const Color(0xFFA0A0A0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Radial wires
    for (int i = 0; i < 20; i++) {
      final angle = -pi / 2 + i * sectorAngle - sectorAngle / 2;
      final inner =
          center + Offset(cos(angle), sin(angle)) * boardRadius * bullR;
      final outer =
          center + Offset(cos(angle), sin(angle)) * boardRadius * doubleEndR;
      canvas.drawLine(inner, outer, wirePaint);
    }

    // Ring wires
    for (final r in [
      doubleBullR,
      bullR,
      innerSingleEndR,
      tripleEndR,
      outerSingleEndR,
      doubleEndR
    ]) {
      canvas.drawCircle(center, boardRadius * r, wirePaint);
    }

    // Numbers
    for (int i = 0; i < 20; i++) {
      final angle = -pi / 2 + i * sectorAngle;
      final numberRadius = boardRadius * 1.06;
      final pos = center + Offset(cos(angle), sin(angle)) * numberRadius;

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${sectors[i]}',
          style: TextStyle(
            color: Colors.white,
            fontSize: boardRadius * 0.07,
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
