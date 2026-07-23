import 'package:flutter/material.dart';
import '../../../models/golf_engine.dart' show golfTerm;
import '../../../theme/dossedart_tokens.dart';
import 'golf_common.dart' show golfTermColor, vsParColor, vsParLabel;

const double _kCellWidth = 72;
const double _kCellGap = 6;
const double _kCellStride = _kCellWidth + _kCellGap;

/// Full 18-hole scorecard strip for the DOSSEDART Golf cockpit v3 — every
/// hole scrolls horizontally in a fixed 96px zone, auto-centring on the
/// current hole (KISS pass: replaces the v2 windowed 7-hole strip, which hid
/// holes outside the window entirely). Only the trailing `SCORECARD ▸` chip
/// opens the full [showGolfScoreSheet]; the cell row itself is just the
/// horizontal scroller and does not trigger it.
class GolfScorecardStrip extends StatefulWidget {
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

  @override
  State<GolfScorecardStrip> createState() => _GolfScorecardStripState();
}

class _GolfScorecardStripState extends State<GolfScorecardStrip> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerCurrentHole());
  }

  @override
  void didUpdateWidget(covariant GolfScorecardStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentHole != widget.currentHole) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerCurrentHole());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Scrolls so the current hole sits centred in the viewport, clamped so
  /// the strip never scrolls past either edge (fasit formula, 0-based here:
  /// `max(0, min(currentHole*stride - (viewport-cellWidth)/2, maxExtent))`).
  void _centerCurrentHole() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    final target = widget.currentHole * _kCellStride -
        (position.viewportDimension - _kCellWidth) / 2;
    final maxExtent =
        position.maxScrollExtent > 0 ? position.maxScrollExtent : 0.0;
    final clamped = target.clamp(0.0, maxExtent);
    _controller.animateTo(
      clamped,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Margin lives on the outer Padding, not the sized body below — a
      // `Container.margin` is the outermost layer of that widget's own
      // render size, which would pollute a `getSize` height check against
      // the fixed 96px zone (same gotcha as GolfLeaderboard's board key).
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        key: const Key('golfScorecardStripBody'),
        height: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StripHeader(onExpand: widget.onExpand),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                children: [
                  for (var i = 0; i < widget.strokes.length; i++) ...[
                    _HoleCell(
                      index: i,
                      stroke: widget.strokes[i],
                      isCurrent: i == widget.currentHole,
                    ),
                    if (i != widget.strokes.length - 1)
                      const SizedBox(width: _kCellGap),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StripHeader extends StatelessWidget {
  const _StripHeader({required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'YOUR CARD',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.6),
            letterSpacing: 1,
          ),
        ),
        Text(
          ' · ‹ SWIPE ›',
          style: TextStyle(
            fontFamily: 'VT323',
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onExpand,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: DossedartTokens.cyan, width: 2),
            ),
            child: Text(
              'SCORECARD ▸',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 11,
                color: DossedartTokens.cyan,
              ),
            ),
          ),
        ),
      ],
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

    final Color borderColor;
    final Color bgColor;
    final Color contentColor;
    final String content;
    final BoxShadow? glow;

    if (isCurrent) {
      borderColor = DossedartTokens.yellow;
      bgColor = DossedartTokens.yellow.withValues(alpha: 0.11);
      contentColor = DossedartTokens.yellow;
      content = '▶';
      glow = BoxShadow(
        color: DossedartTokens.yellow.withValues(alpha: 0.6),
        blurRadius: 8,
      );
    } else if (played) {
      final term = golfTermColor(stroke!);
      borderColor = term;
      bgColor = term.withValues(alpha: 0.09);
      contentColor = term;
      content = '$stroke';
      glow = null;
    } else {
      borderColor = Colors.white.withValues(alpha: 0.12);
      bgColor = Colors.transparent;
      contentColor = Colors.white.withValues(alpha: 0.25);
      content = '·';
      glow = null;
    }

    return SizedBox(
      width: _kCellWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${index + 1}',
            style: TextStyle(
              fontFamily: 'VT323',
              fontSize: 15,
              color: isCurrent
                  ? DossedartTokens.yellow
                  : Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 1),
          Container(
            key: ValueKey('golf-hole-$index-$suffix'),
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor, width: 2),
              boxShadow: glow == null ? null : [glow],
            ),
            child: Text(
              content,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 15,
                color: contentColor,
              ),
            ),
          ),
        ],
      ),
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
