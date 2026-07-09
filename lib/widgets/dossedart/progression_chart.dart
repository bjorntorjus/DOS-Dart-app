import 'package:flutter/material.dart';

import '../../models/dart_throw.dart';
import '../../stats/mode_progression.dart';
import '../../theme/dossedart_tokens.dart';

/// Palette cycling for per-player lines/legends across the DOSSEDART match
/// history views (chart lines + legend here; the round-by-round log's player
/// column headers in `game_detail_screen.dart` reuse the same list).
const dossedartPlayerPalette = [
  DossedartTokens.cyan,
  DossedartTokens.silver,
  DossedartTokens.green,
  DossedartTokens.orange,
  DossedartTokens.yellow,
  DossedartTokens.magenta,
];

/// The MATCH FLOW / SCORE PER ROUND line chart — extracted from
/// `game_detail_screen.dart` (2026-07-09) so both the MATCH DETAILS
/// drill-down and the WILDCARD post-game screen render the identical plot +
/// legend off the same painter. Callers own the outer section chrome
/// (heading, border, padding) — this widget is just the 200px plot and its
/// legend row below it.
class ProgressionChart extends StatelessWidget {
  const ProgressionChart({
    super.key,
    required this.progression,
    required this.throws,
    required this.playerNames,
  });

  final ModeProgression progression;
  final List<DartThrow> throws;
  final List<String> playerNames;

  @override
  Widget build(BuildContext context) {
    final series = [
      for (var i = 0; i < playerNames.length; i++)
        progression.seriesFor(throws, playerIndex: i),
    ];
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: CustomPaint(
            painter: _LegPainter(progression: progression, series: series),
            size: Size.infinite,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 18,
          runSpacing: 4,
          children: [
            for (var i = 0; i < playerNames.length; i++)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 16,
                    height: 3,
                    color: dossedartPlayerPalette[
                        i % dossedartPlayerPalette.length]),
                const SizedBox(width: 7),
                Text(playerNames[i],
                    style: TextStyle(
                        fontFamily: 'VT323',
                        fontSize: 15,
                        color: dossedartPlayerPalette[
                            i % dossedartPlayerPalette.length])),
              ]),
          ],
        ),
      ],
    );
  }
}

class _LegPainter extends CustomPainter {
  _LegPainter({required this.progression, required this.series});
  final ModeProgression progression;
  final List<List<num>> series;

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 40.0, padR = 16.0, padT = 14.0, padB = 24.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;

    final dataMax =
        series.expand((s) => s).fold<num>(0, (m, v) => v > m ? v : m);
    final top = progression.descending
        ? (progression.maxValue > 0 ? progression.maxValue : (dataMax > 0 ? dataMax : 1))
        : (dataMax > 0 ? dataMax : 1);
    final maxLen = series.fold<int>(1, (m, s) => s.length > m ? s.length : m);

    double xAt(int i) => padL + (maxLen > 1 ? i * plotW / (maxLen - 1) : 0);
    double yAt(num v) => padT + (1 - v / top) * plotH;

    // Gridlines + y labels (5 steps).
    for (var g = 0; g <= 4; g++) {
      final value = top * (4 - g) / 4;
      final y = padT + plotH * g / 4;
      final atZero = (4 - g) == 0;
      canvas.drawLine(
        Offset(padL, y),
        Offset(size.width - padR, y),
        Paint()
          ..color = atZero
              ? DossedartTokens.green.withValues(alpha: 0.27)
              : DossedartTokens.magenta.withValues(alpha: 0.12)
          ..strokeWidth = atZero ? 1.5 : 1,
      );
      _label(canvas, '${value.round()}', Offset(padL - 6, y),
          align: _Align.right,
          color: atZero ? DossedartTokens.green : const Color(0x66FFFFFF));
    }

    // x labels.
    for (var i = 0; i < maxLen; i++) {
      _label(canvas, i == 0 ? 'START' : 'R$i',
          Offset(xAt(i), size.height - 6),
          align: _Align.center, color: const Color(0x66FFFFFF), size: 11);
    }

    // Lines (paint opponents first so player[0] sits on top).
    for (var p = series.length - 1; p >= 0; p--) {
      final s = series[p];
      if (s.isEmpty) continue;
      final color = dossedartPlayerPalette[p % dossedartPlayerPalette.length];
      final path = Path();
      for (var i = 0; i < s.length; i++) {
        final o = Offset(xAt(i), yAt(s[i]));
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      // Soft glow underlay.
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = color.withValues(alpha: 0.55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = color);
      for (var i = 0; i < s.length; i++) {
        final finished = progression.descending && s[i] <= 0;
        canvas.drawCircle(Offset(xAt(i), yAt(s[i])), finished ? 6 : 3.4,
            Paint()..color = color);
      }
    }

    // Finish flag for race-to-0 modes.
    if (progression.descending && series.any((s) => s.isNotEmpty && s.last <= 0)) {
      _label(canvas, progression.finishLabel,
          Offset(xAt(maxLen - 1), yAt(0) - 10),
          align: _Align.right, color: DossedartTokens.yellow, size: 9, ps2p: true);
    }
  }

  void _label(Canvas canvas, String text, Offset at,
      {required _Align align,
      required Color color,
      double size = 13,
      bool ps2p = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              fontFamily: ps2p ? 'PressStart2P' : 'VT323',
              fontSize: size,
              color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      _Align.right => at.dx - tp.width,
      _Align.center => at.dx - tp.width / 2,
      _Align.left => at.dx,
    };
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_LegPainter old) =>
      old.series != series || old.progression != progression;
}

enum _Align { left, center, right }
