import 'package:flutter/material.dart';
import '../models/game_result.dart';
import '../widgets/player_avatar.dart';

class PostGameScreen extends StatelessWidget {
  final GameResult result;

  const PostGameScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sorted = List<PlayerResult>.from(result.results)
      ..sort((a, b) => a.placement.compareTo(b.placement));
    final winner = sorted.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Over'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Winner section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  cs.tertiary.withAlpha(40),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.emoji_events, size: 48, color: cs.tertiary),
                const SizedBox(height: 8),
                PlayerAvatar(
                  avatarPath: winner.avatarPath,
                  name: winner.name,
                  radius: 36,
                ),
                const SizedBox(height: 8),
                Text(
                  winner.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('Winner!',
                    style: TextStyle(color: cs.tertiary, fontSize: 16)),
              ],
            ),
          ),

          // Stats skipped notice
          if (result.statsSkipped)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(30),
                border: Border.all(color: Colors.orange.withAlpha(80)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Statistics not recorded (player list changed mid-game)',
                      style: TextStyle(color: Colors.orange, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Rankings
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                final pr = sorted[index];
                return _PlayerResultTile(
                  result: pr,
                  gameMode: result.gameMode,
                );
              },
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop('undo'),
                    child: const Text('Undo'),
                  ),
                ),
                if (result.canContinue) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop('continue'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                      ),
                      child: const Text('Continue'),
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop('home'),
                    child: const Text('Finish Game'),
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

class _PlayerResultTile extends StatelessWidget {
  final PlayerResult result;
  final String gameMode;

  const _PlayerResultTile({required this.result, required this.gameMode});

  Color _placementColor(int p, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (p) {
      case 1:
        return cs.tertiary;
      case 2:
        return cs.onSurface.withValues(alpha: 0.7);
      case 3:
        return Colors.brown[300]!;
      default:
        return cs.onSurface.withValues(alpha: 0.4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratingChange = result.ratingChange;
    final stats = result.stats;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Placement badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _placementColor(result.placement, context).withAlpha(40),
                border: Border.all(
                  color: _placementColor(result.placement, context),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '${result.placement}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _placementColor(result.placement, context),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Avatar
            PlayerAvatar(
              avatarPath: result.avatarPath,
              name: result.name,
              radius: 20,
            ),
            const SizedBox(width: 12),
            // Name and stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildStats(stats, context),
                ],
              ),
            ),
            // Rating change
            if (ratingChange != null)
              _buildRatingDelta(context, ratingChange),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(Map<String, dynamic> stats, BuildContext context) {
    final entries = <String>[];

    switch (gameMode) {
      case 'x01':
        if (stats['highestTurn'] != null) entries.add('Best: ${stats['highestTurn']}');
        if (stats['avgTurn'] != null) entries.add('Avg: ${(stats['avgTurn'] as double).toStringAsFixed(1)}');
        if (stats['darts'] != null) entries.add('Darts: ${stats['darts']}');
        if (stats['checkout'] != null) entries.add('Out: ${stats['checkout']}');
      case 'cricket':
        if (stats['points'] != null) entries.add('Pts: ${stats['points']}');
        if (stats['closed'] != null) entries.add('Closed: ${stats['closed']}');
      case 'aroundTheClock':
        if (stats['reached'] != null) entries.add('Reached: ${stats['reached']}');
        if (stats['darts'] != null) entries.add('Darts: ${stats['darts']}');
      case 'killer':
        if (stats['lives'] != null) entries.add('Lives: ${stats['lives']}');
      case 'halveIt':
        if (stats['score'] != null) entries.add('Score: ${stats['score']}');
        if (stats['halved'] != null) entries.add('Halved: ${stats['halved']}');
    }

    if (entries.isEmpty) return const SizedBox.shrink();
    return Text(
      entries.join(' | '),
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12),
    );
  }

  Widget _buildRatingDelta(BuildContext context, double delta) {
    if (delta.abs() < 0.5) {
      return Text(
        '±0',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    final positive = delta > 0;
    final color = positive ? cs.primary : cs.error;
    final icon = positive ? Icons.arrow_upward : Icons.arrow_downward;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 2),
        Text(
          '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
