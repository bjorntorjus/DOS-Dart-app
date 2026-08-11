import 'package:flutter/material.dart';

import '../../../models/season.dart';
import '../../../theme/dossedart_tokens.dart';
import '../../../utils/dossedart_player_accents.dart';

const _months = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', //
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

String _day(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// The SEASONS tab: every closed season, newest first, each with its final
/// table.
///
/// Pure data in, no service lookups, so it can be pumped on its own.
class SeasonsTab extends StatelessWidget {
  const SeasonsTab({super.key, required this.seasons});

  final List<SeasonRecord> seasons;

  @override
  Widget build(BuildContext context) {
    if (seasons.isEmpty) {
      return Center(
        child: Text(
          'NO SEASONS YET',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.4),
            letterSpacing: 2,
          ),
        ),
      );
    }

    // Newest first. The all-time record (number 0) is the oldest thing there
    // is, so it sorts to the bottom naturally.
    final ordered = [...seasons]..sort((a, b) => b.number.compareTo(a.number));

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: ordered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (_, i) => _SeasonCard(season: ordered[i]),
    );
  }
}

class _SeasonCard extends StatelessWidget {
  const _SeasonCard({required this.season});

  final SeasonRecord season;

  @override
  Widget build(BuildContext context) {
    final ranked = season.ranked;
    final unranked = season.unqualified;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DossedartTokens.surface,
        border: Border.all(
            color: DossedartTokens.magenta.withValues(alpha: 0.4), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: 10),
          if (ranked.isEmpty)
            Text('NOBODY QUALIFIED',
                style: _vt(15, Colors.white.withValues(alpha: 0.4)))
          else ...[
            _columnHeads(),
            const SizedBox(height: 4),
            for (var i = 0; i < ranked.length; i++)
              _RankRow(rank: i + 1, row: ranked[i], seat: i),
          ],
          if (unranked.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('UNQUALIFIED',
                style: _ps(8, Colors.white.withValues(alpha: 0.4))),
            const SizedBox(height: 4),
            for (final r in unranked)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(r.name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              _vt(16, Colors.white.withValues(alpha: 0.45))),
                    ),
                    Text('${r.games}/$kSeasonQualifyingGames',
                        style:
                            _vt(16, Colors.white.withValues(alpha: 0.35))),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _header() {
    // The all-time record is not "season 0" — it is everything that came
    // before seasons existed, and calling it a season would be a lie.
    final title = season.isAllTime
        ? 'ALL-TIME · BEFORE SEASONS'
        : 'SEASON ${season.number}';
    final winner = season.winnerName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: _ps(11, DossedartTokens.yellow, 2)),
        const SizedBox(height: 5),
        Text(
          '${_day(season.start)} – ${_day(season.end)} ${season.end.year}'
          '${winner == null ? '' : '  ·  ${winner.toUpperCase()}'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _vt(16, Colors.white.withValues(alpha: 0.5)),
        ),
      ],
    );
  }

  Widget _columnHeads() => Row(
        children: [
          const SizedBox(width: 26),
          Expanded(
              child: Text('PLAYER',
                  style: _vt(14, Colors.white.withValues(alpha: 0.35)))),
          SizedBox(
              width: 52,
              child: Text('RATING',
                  textAlign: TextAlign.right,
                  style: _vt(14, Colors.white.withValues(alpha: 0.35)))),
          SizedBox(
              width: 36,
              child: Text('GP',
                  textAlign: TextAlign.right,
                  style: _vt(14, Colors.white.withValues(alpha: 0.35)))),
          SizedBox(
              width: 44,
              child: Text('WIN',
                  textAlign: TextAlign.right,
                  style: _vt(14, Colors.white.withValues(alpha: 0.35)))),
          SizedBox(
              width: 44,
              child: Text('HIT',
                  textAlign: TextAlign.right,
                  style: _vt(14, Colors.white.withValues(alpha: 0.35)))),
        ],
      );
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.row, required this.seat});

  final int rank;
  final SeasonPlayerRow row;
  final int seat;

  /// A null percentage means unknown — an em dash, never "0%". Season 1 has
  /// no stored throws for most of its span, and claiming a 0 % hit rate there
  /// would be inventing a fact.
  String _pct(double? v) => v == null ? '—' : '${v.round()}%';

  @override
  Widget build(BuildContext context) {
    final medal = switch (rank) {
      1 => DossedartTokens.yellow,
      2 => DossedartTokens.silver,
      3 => DossedartTokens.bronze,
      _ => null,
    };
    final accent = dossedartAccent(seat);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text('$rank',
                style: _ps(10, medal ?? Colors.white.withValues(alpha: 0.5))),
          ),
          Expanded(
            child: Text(row.name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _vt(17, accent)),
          ),
          SizedBox(
              width: 52,
              child: Text('${row.rating.round()}',
                  textAlign: TextAlign.right, style: _ps(9))),
          SizedBox(
              width: 36,
              child: Text('${row.games}',
                  textAlign: TextAlign.right,
                  style: _vt(16, Colors.white.withValues(alpha: 0.6)))),
          SizedBox(
              width: 44,
              child: Text(_pct(row.winPercent),
                  textAlign: TextAlign.right,
                  style: _vt(16, Colors.white.withValues(alpha: 0.6)))),
          SizedBox(
              width: 44,
              child: Text(_pct(row.hitPercent),
                  textAlign: TextAlign.right,
                  style: _vt(16, Colors.white.withValues(alpha: 0.6)))),
        ],
      ),
    );
  }
}

TextStyle _ps(double size,
        [Color color = Colors.white, double letterSpacing = 1]) =>
    TextStyle(
      fontFamily: 'PressStart2P',
      fontSize: size,
      color: color,
      letterSpacing: letterSpacing,
      height: 1.4,
    );

TextStyle _vt(double size, Color color) => TextStyle(
      fontFamily: 'VT323',
      fontSize: size,
      color: color,
      letterSpacing: 1,
      height: 1,
    );
