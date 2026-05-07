import 'package:flutter/material.dart';

/// Standard active-player ring used across all game modes. When [isActive]
/// is true the child is wrapped in a bordered, tinted container; when false
/// the wrapper reserves the same total size with a transparent border so
/// switching active player does not shift surrounding layout.
class ActivePlayerHighlight extends StatelessWidget {
  final bool isActive;
  final Widget child;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final double borderWidth;

  const ActivePlayerHighlight({
    super.key,
    required this.isActive,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.borderWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        border: Border.all(
          color: isActive ? cs.primary : Colors.transparent,
          width: borderWidth,
        ),
        borderRadius: borderRadius,
        color: isActive ? cs.primary.withValues(alpha: 0.08) : null,
      ),
      child: child,
    );
  }
}
