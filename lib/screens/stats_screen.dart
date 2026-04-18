import 'dart:math';
import 'package:flutter/material.dart';
import '../models/saved_player.dart';
import '../services/player_storage.dart';
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
    _tabController = TabController(length: 2 + _modes.length, vsync: this);
    _loadPlayers();
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
              backgroundColor: const Color(0xFFE53935),
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
                          color: Colors.grey[400],
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
            Icon(Icons.sports_esports, size: 48, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'No $modeLabel games played yet',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
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
                          ? Colors.amber
                          : rank == 1
                              ? Colors.grey[400]
                              : rank == 2
                                  ? Colors.brown[300]
                                  : Colors.grey[600],
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
                          color: Colors.grey[400],
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
                            : Colors.grey[400],
                      ),
                    ),
                    Text(
                      'win rate',
                      style: TextStyle(
                        color: Colors.grey[600],
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
        color: Colors.grey[900],
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
                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
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
              style: TextStyle(color: Colors.grey[400], fontSize: 14)),
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
                    Icon(Icons.map, size: 48, color: Colors.grey[700]),
                    const SizedBox(height: 16),
                    Text(
                      'Select a player to see their heatmap',
                      style: TextStyle(color: Colors.grey[500], fontSize: 16),
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
          child: Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
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

  _RatingGraphPainter({required this.snapshots, required this.lineColor});

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
    final textStyle = TextStyle(color: Colors.grey[500], fontSize: 10);
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
