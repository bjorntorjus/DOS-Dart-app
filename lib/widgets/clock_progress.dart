import 'package:flutter/material.dart';

class ClockProgress extends StatelessWidget {
  final int currentTarget; // 1-20 or 25
  final bool includeBull;
  final bool reverse;

  const ClockProgress({
    super.key,
    required this.currentTarget,
    required this.includeBull,
    this.reverse = false,
  });

  @override
  Widget build(BuildContext context) {
    List<int> targets;
    if (reverse) {
      if (includeBull) {
        targets = [25, ...List.generate(20, (i) => 20 - i)];
      } else {
        targets = List.generate(20, (i) => 20 - i);
      }
    } else {
      targets = List.generate(20, (i) => i + 1);
      if (includeBull) targets.add(25);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: targets.map((t) {
          final done = _isDone(t);
          final isCurrent = t == currentTarget;
          return Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? Colors.green
                  : isCurrent
                      ? Colors.amber
                      : Theme.of(context).colorScheme.surfaceContainerLow,
              border: isCurrent
                  ? Border.all(color: Colors.amber, width: 2)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              t == 25 ? 'B' : '$t',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: done || isCurrent ? Colors.black : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _isDone(int target) {
    if (reverse) {
      // In reverse: targets go down. A target is done if it's "after" currentTarget.
      if (currentTarget <= 0) return true; // All done (finished)
      if (target == 25) {
        // Bull is first in reverse+bull. Done if currentTarget <= 20.
        return currentTarget <= 20;
      }
      if (currentTarget == 25) return false; // On bull, no numbers done yet
      return target > currentTarget;
    } else {
      if (target == 25) return false; // Bull is last — only done if finished
      if (currentTarget == 25) return target <= 20;
      if (currentTarget > 20) return target <= 20; // Finished
      return target < currentTarget;
    }
  }
}
