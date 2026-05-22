import 'package:flutter/material.dart';
import '../../theme/dossedart_tokens.dart';
import 'arcade_frame.dart';

/// Wraps a screen body with the DOSSEDART CRT treatment — delegates to
/// [ArcadeFrame] (scanlines, vignette, scan-beam) on top of the DOSSEDART
/// background color.
class DossedartCrtFrame extends StatelessWidget {
  const DossedartCrtFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DossedartTokens.bg,
      child: ArcadeFrame(child: child),
    );
  }
}
