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
        _arcadeLabel(label),
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
          color: value ? accent : DossedartTokens.surface,
          border: Border.all(
            color: value ? DossedartTokens.yellow : accent.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '$label ${value ? '●' : '○'}',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 9,
            color: value ? DossedartTokens.bg : accent.withValues(alpha: 0.6),
            fontWeight: value ? FontWeight.bold : FontWeight.normal,
            letterSpacing: 0.5,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// `[-] N [+]` stepper for range config. Disabled buttons do not call onChanged.
class ArcadeStepper extends StatelessWidget {
  const ArcadeStepper({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canDec = value > min;
    final canInc = value < max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _arcadeLabel(label),
        Row(
          children: [
            _button('-', canDec, () => onChanged(value - 1)),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: DossedartTokens.magenta, width: 2),
                  color: DossedartTokens.surface,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$value',
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            _button('+', canInc, () => onChanged(value + 1)),
          ],
        ),
      ],
    );
  }

  Widget _button(String glyph, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 48,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: enabled ? DossedartTokens.yellow : DossedartTokens.disabledFill,
          border: Border.all(
            color: enabled ? DossedartTokens.yellow : DossedartTokens.disabledBorder,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          glyph,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 16,
            color: enabled ? DossedartTokens.bg : DossedartTokens.disabledFg,
          ),
        ),
      ),
    );
  }
}

/// Section label used above `ArcadeChipRow` and `ArcadeStepper`.
/// Matches the muted-VT323 label style shared across DOSSEDART RULES.
Widget _arcadeLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'VT323',
          fontSize: 13,
          color: Colors.white54,
          letterSpacing: 2,
        ),
      ),
    );
