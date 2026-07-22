import 'package:flutter/material.dart';
import '../../../models/golf_engine.dart' show golfTerm;
import '../../../theme/dossedart_tokens.dart';
import 'golf_common.dart' show golfTermColor, vsParColor, vsParLabel;

/// Windowed per-hole scorecard strip for the DOSSEDART Golf cockpit v2 —
/// 7 holes centred on the current one (clamped at either edge), replacing
/// the old always-on 1-18 strip that QA found unreadable. Current hole gets
/// a yellow highlight + `▶` marker; a trailing `SCORECARD ▸` affordance (and
/// the strip itself) opens the full [showGolfScoreSheet].
class GolfScorecardStrip extends StatelessWidget {
  const GolfScorecardStrip({
    super.key,
    required this.strokes,
    required this.currentHole,
    required this.onExpand,
  });

  /// Active player's card, length == number of holes in the round.
  final List<int?> strokes;

  /// 0-based index of the hole in progress; always highlighted yellow.
  final int currentHole;

  final VoidCallback onExpand;

  static const int _windowSize = 7;

  /// 0-based visible hole indices, [_windowSize] wide (or fewer if
  /// [strokes] has fewer holes), centred on [currentHole] with 3 holes of
  /// lookback, clamped so the window never runs past either edge.
  List<int> get _visible {
    final holes = strokes.length;
    final width = _windowSize < holes ? _windowSize : holes;
    var start = currentHole - 3;
    if (start < 0) start = 0;
    final maxStart = holes - width;
    if (start > maxStart) start = maxStart;
    return [for (var i = 0; i < width; i++) start + i];
  }

  @override
  Widget build(BuildContext context) {
    final nums = _visible;
    return InkWell(
      onTap: onExpand,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 10),
        decoration: BoxDecoration(
          color: DossedartTokens.surface,
          border: Border.all(
              color: DossedartTokens.magenta.withValues(alpha: 0.34)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'YOUR CARD · HOLES ${nums.first + 1}–${nums.last + 1}',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.6),
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Text(
                  'SCORECARD ▸',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 10,
                    color: DossedartTokens.cyan,
                    letterSpacing: 1,
                    shadows: [
                      Shadow(
                        color: DossedartTokens.cyan.withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final i in nums) ...[
                  Expanded(
                    child: _HoleCell(
                      index: i,
                      stroke: strokes[i],
                      isCurrent: i == currentHole,
                    ),
                  ),
                  if (i != nums.last) const SizedBox(width: 5),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HoleCell extends StatelessWidget {
  const _HoleCell({
    required this.index,
    required this.stroke,
    required this.isCurrent,
  });

  final int index;
  final int? stroke;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final played = stroke != null;
    final suffix = isCurrent ? 'current' : (played ? 'played' : 'empty');
    final Color accent = isCurrent
        ? DossedartTokens.yellow
        : (played ? golfTermColor(stroke!) : Colors.white24);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${index + 1}',
          style: TextStyle(
            fontFamily: 'VT323',
            fontSize: 13,
            color: isCurrent ? DossedartTokens.yellow : Colors.white38,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          key: ValueKey('golf-hole-$index-$suffix'),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isCurrent
                ? DossedartTokens.yellow.withValues(alpha: 0.16)
                : (played ? accent.withValues(alpha: 0.12) : Colors.transparent),
            border: Border.all(color: accent, width: isCurrent ? 2 : 1),
          ),
          child: Text(
            played ? '$stroke' : (isCurrent ? '▶' : '·'),
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 15,
              color: accent,
            ),
          ),
        ),
      ],
    );
  }
}

/// Opens the DOSSEDART-styled full scorecard sheet: every hole for every
/// player in a horizontally scrollable grid, a constant PAR row, per-player
/// TOTAL + vs-par columns and a term-colour legend covering the full 1-6
/// stroke range.
Future<void> showGolfScoreSheet(
  BuildContext context, {
  required List<String> names,
  required List<List<int?>> scorecards,
  required List<int> totals,
  required List<int> vsPars,
  required Set<int> skippedSeats,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: DossedartTokens.surface,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: _GolfScoreSheet(
        names: names,
        scorecards: scorecards,
        totals: totals,
        vsPars: vsPars,
        skippedSeats: skippedSeats,
      ),
    ),
  );
}

const double _kLabelColWidth = 68;
const double _kHoleColWidth = 30;
const double _kTotalColWidth = 54;
const double _kVsParColWidth = 46;

class _GolfScoreSheet extends StatelessWidget {
  const _GolfScoreSheet({
    required this.names,
    required this.scorecards,
    required this.totals,
    required this.vsPars,
    required this.skippedSeats,
  });

  final List<String> names;
  final List<List<int?>> scorecards;
  final List<int> totals;
  final List<int> vsPars;
  final Set<int> skippedSeats;

  int get _holes => scorecards.isEmpty ? 0 : scorecards.first.length;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 0, 18, 6),
            child: Text(
              'SCORECARD',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 14,
                color: DossedartTokens.cyan,
                letterSpacing: 2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: DossedartTokens.magenta.withValues(alpha: 0.34)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _headerRow(),
                    _parRow(),
                    for (var seat = 0; seat < names.length; seat++)
                      _playerRow(seat),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _legend(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _headerRow() {
    return Container(
      decoration: BoxDecoration(
        color: DossedartTokens.magenta.withValues(alpha: 0.15),
        border: Border(
          bottom: BorderSide(
              color: DossedartTokens.magenta.withValues(alpha: 0.34)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _cell('HOLE', width: _kLabelColWidth, isLabel: true),
          for (var i = 0; i < _holes; i++)
            _cell('${i + 1}', width: _kHoleColWidth, color: Colors.white70),
          _cell('TOTAL', width: _kTotalColWidth, isLabel: true, color: DossedartTokens.yellow),
          _cell('+/-', width: _kVsParColWidth, isLabel: true, color: DossedartTokens.yellow),
        ],
      ),
    );
  }

  Widget _parRow() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: Border(
          bottom: BorderSide(
              color: DossedartTokens.magenta.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _cell('PAR', width: _kLabelColWidth, color: Colors.white54),
          for (var i = 0; i < _holes; i++)
            _cell('3', width: _kHoleColWidth, color: Colors.white38),
          _cell('${3 * _holes}', width: _kTotalColWidth, color: Colors.white54),
          _cell('', width: _kVsParColWidth),
        ],
      ),
    );
  }

  Widget _playerRow(int seat) {
    final card = scorecards[seat];
    final row = Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: DossedartTokens.magenta.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _cell(names[seat].toUpperCase(),
              width: _kLabelColWidth, color: Colors.white),
          for (var i = 0; i < _holes; i++) _holeValueCell(card[i]),
          _cell('${totals[seat]}', width: _kTotalColWidth, color: Colors.white),
          _cell(vsParLabel(vsPars[seat]),
              width: _kVsParColWidth, color: vsParColor(vsPars[seat])),
        ],
      ),
    );
    if (!skippedSeats.contains(seat)) return row;
    return Opacity(opacity: 0.4, child: row);
  }

  Widget _holeValueCell(int? stroke) {
    final played = stroke != null;
    final worst = stroke == 6;
    final Color accent = played ? golfTermColor(stroke) : Colors.white24;
    return Container(
      width: _kHoleColWidth,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: worst ? accent : (played ? accent.withValues(alpha: 0.12) : Colors.transparent),
        border: Border.all(color: accent, width: worst ? 0 : 1),
      ),
      child: Text(
        played ? '$stroke' : '·',
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 11,
          color: worst ? DossedartTokens.bg : accent,
        ),
      ),
    );
  }

  Widget _cell(
    String text, {
    required double width,
    bool isLabel = false,
    Color color = Colors.white70,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 9),
      alignment: Alignment.center,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: isLabel ? 'PressStart2P' : 'VT323',
          fontSize: isLabel ? 9 : 14,
          color: color,
          letterSpacing: isLabel ? 1 : 0,
        ),
      ),
    );
  }

  Widget _legend() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        for (var stroke = 1; stroke <= 6; stroke++) _LegendSwatch(stroke: stroke),
      ],
    );
  }
}

/// One term-colour swatch in the score sheet's legend. Covers the full 1-6
/// stroke range so DOUBLE BOGEY (5) and TRIPLE BOGEY (6) both read as red,
/// with TRIPLE BOGEY (the worst outcome) getting the strongest treatment —
/// a filled swatch instead of an outline.
class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({required this.stroke});

  final int stroke;

  @override
  Widget build(BuildContext context) {
    final color = golfTermColor(stroke);
    final worst = stroke == 6;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: worst ? color : color.withValues(alpha: 0.16),
            border: Border.all(color: color, width: worst ? 2 : 1),
          ),
          child: Text(
            '$stroke',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 7,
              color: worst ? DossedartTokens.bg : color,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          golfTerm(stroke),
          style: const TextStyle(
            fontFamily: 'VT323',
            fontSize: 13,
            color: Colors.white70,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
