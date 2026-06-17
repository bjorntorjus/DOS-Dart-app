import 'package:flutter/material.dart';
import '../../models/game_history.dart';
import '../../models/saved_player.dart';
import '../../services/game_history_service.dart';
import '../../services/player_storage.dart';
import '../../stats/profile_stats.dart';
import '../../theme/dossedart_tokens.dart';
import '../../utils/rating_rank.dart';
import '../../widgets/dossedart/arcade_frame.dart';
import '../../widgets/dossedart/dossedart_player_avatar.dart';
import '../../widgets/dossedart/dossedart_top_bar.dart';
import '../../widgets/dossedart/stats/prestasjoner_section.dart';
import '../../widgets/heatmap_board.dart';
import 'game_detail_screen.dart';

/// Arcade statistics hub — 4 tabs: PROFIL / MODUS / HEATMAP / HISTORIKK.
/// Reads SavedPlayer / ModeStats / GameHistory (no new storage). The classic
/// Material StatsScreen stays for the non-arcade path; this is the DOSSEDART one.
class DossedartStatsScreen extends StatefulWidget {
  const DossedartStatsScreen({super.key});

  @override
  State<DossedartStatsScreen> createState() => _DossedartStatsScreenState();
}

class _DossedartStatsScreenState extends State<DossedartStatsScreen>
    with SingleTickerProviderStateMixin {
  static const _modes = <(String, String)>[
    ('x01', 'X01'),
    ('cricket', 'CRICKET'),
    ('aroundTheClock', 'CLOCK'),
    ('killer', 'KILLER'),
    ('halveIt', 'SPLITSCORE'),
    ('shanghai', 'SHANGHAI'),
  ];

  late final TabController _tabs = TabController(length: 4, vsync: this);
  List<SavedPlayer> _players = [];
  List<GameHistoryEntry> _history = [];
  bool _loading = true;

  /// Players shown in selectors, leaderboards and rank computations.
  /// [_players] keeps the full list so H2H rows can still resolve the
  /// names of archived opponents.
  List<SavedPlayer> get _visiblePlayers =>
      _players.where((p) => !p.archived).toList();

  String? _selectedPlayerId; // PROFIL
  int _modeIndex = 0; // MODUS
  int _heatmapModeIndex = 0; // HEATMAP
  String? _heatmapPlayerId;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (mounted) setState(() {}); // keep the arcade tab strip in sync
    });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final players = await PlayerStorage.loadPlayers();
    final history = await GameHistoryService.load();
    players.sort((a, b) => b.rating.compareTo(a.rating));
    if (!mounted) return;
    final visible = players.where((p) => !p.archived).toList();
    setState(() {
      _players = players;
      _history = history;
      _selectedPlayerId ??= visible.isNotEmpty ? visible.first.id : null;
      _heatmapPlayerId ??= visible.isNotEmpty ? visible.first.id : null;
      _loading = false;
    });
  }

  SavedPlayer? get _selected =>
      _players.where((p) => p.id == _selectedPlayerId).firstOrNull;

  int _rankOf(SavedPlayer p) => _visiblePlayers.indexWhere((x) => x.id == p.id) +
      1; // _players is rating-sorted, so the filtered view is too

  List<FormResult> _recentForm(SavedPlayer p) =>
      recentForm(_history, p.id, limit: 8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DossedartTokens.bg,
      body: ArcadeFrame(
        child: SafeArea(
          child: Column(
            children: [
              DossedartTopBar(
                title: 'STATISTICS',
                onExit: () => Navigator.of(context).maybePop(),
              ),
              if (!_loading && _visiblePlayers.isNotEmpty)
                _ArcadeTabBar(
                  labels: const ['PROFIL', 'MODUS', 'HEATMAP', 'HISTORIKK'],
                  index: _tabs.index,
                  onTap: (i) => _tabs.animateTo(i),
                ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: DossedartTokens.cyan))
                    : _visiblePlayers.isEmpty
                        ? const _EmptyState()
                        : TabBarView(
                            controller: _tabs,
                            children: [
                              _buildProfil(),
                              _buildModus(),
                              _buildHeatmap(),
                              _buildHistorikk(),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── PROFIL ─────────────────────────

  Widget _buildProfil() {
    final p = _selected ?? _visiblePlayers.first;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _PlayerSelector(
          players: _visiblePlayers,
          selectedId: p.id,
          onSelect: (id) => setState(() => _selectedPlayerId = id),
        ),
        const SizedBox(height: 14),
        _ProfileHero(player: p, rank: _rankOf(p), total: _visiblePlayers.length),
        const SizedBox(height: 14),
        if (_recentForm(p).isNotEmpty) ...[
          _SectionCard(
            title: 'FORM',
            child: _FormStrip(results: _recentForm(p)),
          ),
          const SizedBox(height: 14),
        ],
        _SectionCard(title: 'STREAKS & TOPP', child: _StreaksCard(player: p)),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'RATING HISTORY',
          child: SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _RatingSparkline(
                p.ratingHistory.map((s) => s.rating).toList(),
                deriveRankHistory(p, _visiblePlayers)
                    .map((r) => r.rank)
                    .toList(),
              ),
              size: Size.infinite,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'PER MODE',
          child: Column(children: [for (final m in _modes) _modeWinRow(p, m)]),
        ),
        if (_h2hRows(p).isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionCard(
            title: 'HEAD-TO-HEAD',
            child: Column(children: _h2hRows(p)),
          ),
        ],
        PrestasjonerSection(player: p),
      ],
    );
  }

  Widget _modeWinRow(SavedPlayer p, (String, String) mode) {
    final ms = p.modeStats[mode.$1];
    final played = ms?.played ?? 0;
    if (played == 0) return const SizedBox.shrink();
    final won = ms?.won ?? 0;
    final pct = (won * 100 / played).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(mode.$2,
                style: const TextStyle(color: DossedartTokens.phosphor, fontSize: 12)),
          ),
          Expanded(
            child: Text('$won / $played',
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          Text('$pct%',
              style: const TextStyle(
                  color: DossedartTokens.cyan, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  List<Widget> _h2hRows(SavedPlayer p) {
    final entries = p.headToHead.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));
    return entries.take(4).map((e) {
      final name = _players.where((x) => x.id == e.key).firstOrNull?.name ?? '???';
      final r = e.value;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
            Text('${r.wins}',
                style: const TextStyle(color: DossedartTokens.green, fontSize: 13)),
            const Text(' - ', style: TextStyle(color: DossedartTokens.phosphor)),
            Text('${r.losses}',
                style: const TextStyle(color: DossedartTokens.red, fontSize: 13)),
          ],
        ),
      );
    }).toList();
  }

  // ───────────────────────── MODUS ─────────────────────────

  Widget _buildModus() {
    final mode = _modes[_modeIndex];
    final ranked = _visiblePlayers
        .where((p) => (p.modeStats[mode.$1]?.played ?? 0) > 0)
        .toList()
      ..sort((a, b) {
        final aw = a.modeStats[mode.$1]?.won ?? 0;
        final bw = b.modeStats[mode.$1]?.won ?? 0;
        if (aw != bw) return bw.compareTo(aw);
        return (b.modeStats[mode.$1]?.played ?? 0)
            .compareTo(a.modeStats[mode.$1]?.played ?? 0);
      });
    return Column(
      children: [
        _ChipBar(
          labels: [for (final m in _modes) m.$2],
          selected: _modeIndex,
          onSelect: (i) => setState(() => _modeIndex = i),
        ),
        Expanded(
          child: ranked.isEmpty
              ? Center(
                  child: Text('No ${mode.$2} games yet',
                      style: const TextStyle(color: DossedartTokens.phosphor)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: ranked.length,
                  itemBuilder: (ctx, i) =>
                      _LeaderboardRow(rank: i + 1, player: ranked[i], modeKey: mode.$1),
                ),
        ),
      ],
    );
  }

  // ───────────────────────── HEATMAP ─────────────────────────

  Widget _buildHeatmap() {
    final mode = _modes[_heatmapModeIndex];
    final player = _players.where((p) => p.id == _heatmapPlayerId).firstOrNull;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _ChipBar(
          labels: [for (final m in _modes) m.$2],
          selected: _heatmapModeIndex,
          onSelect: (i) => setState(() => _heatmapModeIndex = i),
        ),
        const SizedBox(height: 12),
        _PlayerSelector(
          players: _visiblePlayers,
          selectedId: _heatmapPlayerId,
          onSelect: (id) => setState(() => _heatmapPlayerId = id),
        ),
        const SizedBox(height: 16),
        if (player != null)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: HeatmapBoard(
                counters: player.modeStats[mode.$1]?.counters ?? const {},
                playerName: '${player.name} · ${mode.$2}',
              ),
            ),
          ),
      ],
    );
  }

  // ───────────────────────── HISTORIKK ─────────────────────────

  Widget _buildHistorikk() {
    if (_history.isEmpty) {
      return const Center(
        child: Text('No games played yet',
            style: TextStyle(color: DossedartTokens.phosphor)),
      );
    }
    final sorted = [..._history]..sort((a, b) => b.date.compareTo(a.date));
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: sorted.length,
      itemBuilder: (ctx, i) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
            builder: (_) => GameDetailScreen(entry: sorted[i]))),
        child: _HistoryRow(entry: sorted[i]),
      ),
    );
  }
}

// ───────────────────────── shared sub-widgets ─────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 56, color: DossedartTokens.phosphor),
            SizedBox(height: 16),
            Text('NO SAVED PLAYERS YET',
                style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 11,
                    color: DossedartTokens.phosphor)),
          ],
        ),
      );
}

class _ArcadeTabBar extends StatelessWidget {
  const _ArcadeTabBar({required this.labels, required this.index, required this.onTap});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: i == index ? DossedartTokens.cyan : DossedartTokens.magenta.withValues(alpha: 0.4),
                        width: i == index ? 3 : 1,
                      ),
                    ),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 9,
                      letterSpacing: 1,
                      color: i == index ? DossedartTokens.cyan : DossedartTokens.phosphor,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DossedartTokens.surface,
        border: Border.all(color: DossedartTokens.cyan, width: DossedartTokens.borderThin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: DossedartTokens.cyan,
                  letterSpacing: 1.5)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _FormStrip extends StatelessWidget {
  const _FormStrip({required this.results});
  final List<FormResult> results;

  @override
  Widget build(BuildContext context) {
    (String, Color) cell(FormOutcome o) => switch (o) {
          FormOutcome.win => ('W', DossedartTokens.green),
          FormOutcome.loss => ('L', DossedartTokens.red),
          FormOutcome.draw => ('U', DossedartTokens.yellow),
        };
    // Oldest → newest reads left-to-right like a form guide.
    final ordered = results.reversed.toList();
    return Row(
      children: [
        for (final f in ordered)
          Expanded(
            child: Builder(builder: (_) {
              final (letter, c) = cell(f.outcome);
              final d = f.ratingDelta;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.07),
                  border: Border.all(color: c.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Text(letter, style: TextStyle(fontFamily: 'PressStart2P', fontSize: 11, color: c)),
                    const SizedBox(height: 5),
                    Text(
                      d == null ? '–' : '${d >= 0 ? '+' : ''}${d.round()}',
                      style: TextStyle(fontFamily: 'VT323', fontSize: 13, color: c),
                    ),
                  ],
                ),
              );
            }),
          ),
      ],
    );
  }
}

class _StreaksCard extends StatelessWidget {
  const _StreaksCard({required this.player});
  final SavedPlayer player;

  @override
  Widget build(BuildContext context) {
    final onStreak = player.currentWinStreak > 0;
    final peak = peakRating(player);
    final best = bestRank(player);
    final tiles = <(String, String, Color)>[
      (
        'NÅ PÅ RAD',
        onStreak ? '🔥 ${player.currentWinStreak}' : '${player.currentLossStreak} tap',
        onStreak ? DossedartTokens.orange : DossedartTokens.red,
      ),
      ('BESTE STREAK', '${player.bestWinStreak}', DossedartTokens.green),
      ('RATING-TOPP', peak == null ? '–' : '${peak.round()}', DossedartTokens.yellow),
      ('BESTE RANK', best == null ? '–' : '#$best', DossedartTokens.silver),
    ];
    return Row(
      children: [
        for (final (k, v, c) in tiles)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              decoration: BoxDecoration(
                  border: Border.all(color: DossedartTokens.phosphor.withValues(alpha: 0.25))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k, style: const TextStyle(fontFamily: 'VT323', fontSize: 12, color: DossedartTokens.phosphor)),
                  const SizedBox(height: 6),
                  Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PlayerSelector extends StatelessWidget {
  const _PlayerSelector({
    required this.players,
    required this.selectedId,
    required this.onSelect,
  });
  final List<SavedPlayer> players;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: players.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final p = players[i];
          final on = p.id == selectedId;
          return GestureDetector(
            onTap: () => onSelect(p.id),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DossedartPlayerAvatar(
                  size: 44,
                  borderColor: on ? DossedartTokens.cyan : DossedartTokens.phosphor,
                  avatarPath: p.avatarPath,
                  borderWidth: on ? DossedartTokens.borderActive : DossedartTokens.borderThin,
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 56,
                  child: Text(
                    p.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: on ? DossedartTokens.cyan : DossedartTokens.phosphor,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ChipBar extends StatelessWidget {
  const _ChipBar({required this.labels, required this.selected, required this.onSelect});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final on = i == selected;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: on ? DossedartTokens.cyan.withValues(alpha: 0.2) : DossedartTokens.surface,
                border: Border.all(
                  color: on ? DossedartTokens.cyan : DossedartTokens.phosphor,
                  width: DossedartTokens.borderThin,
                ),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 9,
                  color: on ? DossedartTokens.cyan : DossedartTokens.phosphor,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.player, required this.rank, required this.total});
  final SavedPlayer player;
  final int rank;
  final int total;

  @override
  Widget build(BuildContext context) {
    final rankColor = rank == 1
        ? DossedartTokens.yellow
        : rank == 2
            ? DossedartTokens.silver
            : rank == 3
                ? DossedartTokens.bronze
                : DossedartTokens.phosphor;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DossedartTokens.surface,
        border: Border.all(color: DossedartTokens.magenta, width: DossedartTokens.border),
      ),
      child: Row(
        children: [
          DossedartPlayerAvatar(
            size: 64,
            borderColor: DossedartTokens.cyan,
            avatarPath: player.avatarPath,
            borderWidth: DossedartTokens.borderActive,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('ELO ${player.rating.round()}',
                    style: const TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 11,
                        color: DossedartTokens.cyan)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('RANK #$rank/$total',
                        style: TextStyle(
                            fontFamily: 'PressStart2P', fontSize: 9, color: rankColor)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '· ${player.gamesPlayed} kamper · siden ${_monthAbbr(player.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'VT323', fontSize: 13, color: DossedartTokens.phosphor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _WinRing(won: player.gamesWon, played: player.gamesPlayed),
        ],
      ),
    );
  }
}

class _WinRing extends StatelessWidget {
  const _WinRing({required this.won, required this.played});
  final int won;
  final int played;

  @override
  Widget build(BuildContext context) {
    final pct = played > 0 ? won / played : 0.0;
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: pct,
              strokeWidth: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation(DossedartTokens.green),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${(pct * 100).round()}%',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              Text('$won-${played - won}',
                  style: const TextStyle(color: DossedartTokens.phosphor, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.rank, required this.player, required this.modeKey});
  final int rank;
  final SavedPlayer player;
  final String modeKey;

  @override
  Widget build(BuildContext context) {
    final ms = player.modeStats[modeKey];
    final played = ms?.played ?? 0;
    final won = ms?.won ?? 0;
    final best = ms?.bestScore ?? 0;
    final pct = played > 0 ? (won * 100 / played).round() : 0;
    final rankColor = rank == 1
        ? DossedartTokens.yellow
        : rank == 2
            ? DossedartTokens.silver
            : rank == 3
                ? DossedartTokens.bronze
                : DossedartTokens.phosphor;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: DossedartTokens.surface,
        border: Border.all(color: DossedartTokens.phosphor.withValues(alpha: 0.4), width: DossedartTokens.borderThin),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('$rank',
                style: TextStyle(
                    fontFamily: 'PressStart2P', fontSize: 12, color: rankColor)),
          ),
          DossedartPlayerAvatar(
            size: 32,
            borderColor: rankColor,
            avatarPath: player.avatarPath,
            borderWidth: DossedartTokens.borderThin,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          Text('$won/$played · $pct%${best > 0 ? ' · best $best' : ''}',
              style: const TextStyle(color: DossedartTokens.phosphor, fontSize: 11)),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});
  final GameHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final ranked = [...entry.players]..sort((a, b) => a.placement.compareTo(b.placement));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DossedartTokens.surface,
        border: Border.all(color: DossedartTokens.phosphor.withValues(alpha: 0.4), width: DossedartTokens.borderThin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(entry.gameMode,
                    style: const TextStyle(
                        fontFamily: 'PressStart2P', fontSize: 9, color: DossedartTokens.yellow)),
              ),
              Text(
                '${entry.date.day}.${entry.date.month}.${entry.date.year}',
                style: const TextStyle(color: DossedartTokens.phosphor, fontSize: 11),
              ),
              const SizedBox(width: 8),
              const Text('DETALJER ›',
                  style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 8,
                      color: DossedartTokens.cyan)),
            ],
          ),
          const SizedBox(height: 8),
          for (final p in ranked)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text('${p.placement}',
                        style: const TextStyle(color: DossedartTokens.phosphor, fontSize: 12)),
                  ),
                  Expanded(
                    child: Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: p.placement == 1 ? DossedartTokens.yellow : Colors.white,
                            fontSize: 13)),
                  ),
                  if (p.ratingDelta != null)
                    Text(
                      '${p.ratingDelta! >= 0 ? '+' : ''}${p.ratingDelta!.round()}',
                      style: TextStyle(
                        color: p.ratingDelta! >= 0 ? DossedartTokens.green : DossedartTokens.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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

/// Minimal arcade sparkline of a player's rating history, with markers at
/// every snapshot where the leaderboard rank changed (▲#N up / ▼#N down).
class _RatingSparkline extends CustomPainter {
  _RatingSparkline(this.values, this.ranks);
  final List<double> values;
  final List<int> ranks; // same length as values

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      final tp = TextPainter(
        text: const TextSpan(
            text: 'Not enough games yet',
            style: TextStyle(color: DossedartTokens.phosphor, fontSize: 12)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      tp.paint(canvas, Offset(0, size.height / 2 - tp.height / 2));
      return;
    }
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1 ? 1.0 : (maxV - minV);
    final dx = size.width / (values.length - 1);
    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = dx * i;
      final y = size.height - ((values[i] - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = DossedartTokens.cyan,
    );

    // Rank-change markers: a dot on the line + ▲#N / ▼#N label.
    if (ranks.length != values.length) return;
    for (int i = 1; i < values.length; i++) {
      if (ranks[i] == ranks[i - 1]) continue;
      final up = ranks[i] < ranks[i - 1]; // lower number = better
      final color = up ? DossedartTokens.green : DossedartTokens.red;
      final x = dx * i;
      final y = size.height - ((values[i] - minV) / range) * size.height;
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = color);
      final tp = TextPainter(
        text: TextSpan(
          text: '${up ? '▲' : '▼'}#${ranks[i]}',
          style: TextStyle(
              color: color, fontSize: 10, fontFamily: 'PressStart2P'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // Label above the point when rising, below when falling; clamp into bounds.
      final ly = up ? y - tp.height - 6 : y + 6;
      tp.paint(
          canvas,
          Offset((x - tp.width / 2).clamp(0.0, size.width - tp.width).toDouble(),
              ly.clamp(0.0, size.height - tp.height).toDouble()));
    }
  }

  @override
  bool shouldRepaint(_RatingSparkline old) =>
      old.values != values || old.ranks != ranks;
}

const _months = [
  'jan', 'feb', 'mar', 'apr', 'mai', 'jun',
  'jul', 'aug', 'sep', 'okt', 'nov', 'des'
];
String _monthAbbr(DateTime d) => "${_months[d.month - 1]} '${d.year % 100}";
