import 'package:flutter/material.dart';
import '../../theme/dossedart_tokens.dart';

/// Wraps a screen body with the DOSSEDART arcade chrome:
/// - solid CRT background
/// - scanline overlay (3px-period horizontal lines)
/// - radial vignette darkening the corners
///
/// Both overlays ignore pointer events.
class ArcadeFrame extends StatelessWidget {
  const ArcadeFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DossedartTokens.bg,
      child: Stack(
        children: [
          Positioned.fill(child: child),
          const Positioned.fill(
            child: IgnorePointer(child: _ScanlineOverlay()),
          ),
          const Positioned.fill(
            child: IgnorePointer(child: _VignetteOverlay()),
          ),
        ],
      ),
    );
  }
}

class _ScanlineOverlay extends StatelessWidget {
  const _ScanlineOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ScanlinePainter());
  }
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x4D000000); // 0.3 alpha black
    for (double y = 2; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanlinePainter oldDelegate) => false;
}

class _VignetteOverlay extends StatelessWidget {
  const _VignetteOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [Colors.transparent, Color(0x99000000)],
          stops: [0.5, 1.0],
        ),
      ),
    );
  }
}
