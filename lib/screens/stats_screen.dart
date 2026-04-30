import 'dart:math';
import 'package:flutter/material.dart';
import '../models/saved_player.dart';
import '../models/game_history.dart';
import '../services/player_storage.dart';
import '../services/game_history_service.dart';
import '../widgets/player_avatar.dart';
import '../widgets/heatmap_board.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  List<SavedPlayer> _players = [];
  List<GameHistoryEntry> _history = [];
  bool _isLoading = true;
  late TabController _tabController;
  String? _heatmapPlayer1Id;
  String? _heatmapPlayer2Id;
  String _heatmapMode = 'x01';

  static const _modes = [
    ('x01', 'X01'),
    ('cricket', 'Cricket'),
    ('aroundTheClock', 'Clock'),
    ('killer', 'Killer'),
    ('halveIt', 'Halve It'),
  ];

  @override
  void initState() {
    super.initState();
    // Players + 5 modes + Heatmap + History = 9 tabs
    _tabController = TabController(length: 3 + _modes.length, vsync: this);
    _loadPlayers();
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPlayers() async {
    final players = await PlayerStorage.loadPlayers();
    setState(() {
      _players = players;
      _isLoading = false;
    });
  }

  Future<void> _loadHistory() async {
    final history = await GameHistoryService.load();
    if (mounted) setState(() => _history = history);
  }

  Future<void> _deletePlayer(SavedPlayer player) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete player?'),
        content: Text('Delete ${player.name} and all statistics?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await PlayerStorage.deletePlayer(player.id);
      _loadPlayers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            const Tab(text: 'Players'),
            ..._modes.map((m) => Tab(text: m.$2)),
            const Tab(text: 'Heatmap'),
            const Tab(text: 'History'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _players.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bar_chart, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No saved players yet',
                        style: TextStyle(color: Colors.grey, fontSize: 18),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Save players in game setup\nto track statistics',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPlayersTab(),
                    ..._modes.map((m) => _buildModeTab(m.$1, m.$2)),
                    _buildHeatmapTab(),
                    _buildHistoryTab(),
                  ],
                ),
    );
  }

  // ──────────────────────────────────────────
  // PLAYERS TAB
  // ──────────────────────────────────────────

  Widget _buildPlayersTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _players.length,
      itemBuilder: (context, index) => _buildPlayerCard(_players[index]),
    );
  }

  Widget _buildPlayerCard(SavedPlayer p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with avatar
            Row(
              children: [
                PlayerAvatar(
                  avatarPath: p.avatarPath,
                  name: p.name,
                  radius: 22,
                  backgroundColor: Colors.blue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Rating: ${p.rating.round()}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                  onPressed: () => _deletePlayer(p),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Overview
            _statRow(
              'Games',
              '${p.gamesPlayed} (won ${p.gamesWon})'
              '${p.gamesPlayed > 0 ? ' — ${(p.winRate * 100).toStringAsFixed(0)}%' : ''}',
            ),
            const SizedBox(height: 4),
            _statRow(
              'Average per round',
              p.totalTurns > 0 ? p.averageTurnScore.toStringAsFixed(1) : '-',
            ),
            const SizedBox(height: 4),
            _statRow(
              'Best round',
              p.highestTurnScore > 0 ? '${p.highestTurnScore}' : '-',
            ),
            const SizedBox(height: 4),
            _statRow(
              'Mid-game joins / leaves',
              '${p.gamesJoinedMidway} / ${p.gamesLeftMidway}',
            ),
            ..._buildPlayerInsights(p),

            // Head-to-head
            if (p.headToHead.isNotEmpty) ...[
              const SizedBox(height: 4),
              _buildSection(
                title: 'Head-to-head',
                icon: Icons.people,
                child: Column(
                  children: p.headToHead.entries.map((e) {
                    final opponentName = _findPlayerName(e.key);
                    final h = e.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: _statRow(
                        'vs $opponentName',
                        '${h.wins}W-${h.losses}L${h.draws > 0 ? '-${h.draws}D' : ''}',
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            // Rating history graph
            if (p.ratingHistory.length >= 2) ...[
              const SizedBox(height: 4),
              _buildSection(
                title: 'Rating history',
                icon: Icons.show_chart,
                child: SizedBox(
                  height: 120,
                  child: CustomPaint(
                    size: const Size(double.infinity, 120),
                    painter: _RatingGraphPainter(
                      snapshots: p.ratingHistory,
                      lineColor: Colors.blue,
                      textColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // GAME MODE TABS
  // ──────────────────────────────────────────

  Widget _buildModeTab(String modeKey, String modeLabel) {
    final playersWithMode = _players
        .where((p) => p.modeStats.containsKey(modeKey))
        .toList()
      ..sort((a, b) {
        final aMs = a.modeStats[modeKey]!;
        final bMs = b.modeStats[modeKey]!;
        final aWr = aMs.played > 0 ? aMs.won / aMs.played : 0.0;
        final bWr = bMs.played > 0 ? bMs.won / bMs.played : 0.0;
        if (bWr != aWr) return bWr.compareTo(aWr);
        return bMs.played.compareTo(aMs.played);
      });

    if (playersWithMode.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_esports, size: 48, color: Theme.of(context).colorScheme.surfaceContainer),
            const SizedBox(height: 16),
            Text(
              'No $modeLabel games played yet',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55), fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: playersWithMode.length,
      itemBuilder: (context, index) {
        final p = playersWithMode[index];
        final ms = p.modeStats[modeKey]!;
        return _buildModePlayerCard(p, ms, modeKey, index);
      },
    );
  }

  Widget _buildModePlayerCard(SavedPlayer p, ModeStats ms, String modeKey, int rank) {
    final winRate = ms.played > 0
        ? (ms.won / ms.played * 100).toStringAsFixed(0)
        : '0';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with rank, avatar, name, win rate
            Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '${rank + 1}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: rank == 0
                          ? Theme.of(context).colorScheme.tertiary
                          : rank == 1
                              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                              : rank == 2
                                  ? Colors.brown[300]
                                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                PlayerAvatar(
                  avatarPath: p.avatarPath,
                  name: p.name,
                  radius: 20,
                  backgroundColor: Colors.blue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${ms.played} games, ${ms.won} won',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$winRate%',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: int.parse(winRate) >= 50
                            ? Colors.green
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      'win rate',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Mode-specific detailed stats
            if (ms.counters.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ..._buildModeDetailStats(ms, modeKey),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildModeDetailStats(ModeStats ms, String modeKey) {
    switch (modeKey) {
      case 'x01':
        return _buildX01Stats(ms);
      case 'killer':
        return _buildKillerStats(ms);
      case 'halveIt':
        return _buildHalveItStats(ms);
      case 'cricket':
        return _buildCricketStats(ms);
      case 'aroundTheClock':
        return _buildClockStats(ms);
      default:
        return [];
    }
  }

  List<Widget> _buildX01Stats(ModeStats ms) {
    final totalTurns = ms.get('totalTurns');
    final totalTurnScore = ms.get('totalTurnScore');
    final avg3Dart = totalTurns > 0
        ? (totalTurnScore / totalTurns).toStringAsFixed(1)
        : '-';
    final highestTurn = ms.get('highestTurn');
    final turnsOver100 = ms.get('turnsOver100');
    final doublesHit = ms.get('doublesHit');
    final triplesHit = ms.get('triplesHit');
    final bullsHit = ms.get('bullsHit');
    final misses = ms.get('misses');
    final totalDarts = ms.get('totalDarts');
    final checkouts = ms.get('checkouts');
    final bestCheckout = ms.get('bestCheckout');

    final missRate = totalDarts > 0
        ? (misses / totalDarts * 100).toStringAsFixed(0)
        : '0';
    final doubleRate = totalDarts > 0
        ? (doublesHit / totalDarts * 100).toStringAsFixed(1)
        : '0';
    final tripleRate = totalDarts > 0
        ? (triplesHit / totalDarts * 100).toStringAsFixed(1)
        : '0';

    return [
      _buildStatsGrid([
        _StatItem('⚡', 'Best 3 darts', highestTurn > 0 ? '$highestTurn' : '-'),
        _StatItem('📊', '3-dart avg', avg3Dart),
        _StatItem('💯', '100+ turns', '$turnsOver100'),
        _StatItem('🎯', 'Checkouts', '$checkouts'),
        _StatItem('🏆', 'Best checkout', bestCheckout > 0 ? '$bestCheckout' : '-'),
        _StatItem('🎲', 'Total darts', '$totalDarts'),
        _StatItem('2×', 'Doubles', '$doublesHit ($doubleRate%)'),
        _StatItem('3×', 'Triples', '$triplesHit ($tripleRate%)'),
        _StatItem('🐂', 'Bulls', '$bullsHit'),
        _StatItem('✕', 'Misses', '$misses ($missRate%)'),
      ]),
    ];
  }

  List<Widget> _buildKillerStats(ModeStats ms) {
    final kills = ms.get('kills');
    final shieldsGained = ms.get('shieldsGained');
    final attacksDealt = ms.get('attacksDealt');
    final attacksReceived = ms.get('attacksReceived');
    final selfHits = ms.get('selfHits');

    // Most aggressive badge
    final isAggressive = attacksDealt >= 5;

    return [
      _buildStatsGrid([
        _StatItem('⚔️', 'Kills', '$kills'),
        _StatItem('💥', 'Damage dealt', '$attacksDealt'),
        _StatItem('🛡️', 'Shields earned', '$shieldsGained'),
        _StatItem('💔', 'Damage taken', '$attacksReceived'),
        _StatItem('🤦', 'Self-inflicted', '$selfHits'),
      ]),
      if (isAggressive)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(25),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.withAlpha(60)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⚔️', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  'Aggressive Player!',
                  style: TextStyle(
                    color: Colors.red[300],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _buildHalveItStats(ModeStats ms) {
    final bestScore = ms.get('bestScore');
    final totalScore = ms.get('totalScore');
    final totalGames = ms.get('totalGames');
    final avgScore = totalGames > 0
        ? (totalScore / totalGames).toStringAsFixed(0)
        : '-';
    final biggestHalving = ms.get('biggestHalving');
    final roundsHit = ms.get('roundsHit');
    final totalRounds = ms.get('totalRounds');
    final hitRate = totalRounds > 0
        ? (roundsHit / totalRounds * 100).toStringAsFixed(0)
        : '0';
    final totalDarts = ms.get('totalDarts');
    final misses = ms.get('misses');

    return [
      _buildStatsGrid([
        _StatItem('🏆', 'Best score', bestScore > 0 ? '$bestScore' : '-'),
        _StatItem('📊', 'Avg score', avgScore),
        _StatItem('📉', 'Worst halving', biggestHalving > 0 ? '-$biggestHalving' : '-'),
        _StatItem('✅', 'Hit rate', '$hitRate% ($roundsHit/$totalRounds)'),
        _StatItem('🎲', 'Total darts', '$totalDarts'),
        _StatItem('✕', 'Misses', '$misses'),
      ]),
    ];
  }

  List<Widget> _buildCricketStats(ModeStats ms) {
    final totalDarts = ms.get('totalDarts');
    final closedTargets = ms.get('closedTargets');
    final totalPoints = ms.get('totalPoints');
    final bestPoints = ms.get('bestPoints');
    final marksScored = ms.get('marksScored');
    final misses = ms.get('misses');
    final marksPerDart = totalDarts > 0
        ? (marksScored / totalDarts).toStringAsFixed(2)
        : '-';

    return [
      _buildStatsGrid([
        _StatItem('🎯', 'Targets closed', '$closedTargets'),
        _StatItem('📊', 'Marks/dart', marksPerDart),
        _StatItem('🏆', 'Best game pts', bestPoints > 0 ? '$bestPoints' : '-'),
        _StatItem('💰', 'Total points', '$totalPoints'),
        _StatItem('🎲', 'Total darts', '$totalDarts'),
        _StatItem('✕', 'Misses', '$misses'),
      ]),
    ];
  }

  List<Widget> _buildClockStats(ModeStats ms) {
    final totalDarts = ms.get('totalDarts');
    final totalHits = ms.get('totalHits');
    final misses = ms.get('misses');
    final finished = ms.get('finished');
    final bestDartCount = ms.get('bestDartCount');
    final hitRate = totalDarts > 0
        ? (totalHits / totalDarts * 100).toStringAsFixed(0)
        : '0';

    return [
      _buildStatsGrid([
        _StatItem('🎯', 'Hit rate', '$hitRate%'),
        _StatItem('✅', 'Finishes', '$finished'),
        _StatItem('⚡', 'Best finish', bestDartCount > 0 ? '$bestDartCount darts' : '-'),
        _StatItem('🎲', 'Total darts', '$totalDarts'),
        _StatItem('🎯', 'Total hits', '$totalHits'),
        _StatItem('✕', 'Misses', '$misses'),
      ]),
    ];
  }

  /// Builds a compact 2-column grid of stat items
  Widget _buildStatsGrid(List<_StatItem> items) {
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(child: _buildStatChip(items[i])),
              const SizedBox(width: 8),
              if (i + 1 < items.length)
                Expanded(child: _buildStatChip(items[i + 1]))
              else
                const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _buildStatChip(_StatItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Text(item.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55), fontSize: 10),
                ),
                Text(
                  item.value,
                  style: const TextStyle(
                    fontSize: 13,
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

  // ──────────────────────────────────────────
  // SHARED WIDGETS
  // ──────────────────────────────────────────

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      leading: Icon(icon, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      children: [child],
    );
  }

  String _findPlayerName(String id) {
    final match = _players.where((p) => p.id == id);
    if (match.isNotEmpty) return match.first.name;
    return 'Unknown';
  }

  Widget _statRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(label,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 14)),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────
  // HEATMAP TAB
  // ──────────────────────────────────────────

  Widget _buildHeatmapTab() {
    final modeOptions = _modes.map((m) => m.$1).toList();
    final modeLabels = {for (final m in _modes) m.$1: m.$2};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode selector
          Row(
            children: [
              const Text('Mode: ', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: SegmentedButton<String>(
                  segments: modeOptions
                      .map((m) => ButtonSegment(value: m, label: Text(modeLabels[m]!)))
                      .toList(),
                  selected: {_heatmapMode},
                  onSelectionChanged: (s) =>
                      setState(() => _heatmapMode = s.first),
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(
                      TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Player 1 selector
          _buildHeatmapPlayerDropdown(
            label: 'Player 1',
            value: _heatmapPlayer1Id,
            onChanged: (id) => setState(() => _heatmapPlayer1Id = id),
          ),
          const SizedBox(height: 8),

          // Player 2 selector (optional)
          _buildHeatmapPlayerDropdown(
            label: 'Player 2 (compare)',
            value: _heatmapPlayer2Id,
            onChanged: (id) => setState(() => _heatmapPlayer2Id = id),
            allowNone: true,
          ),
          const SizedBox(height: 16),

          // Heatmap boards
          if (_heatmapPlayer1Id != null) ...[
            if (_heatmapPlayer2Id != null && _heatmapPlayer2Id != _heatmapPlayer1Id)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildHeatmapForPlayer(_heatmapPlayer1Id!)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildHeatmapForPlayer(_heatmapPlayer2Id!)),
                ],
              )
            else
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _buildHeatmapForPlayer(_heatmapPlayer1Id!),
                ),
              ),
          ] else
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Column(
                  children: [
                    Icon(Icons.map, size: 48, color: Theme.of(context).colorScheme.surfaceContainer),
                    const SizedBox(height: 16),
                    Text(
                      'Select a player to see their heatmap',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55), fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeatmapPlayerDropdown({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
    bool allowNone = false,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13)),
        ),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: [
              if (allowNone)
                const DropdownMenuItem(value: null, child: Text('None')),
              ..._players.map((p) => DropdownMenuItem(
                    value: p.id,
                    child: Text(p.name, overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildHeatmapForPlayer(String playerId) {
    final player = _players.where((p) => p.id == playerId).firstOrNull;
    if (player == null) return const SizedBox();

    final modeStats = player.modeStats[_heatmapMode];
    final counters = modeStats?.counters ?? {};

    final segCounters = Map<String, int>.fromEntries(
      counters.entries.where((e) => e.key.startsWith('seg_')),
    );

    return HeatmapBoard(
      counters: segCounters,
      playerName: player.name,
    );
  }

  // ──────────────────────────────────────────
  // HISTORY TAB
  // ──────────────────────────────────────────

  static const _modeLabels = {
    'x01': 'X01',
    'cricket': 'Cricket',
    'cricket_cutthroat': 'Cricket CT',
    'aroundTheClock': 'Clock',
    'killer': 'Killer',
    'halveIt': 'Halve It',
  };

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Theme.of(context).colorScheme.surfaceContainer),
            const SizedBox(height: 16),
            Text('No games recorded yet',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55), fontSize: 18)),
            const SizedBox(height: 8),
            Text('Games appear here after you exit',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _history.length,
      itemBuilder: (context, index) =>
          _buildHistoryCard(_history[index]),
    );
  }

  Widget _buildHistoryCard(GameHistoryEntry entry) {
    final label = _modeLabels[entry.gameMode] ?? entry.gameMode;
    final date = _formatDate(entry.date);
    final sorted = List<GameHistoryPlayer>.from(entry.players)
      ..sort((a, b) => a.placement.compareTo(b.placement));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding:
            const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.32)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary)),
        ),
        title: Row(
          children: sorted.take(3).map((p) {
            final medal = p.placement == 1
                ? '🥇'
                : p.placement == 2
                    ? '🥈'
                    : p.placement == 3
                        ? '🥉'
                        : '#${p.placement}';
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('$medal ${p.name}',
                  style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
        ),
        subtitle: Text(date,
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),
          ...sorted.map((p) => _buildHistoryPlayerRow(p, entry.gameMode)),
        ],
      ),
    );
  }

  Widget _buildHistoryPlayerRow(GameHistoryPlayer p, String gameMode) {
    final medal = p.placement == 1
        ? '🥇'
        : p.placement == 2
            ? '🥈'
            : p.placement == 3
                ? '🥉'
                : '#${p.placement}';

    final statChips = _buildHistoryStatChips(p.stats, gameMode);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$medal ', style: const TextStyle(fontSize: 16)),
              Text(p.name,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              _buildRatingDelta(p.ratingDelta),
            ],
          ),
          if (statChips.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: statChips),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildHistoryStatChips(
      Map<String, int> stats, String gameMode) {
    final chips = <Widget>[];

    void chip(String label, String value) {
      chips.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('$label: $value',
            style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ));
    }

    if (gameMode == 'cricket' || gameMode == 'cricket_cutthroat') {
      if (stats.containsKey('totalPoints')) chip('Pts', '${stats['totalPoints']}');
      if (stats.containsKey('closedTargets')) chip('Closed', '${stats['closedTargets']}/7');
      if (stats.containsKey('totalDarts') && stats.containsKey('marksScored')) {
        final darts = stats['totalDarts']!;
        final marks = stats['marksScored']!;
        if (darts > 0) {
          chip('Marks/dart', (marks / darts).toStringAsFixed(2));
        }
      }
    } else if (gameMode == 'x01') {
      final turns = stats['totalTurns'] ?? 0;
      final turnScore = stats['totalTurnScore'] ?? 0;
      if (turns > 0) chip('3-dart avg', (turnScore / turns).toStringAsFixed(1));
      if (stats.containsKey('totalDarts')) chip('Darts', '${stats['totalDarts']}');
      final bestCo = stats['max:bestCheckout'] ?? 0;
      if (bestCo > 0) chip('Checkout', '$bestCo');
      final to100 = stats['turnsOver100'] ?? 0;
      if (to100 > 0) chip('100+', '$to100');
    } else if (gameMode == 'aroundTheClock') {
      if (stats.containsKey('totalDarts')) chip('Darts', '${stats['totalDarts']}');
      final td = stats['totalDarts'] ?? 0;
      final th = stats['totalHits'] ?? 0;
      if (td > 0) chip('Hit rate', '${(th / td * 100).toStringAsFixed(0)}%');
      final reached = stats['reached'];
      final finished = (stats['finished'] ?? 0) == 1;
      if (reached != null && !finished) {
        chip('Reached', reached == 25 ? 'Bull' : '$reached');
      }
    } else if (gameMode == 'killer') {
      if (stats.containsKey('kills')) chip('Kills', '${stats['kills']}');
      if (stats.containsKey('attacksDealt')) chip('Damage', '${stats['attacksDealt']}');
      if (stats.containsKey('livesLeft')) chip('Lives', '${stats['livesLeft']}');
    } else if (gameMode == 'halveIt') {
      if (stats.containsKey('totalScore')) chip('Score', '${stats['totalScore']}');
      if (stats.containsKey('bestRound')) chip('Best rnd', '${stats['bestRound']}');
      if (stats.containsKey('halvings')) chip('Halvings', '${stats['halvings']}');
    }
    return chips;
  }

  /// Compute and build: current streak, favorite mode, top 3 X01 checkouts,
  /// activity (last 30 days), nemesis, favorite victim.
  List<Widget> _buildPlayerInsights(SavedPlayer p) {
    final widgets = <Widget>[];

    // Current win/loss streak — iterate history chronologically (oldest → newest)
    final playerGames = _history
        .where((e) => e.players.any((gp) => gp.savedPlayerId == p.id))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (playerGames.isNotEmpty) {
      int streak = 0;
      bool? streakIsWin;
      for (final game in playerGames.reversed) {
        final gp = game.players.firstWhere((x) => x.savedPlayerId == p.id);
        final bestPlacement =
            game.players.map((x) => x.placement).reduce((a, b) => a < b ? a : b);
        final won = gp.placement == bestPlacement;
        if (streakIsWin == null) {
          streakIsWin = won;
          streak = 1;
        } else if (streakIsWin == won) {
          streak++;
        } else {
          break;
        }
      }
      if (streak > 1) {
        widgets.add(const SizedBox(height: 4));
        widgets.add(_statRow(
          'Current streak',
          '$streak ${streakIsWin! ? 'wins' : 'losses'} ${streakIsWin ? '🔥' : '💀'}',
        ));
      }
    }

    // Favorite mode — most played
    if (p.modeStats.isNotEmpty) {
      final sorted = p.modeStats.entries.toList()
        ..sort((a, b) => b.value.played.compareTo(a.value.played));
      if (sorted.first.value.played > 0) {
        const labels = {
          'x01': 'X01',
          'cricket': 'Cricket',
          'cricket_cutthroat': 'Cricket CT',
          'aroundTheClock': 'Clock',
          'killer': 'Killer',
          'halveIt': 'Halve It',
        };
        final top = sorted.first;
        widgets.add(const SizedBox(height: 4));
        widgets.add(_statRow(
          'Favorite mode',
          '${labels[top.key] ?? top.key} (${top.value.played})',
        ));
      }
    }

    // Top 3 X01 checkouts
    final checkouts = <int>[];
    for (final game in _history.where((e) => e.gameMode == 'x01')) {
      final gp = game.players.where((x) => x.savedPlayerId == p.id).firstOrNull;
      if (gp == null) continue;
      final co = gp.stats['max:bestCheckout'] ?? 0;
      if (co > 0) checkouts.add(co);
    }
    checkouts.sort((a, b) => b.compareTo(a));
    if (checkouts.isNotEmpty) {
      final top3 = checkouts.take(3).toList();
      widgets.add(const SizedBox(height: 4));
      widgets.add(_statRow('Top checkouts (X01)', top3.join(' · ')));
    }

    // Activity last 30 days
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final recentCount = playerGames.where((g) => g.date.isAfter(cutoff)).length;
    if (recentCount > 0) {
      widgets.add(const SizedBox(height: 4));
      widgets.add(_statRow('Games last 30 days', '$recentCount'));
    }

    // Nemesis / Favorite victim
    if (p.headToHead.isNotEmpty) {
      final opponents = p.headToHead.entries
          .where((e) => e.value.total > 0)
          .toList();

      // Nemesis: most losses
      final byLosses = List.of(opponents)
        ..sort((a, b) => b.value.losses.compareTo(a.value.losses));
      if (byLosses.isNotEmpty && byLosses.first.value.losses > 0) {
        final n = byLosses.first;
        widgets.add(const SizedBox(height: 4));
        widgets.add(_statRow(
          'Nemesis 😈',
          '${_findPlayerName(n.key)} (${n.value.wins}W-${n.value.losses}L)',
        ));
      }

      // Favorite victim: most wins
      final byWins = List.of(opponents)
        ..sort((a, b) => b.value.wins.compareTo(a.value.wins));
      if (byWins.isNotEmpty && byWins.first.value.wins > 0) {
        final v = byWins.first;
        widgets.add(const SizedBox(height: 4));
        widgets.add(_statRow(
          'Favorite victim 🎯',
          '${_findPlayerName(v.key)} (${v.value.wins}W-${v.value.losses}L)',
        ));
      }
    }

    return widgets;
  }

  Widget _buildRatingDelta(double? delta) {
    if (delta == null) return const SizedBox.shrink();
    final rounded = delta.round();
    if (rounded == 0) {
      return Text(' ±0',
          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)));
    }
    final isUp = rounded > 0;
    return Text(
      ' ${isUp ? '▲' : '▼'}${rounded.abs()}',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: isUp ? Colors.green[400] : Colors.red[400],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }
}

class _StatItem {
  final String emoji;
  final String label;
  final String value;
  _StatItem(this.emoji, this.label, this.value);
}

class _RatingGraphPainter extends CustomPainter {
  final List<RatingSnapshot> snapshots;
  final Color lineColor;
  final Color textColor;

  _RatingGraphPainter({required this.snapshots, required this.lineColor, required this.textColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (snapshots.length < 2) return;

    final ratings = snapshots.map((s) => s.rating).toList();
    final minR = ratings.reduce(min);
    final maxR = ratings.reduce(max);
    final range = maxR - minR;
    final padding = range * 0.1;
    final low = minR - padding;
    final high = maxR + padding;
    final span = high - low;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = Colors.grey.withAlpha(50)
      ..strokeWidth = 0.5;

    // Draw horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      final y = size.height - (i / 4) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw rating line
    final path = Path();
    for (int i = 0; i < ratings.length; i++) {
      final x = ratings.length == 1
          ? size.width / 2
          : (i / (ratings.length - 1)) * size.width;
      final y = span == 0
          ? size.height / 2
          : size.height - ((ratings[i] - low) / span) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // Draw dots and placement annotations at each point
    final placementTextStyle = TextStyle(
        color: lineColor.withAlpha(200), fontSize: 9, fontWeight: FontWeight.bold);
    for (int i = 0; i < snapshots.length; i++) {
      final x = snapshots.length == 1
          ? size.width / 2
          : (i / (snapshots.length - 1)) * size.width;
      final y = span == 0
          ? size.height / 2
          : size.height - ((ratings[i] - low) / span) * size.height;
      canvas.drawCircle(Offset(x, y), 3, dotPaint);

      // Show placement label above the dot if available
      final placement = snapshots[i].placement;
      if (placement != null) {
        final label = '#$placement';
        final tp = TextPainter(
          text: TextSpan(text: label, style: placementTextStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        // Offset: above dot, clamp so it stays within canvas
        final labelX = (x - tp.width / 2).clamp(0.0, size.width - tp.width);
        final labelY = (y - tp.height - 5).clamp(0.0, size.height - tp.height);
        tp.paint(canvas, Offset(labelX, labelY));
      }
    }

    // Draw min/max labels
    final textStyle = TextStyle(color: textColor, fontSize: 10);
    final maxTp = TextPainter(
      text: TextSpan(text: maxR.round().toString(), style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    maxTp.paint(canvas, Offset(2, 2));

    final minTp = TextPainter(
      text: TextSpan(text: minR.round().toString(), style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    minTp.paint(canvas, Offset(2, size.height - minTp.height - 2));
  }

  @override
  bool shouldRepaint(covariant _RatingGraphPainter oldDelegate) =>
      oldDelegate.snapshots != snapshots;
}
