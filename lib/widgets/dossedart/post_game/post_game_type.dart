import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';

/// Shared type + size curves for the DOSSEDART post-game screen
/// (design fasit 2026-08-10).
///
/// The two name curves are fasit and differ on purpose: the spotlight has a
/// whole row to itself so it can start at 26 px, while a standings row shares
/// its line with a rank plate, an avatar, a headline and an Elo column, so it
/// bottoms out at 9 px. Both ellipsis rather than wrap — a wrapping name would
/// change the card height and break the "identical height per mode" rule.
class PostGameType {
  static const ps = 'PressStart2P';
  static const vt = 'VT323';

  /// Standings row name size by length: ≤8 / ≤12 / ≤16 / longer.
  static double standingsName(String n) => n.length <= 8
      ? 14
      : n.length <= 12
          ? 12
          : n.length <= 16
              ? 10
              : 9;

  /// Winner spotlight name size by the same length buckets.
  static double spotlightName(String n) => n.length <= 8
      ? 26
      : n.length <= 12
          ? 21
          : n.length <= 16
              ? 17
              : 13;

  /// [height] tightens the line box. Both arcade fonts carry generous
  /// leading, which overflows the fixed-height rows the zone budget depends
  /// on — pass 1.0 anywhere the text sits inside a pinned box.
  static TextStyle psStyle(double size,
          {Color color = Colors.white,
          double letterSpacing = 1,
          Color? glow,
          double? height}) =>
      TextStyle(
        fontFamily: ps,
        fontSize: size,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        shadows: glow == null
            ? null
            : [Shadow(color: glow.withValues(alpha: 0.67), blurRadius: 10)],
      );

  static TextStyle vtStyle(double size,
          {Color? color, double letterSpacing = 1.5, double? height}) =>
      TextStyle(
        fontFamily: vt,
        fontSize: size,
        color: color ?? Colors.white.withValues(alpha: 0.5),
        letterSpacing: letterSpacing,
        height: height,
      );

  /// Medal colour for a placement, or null below third — the plate then draws
  /// a dim neutral border instead.
  static Color? medal(int placement) => switch (placement) {
        1 => DossedartTokens.yellow,
        2 => DossedartTokens.silver,
        3 => DossedartTokens.bronze,
        _ => null,
      };
}

/// Section heading above each block in the scroll region, with an optional
/// dimmer note after it (`· 6 players`, `· partly unavailable`).
class PostGameSectionLabel extends StatelessWidget {
  const PostGameSectionLabel(this.label, {super.key, this.note});

  final String label;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(label,
              style: PostGameType.psStyle(9,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 2)),
          if (note != null) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Text(note!,
                  overflow: TextOverflow.ellipsis,
                  style: PostGameType.vtStyle(15,
                      color: Colors.white.withValues(alpha: 0.32),
                      letterSpacing: 1)),
            ),
          ],
        ],
      ),
    );
  }
}
