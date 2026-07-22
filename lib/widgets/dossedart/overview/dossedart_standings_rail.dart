import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';

/// Middle-truncation for rail names (fasit: "ALEXANDER…BITCH") — start and
/// end both kept so long names stay recognizable in the tight rail column.
String midTruncate(String s, int max) {
  if (s.length <= max) return s;
  final head = ((max - 1) * 0.6).ceil();
  final tail = ((max - 1) * 0.4).floor();
  return '${s.substring(0, head)}…${s.substring(s.length - tail).trimLeft()}';
}

class DossedartRailEntry {
  const DossedartRailEntry({
    required this.name,
    required this.accent,
    this.value = '',
    this.isActive = false,
    this.isLeader = false,
    this.trailing,
    this.dimmed = false,
  });

  final String name;
  final Color accent;
  final String value;
  final bool isActive;
  final bool isLeader;
  final Widget? trailing;
  final bool dimmed;
}

/// The shared standings column (grammar rule: standings are mandatory) —
/// rail-B from the X01 round, the shape every mode feeds its own data into.
/// Caller pre-sorts [entries]; rows flex to fill the available height so the
/// rail never grows the card. [bottomLabel]/[bottomValue] is the pinned
/// mode-specific bottom row (X01: TO WIN delta).
class DossedartStandingsRail extends StatelessWidget {
  const DossedartStandingsRail({
    super.key,
    required this.entries,
    required this.bottomLabel,
    required this.bottomValue,
    this.bottomDim = false,
  });

  final List<DossedartRailEntry> entries;
  final String bottomLabel;
  final String bottomValue;
  final bool bottomDim;

  static const double width = 300;

  @override
  Widget build(BuildContext context) {
    const ink = Colors.white;
    return Container(
      width: width,
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: ink.withValues(alpha: 0.12), width: 1),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++)
            Expanded(child: _RailRow(index: i, entry: entries[i])),
          Container(
            padding: const EdgeInsets.only(top: 4),
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: ink.withValues(alpha: 0.1), width: 1),
              ),
            ),
            child: Row(
              children: [
                Text(
                  bottomLabel,
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 8,
                    color: ink.withValues(alpha: 0.5),
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Text(
                  bottomValue,
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 13,
                    color: bottomDim
                        ? Colors.white.withValues(alpha: 0.3)
                        : DossedartTokens.yellow,
                    shadows: bottomDim
                        ? null
                        : [
                            Shadow(
                              color: DossedartTokens.yellow
                                  .withValues(alpha: 0.53),
                              blurRadius: 8,
                            ),
                          ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailRow extends StatelessWidget {
  const _RailRow({required this.index, required this.entry});

  final int index;
  final DossedartRailEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 1, 5, 1),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: e.isActive ? e.accent : Colors.transparent,
            width: 3,
          ),
        ),
        color: e.isActive
            ? e.accent.withValues(alpha: 0.09)
            : Colors.transparent,
      ),
      child: Opacity(
        opacity: e.isActive ? 1 : 0.75,
        child: Row(
          children: [
            SizedBox(
              width: 10,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 7,
                  color: e.isLeader
                      ? DossedartTokens.yellow
                      : Colors.white.withValues(alpha: e.dimmed ? 0.18 : 0.35),
                ),
              ),
            ),
            const SizedBox(width: 7),
            Opacity(
              opacity: e.dimmed ? 0.3 : 1,
              child: Container(width: 7, height: 7, color: e.accent),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                midTruncate(e.name.toUpperCase(), 16),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  letterSpacing: 0.5,
                  color: e.dimmed
                      ? Colors.white.withValues(alpha: 0.3)
                      : (e.isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.8)),
                ),
              ),
            ),
            if (e.isLeader) const Text('👑', style: TextStyle(fontSize: 10)),
            const Spacer(),
            if (e.trailing != null)
              e.trailing!
            else if (e.value.isNotEmpty)
              Text(
                e.value,
                style: TextStyle(
                  fontFamily: 'VT323',
                  fontSize: 18,
                  height: 1,
                  color: e.accent,
                  shadows: [Shadow(color: e.accent.withValues(alpha: 0.33), blurRadius: 6)],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
