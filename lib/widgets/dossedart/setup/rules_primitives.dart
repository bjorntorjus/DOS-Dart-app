import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';

/// Radio-style chip row. Tap a chip to select; selected chip turns yellow.
class ArcadeChipRow<T> extends StatelessWidget {
  const ArcadeChipRow({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<(String, T)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'VT323',
            fontSize: 13,
            color: Colors.white54,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(child: _chip(options[i].$1, options[i].$2)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _chip(String label, T optionValue) {
    final selected = optionValue == value;
    return GestureDetector(
      onTap: () => onChanged(optionValue),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? DossedartTokens.yellow : DossedartTokens.surface,
          border: Border.all(
            color: selected ? DossedartTokens.yellow : DossedartTokens.magenta,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: selected ? DossedartTokens.bg : Colors.white,
            letterSpacing: 0.5,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// A row of independent ON/OFF toggles. Each toggle has its own accent color.
/// Tuple shape: (label, value, accentColor, onChanged).
class ArcadeToggleRow extends StatelessWidget {
  const ArcadeToggleRow({super.key, required this.toggles});

  final List<(String, bool, Color, ValueChanged<bool>)> toggles;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < toggles.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _toggle(toggles[i])),
        ],
      ],
    );
  }

  Widget _toggle((String, bool, Color, ValueChanged<bool>) t) {
    final (label, value, accent, onChanged) = t;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: value ? accent.withValues(alpha: 0.15) : DossedartTokens.surface,
          border: Border.all(color: accent, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          '$label ${value ? '●' : '○'}',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 9,
            color: value ? accent : Colors.white70,
            letterSpacing: 0.5,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
