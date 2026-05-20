import 'package:flutter/material.dart';
import '../../theme/dossedart_tokens.dart';
import 'arcade_frame.dart';

/// Wraps a screen body with the DOSSEDART CRT treatment:
/// - ArcadeFrame (scanlines, vignette, scan-beam)
/// - Inset shadows simulating CRT-glass corner-darkening
/// - 16px border radius on the inner frame
///
/// The "physical bezel" shown in design mockups (grey plastic surround
/// with power LED) is decorative-only in the mockup; in Flutter we
/// convey the CRT feel via inset shadows alone.
class DossedartCrtFrame extends StatelessWidget {
  const DossedartCrtFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DossedartTokens.bg,
      child: Stack(
        children: [
          Positioned.fill(child: ArcadeFrame(child: child)),
          // Inset shadow overlay (CRT glass-bulge darkening)
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xB3000000), // 70% black
                      blurRadius: 60,
                      spreadRadius: -30,
                      offset: Offset.zero,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
