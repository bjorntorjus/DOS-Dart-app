import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/dossedart_tokens.dart';

/// Wraps a screen body with the DOSSEDART arcade chrome:
/// - solid CRT background
/// - static scanline overlay (3px-period horizontal lines)
/// - radial vignette darkening the corners
/// - occasional cyan "scan beam" that sweeps top → bottom once, then rests
///   ~35s before the next sweep (a subtle accent, not a constant strobe)
///
/// All overlays ignore pointer events.
class ArcadeFrame extends StatefulWidget {
  const ArcadeFrame({super.key, required this.child});

  final Widget child;

  /// Tests flip this to skip the scan-beam timer so `pumpAndSettle` can
  /// actually settle. Production keeps the default.
  @visibleForTesting
  static bool disableBeamForTest = false;

  /// How long to rest between sweeps (~1.7 sweeps/min).
  static const Duration _beamInterval = Duration(seconds: 35);

  @override
  State<ArcadeFrame> createState() => _ArcadeFrameState();
}

class _ArcadeFrameState extends State<ArcadeFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beam;
  Timer? _beamTimer;

  @override
  void initState() {
    super.initState();
    // The controller drives only the ~1.4s sweep itself; it rests at value 1
    // (beam off-screen below) between sweeps. A periodic timer kicks off the
    // next sweep, so the beam appears ~1-2 times a minute rather than looping.
    _beam = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (!ArcadeFrame.disableBeamForTest) {
      _beamTimer = Timer.periodic(ArcadeFrame._beamInterval, (_) {
        if (mounted) _beam.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    _beamTimer?.cancel();
    _beam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DossedartTokens.bg,
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          const Positioned.fill(
            child: IgnorePointer(child: _ScanlineOverlay()),
          ),
          Positioned.fill(
            child: IgnorePointer(child: _ScanBeam(controller: _beam)),
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
    final paint = Paint()..color = const Color(0x4D000000);
    for (double y = 2; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanlinePainter oldDelegate) => false;
}

class _ScanBeam extends StatelessWidget {
  const _ScanBeam({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CustomPaint(painter: _ScanBeamPainter(t: controller.value));
      },
    );
  }
}

class _ScanBeamPainter extends CustomPainter {
  _ScanBeamPainter({required this.t});
  final double t; // 0..1

  @override
  void paint(Canvas canvas, Size size) {
    // Beam height ≈ 12% of screen, sweeps from -beamH to height.
    final beamH = size.height * 0.12;
    final cy = -beamH + (size.height + beamH * 2) * t;
    final rect = Rect.fromLTWH(0, cy - beamH / 2, size.width, beamH);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0x0000E5FF),
        Color(0x2200E5FF),
        Color(0x0000E5FF),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_ScanBeamPainter oldDelegate) => oldDelegate.t != t;
}

class _VignetteOverlay extends StatelessWidget {
  const _VignetteOverlay();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
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
