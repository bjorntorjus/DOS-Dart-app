import 'package:flutter/material.dart';
import '../../models/achievement.dart';
import '../../theme/dossedart_tokens.dart';

/// Hexagon medal: tier-colored frame + glyph. Locked badges render dimmed.
/// Accepts either an icon glyph (today) or an asset glyph (later) without any
/// call-site change (spec decision #7).
class AchievementMedal extends StatelessWidget {
  const AchievementMedal({
    super.key,
    required this.achievement,
    this.unlocked = true,
    this.size = 64,
  });

  final Achievement achievement;
  final bool unlocked;
  final double size;

  static Color tierColor(AchievementTier tier) {
    switch (tier) {
      case AchievementTier.bronze:
        return DossedartTokens.bronze;
      case AchievementTier.silver:
        return DossedartTokens.silver;
      case AchievementTier.gold:
        return DossedartTokens.yellow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color =
        unlocked ? tierColor(achievement.tier) : DossedartTokens.disabledFg;
    final glyph = achievement.glyph;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HexPainter(
          fill: unlocked
              ? color.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.03),
          border: color,
          glow: unlocked,
        ),
        child: Center(
          child: glyph.isAsset
              ? Opacity(
                  opacity: unlocked ? 1 : 0.4,
                  child: Image.asset(glyph.assetPath!,
                      width: size * 0.5, height: size * 0.5),
                )
              : Icon(glyph.icon, color: color, size: size * 0.42),
        ),
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  _HexPainter({required this.fill, required this.border, required this.glow});
  final Color fill;
  final Color border;
  final bool glow;

  Path _hex(Size s) {
    final w = s.width, h = s.height;
    return Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.25)
      ..lineTo(w, h * 0.75)
      ..lineTo(w * 0.5, h)
      ..lineTo(0, h * 0.75)
      ..lineTo(0, h * 0.25)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _hex(size);
    canvas.drawPath(path, Paint()..color = fill);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = border;
    if (glow) {
      stroke.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    }
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_HexPainter old) =>
      old.fill != fill || old.border != border || old.glow != glow;
}
