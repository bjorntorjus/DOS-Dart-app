import 'package:flutter/material.dart';

/// Arcade life hearts: live heart in [color] with glow, spent heart dimmed.
class OneUpLifePips extends StatelessWidget {
  const OneUpLifePips({super.key, required this.lives, required this.max,
      required this.color, this.size = 17});

  final int lives;
  final int max;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < max; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              i < lives ? '♥' : '♡',
              style: TextStyle(
                fontFamily: 'VT323',
                fontSize: size,
                height: 1,
                color: i < lives
                    ? color
                    : Colors.white.withValues(alpha: 0.18),
                shadows: i < lives
                    ? [Shadow(color: color, blurRadius: 6)]
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}
