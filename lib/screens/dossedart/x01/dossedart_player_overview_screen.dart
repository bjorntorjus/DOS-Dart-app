import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';
import '../../../widgets/dossedart/dossedart_crt_frame.dart';
import '../../../widgets/dossedart/dossedart_player_avatar.dart';

/// View-model for one player row in the overview.
class PlayerOverviewRow {
  const PlayerOverviewRow({
    required this.name,
    required this.avatarPath,
    required this.remaining,
    required this.lastTurnLabel,
    required this.lastTurnSum,
    required this.avg,
    required this.hitPct,
    required this.missPct,
  });

  final String name;
  final String? avatarPath;
  final int remaining;
  final String lastTurnLabel; // e.g., 'T20 · S20 · S20' or '— · — · —'
  final int lastTurnSum;
  final double avg;
  final int hitPct;
  final int missPct;
}

class DossedartPlayerOverviewScreen extends StatelessWidget {
  const DossedartPlayerOverviewScreen({
    super.key,
    required this.title,
    required this.roundNumber,
    required this.rows,
  });

  final String title; // e.g., 'CAST · X01 501'
  final int roundNumber;
  final List<PlayerOverviewRow> rows;

  static double _nameFontSize(int len) {
    if (len <= 6) return 14;
    if (len <= 10) return 12;
    return 10;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DossedartTokens.bg,
      body: DossedartCrtFrame(
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(title: title, roundNumber: roundNumber),
              const _Marquee(text: '► SCOREBOARD ◄'),
              const _ColHeader(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                  itemCount: rows.length,
                  itemBuilder: (ctx, i) => _Row(rank: i + 1, data: rows[i]),
                ),
              ),
              const _FooterMarquee(text: '★ ★ ★ INSERT DART TO CONTINUE ★ ★ ★'),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.roundNumber});
  final String title;
  final int roundNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(bottom: BorderSide(color: DossedartTokens.magenta, width: 2)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Text(
              '◀ BACK',
              style: TextStyle(
                fontFamily: 'VT323', fontSize: 18, color: DossedartTokens.cyan,
                letterSpacing: 2, height: 1,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'PressStart2P', fontSize: 11, color: DossedartTokens.yellow,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          Text(
            'RND $roundNumber',
            style: const TextStyle(
              fontFamily: 'VT323', fontSize: 14, color: Colors.white54, letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Marquee extends StatelessWidget {
  const _Marquee({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        border: const Border(bottom: BorderSide(color: Color(0x66FF00AA), width: 1)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 12,
          color: DossedartTokens.magenta,
          letterSpacing: 4,
        ),
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  const _ColHeader();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x4D00E5FF), width: 1)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 32, child: Text('#', style: _hStyle)),
          SizedBox(width: 54),
          Expanded(child: Text('PLAYER', style: _hStyle)),
          Text('REMAIN', style: _hStyle),
        ],
      ),
    );
  }

  static const _hStyle = TextStyle(
    fontFamily: 'PressStart2P', fontSize: 8, color: DossedartTokens.cyan,
    letterSpacing: 1.5,
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.rank, required this.data});
  final int rank;
  final PlayerOverviewRow data;

  @override
  Widget build(BuildContext context) {
    final nameSize = DossedartPlayerOverviewScreen._nameFontSize(data.name.length);
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x2EFFFFFF), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Line 1: rank | avatar | name | remaining
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  rank.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontFamily: 'PressStart2P', fontSize: 16,
                    color: DossedartTokens.yellow, letterSpacing: 1,
                  ),
                ),
              ),
              DossedartPlayerAvatar(
                avatarPath: data.avatarPath,
                size: 44,
                borderColor: DossedartTokens.magenta,
                borderWidth: 2,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PressStart2P', fontSize: nameSize, color: Colors.white,
                    letterSpacing: nameSize >= 13 ? 2 : 1.2,
                  ),
                ),
              ),
              Text(
                '${data.remaining}',
                style: const TextStyle(
                  fontFamily: 'PressStart2P', fontSize: 26,
                  color: DossedartTokens.magenta, letterSpacing: 1, height: 1,
                ),
              ),
            ],
          ),
          // Line 2: AVG · HIT%
          Padding(
            padding: const EdgeInsets.only(left: 88, top: 8),
            child: Text(
              'AVG ${data.avg.toStringAsFixed(1)} · HIT ${data.hitPct}%',
              style: const TextStyle(
                fontFamily: 'VT323', fontSize: 16, color: Colors.white60, letterSpacing: 1.5,
              ),
            ),
          ),
          // Line 3: LAST throws (full width)
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: DossedartTokens.yellow.withValues(alpha: 0.08),
              border: Border.all(color: DossedartTokens.yellow.withValues(alpha: 0.35), width: 1),
            ),
            child: Row(
              children: [
                const Text(
                  'LAST',
                  style: TextStyle(
                    fontFamily: 'PressStart2P', fontSize: 8,
                    color: Color(0xA6FFD200), letterSpacing: 1,
                  ),
                ),
                Expanded(
                  child: Text(
                    data.lastTurnLabel,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'VT323', fontSize: 22, letterSpacing: 2,
                      color: DossedartTokens.yellow,
                    ),
                  ),
                ),
                Text(
                  '${data.lastTurnSum}',
                  style: const TextStyle(
                    fontFamily: 'PressStart2P', fontSize: 12,
                    color: DossedartTokens.yellow,
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

class _FooterMarquee extends StatelessWidget {
  const _FooterMarquee({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Color(0x6600E5FF), width: 1)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'PressStart2P', fontSize: 9, color: DossedartTokens.cyan,
          letterSpacing: 3,
        ),
      ),
    );
  }
}
