import 'package:flutter/material.dart';
import '../models/game_mode.dart';
import '../models/saved_player.dart';
import '../services/player_storage.dart';
import '../widgets/player_avatar.dart';
import 'player_setup_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SavedPlayer> _topPlayers = [];

  @override
  void initState() {
    super.initState();
    _loadTopPlayers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTopPlayers();
  }

  Future<void> _loadTopPlayers() async {
    final players = await PlayerStorage.loadPlayers();
    players.sort((a, b) => b.rating.compareTo(a.rating));
    setState(() {
      _topPlayers = players.take(3).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.adjust, size: 80, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Dart Scorer',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'v1.8.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                if (_topPlayers.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildPodium(),
                ],
                const SizedBox(height: 32),
                Text(
                  'X01',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: 0.55),
                        letterSpacing: 1.5,
                      ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(child: _x01Button(context, 301)),
                      const SizedBox(width: 8),
                      Expanded(child: _x01Button(context, 501)),
                      const SizedBox(width: 8),
                      Expanded(child: _x01Button(context, 701)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'GAME MODES',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: 0.55),
                        letterSpacing: 1.5,
                      ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _modeGrid(context),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const StatsScreen()),
                            );
                            _loadTopPlayers();
                          },
                          icon: const Icon(Icons.bar_chart, size: 20),
                          label: const Text('Stats'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SettingsScreen()),
                          ),
                          icon: const Icon(Icons.settings, size: 20),
                          label: const Text('Settings'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPodium() {
    const goldColor = Color(0xFFFFD700);
    const silverColor = Color(0xFFC0C0C0);
    const bronzeColor = Color(0xFFCD7F32);

    // Podium order: 2nd | 1st | 3rd
    final positions = <int>[]; // player indices in podium display order
    if (_topPlayers.length >= 2) positions.add(1); // 2nd place on left
    positions.add(0); // 1st always present
    if (_topPlayers.length >= 3) positions.add(2); // 3rd place on right

    Color colorForPlacement(int placement) {
      switch (placement) {
        case 1: return goldColor;
        case 2: return silverColor;
        default: return bronzeColor;
      }
    }

    double heightForPlacement(int placement) {
      switch (placement) {
        case 1: return 90;
        case 2: return 70;
        default: return 60;
      }
    }

    Widget podiumColumn(int playerIndex) {
      final player = _topPlayers[playerIndex];
      final placement = playerIndex + 1;
      final color = colorForPlacement(placement);
      final barHeight = heightForPlacement(placement);

      return SizedBox(
        width: 90,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            PlayerAvatar(
              avatarPath: player.avatarPath,
              name: player.name,
              radius: placement == 1 ? 26 : 22,
              backgroundColor: color,
            ),
            const SizedBox(height: 4),
            Text(
              player.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              player.rating.toStringAsFixed(0),
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 4),
            Container(
              height: barHeight,
              decoration: BoxDecoration(
                color: color.withAlpha(40),
                border: Border.all(color: color.withAlpha(120), width: 1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '$placement',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Text(
          'Leaderboard',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: positions
              .map((i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: podiumColumn(i),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _x01Button(BuildContext context, int score) {
    return OutlinedButton(
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerSetupScreen(
              gameMode: GameMode.x01,
              startingScore: score,
            ),
          ),
        );
        _loadTopPlayers();
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎯', style: TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            '$score',
            style:
                const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _modeGrid(BuildContext context) {
    final modes = const [
      (GameMode.cricket, '🎯'),
      (GameMode.aroundTheClock, '🕐'),
      (GameMode.killer, '💀'),
      (GameMode.halveIt, '➗'),
      (GameMode.shanghai, '🌃'),
    ];
    final cells = <Widget>[
      for (final (mode, emoji) in modes) _modeButton(context, mode, emoji),
      _comingSoonCell(context),
    ];
    return Column(
      children: [
        for (var i = 0; i < cells.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: i < cells.length - 2 ? 8 : 0),
            child: Row(
              children: [
                Expanded(child: cells[i]),
                const SizedBox(width: 8),
                Expanded(
                  child:
                      i + 1 < cells.length ? cells[i + 1] : const SizedBox(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _modeButton(BuildContext context, GameMode mode, String emoji) {
    return OutlinedButton(
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerSetupScreen(gameMode: mode),
          ),
        );
        _loadTopPlayers();
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 6),
          Text(
            mode.label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _comingSoonCell(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('✨',
              style: TextStyle(
                  fontSize: 26,
                  color: Theme.of(context).colorScheme.secondary)),
          const SizedBox(height: 6),
          Text(
            'Coming soon',
            style: TextStyle(
              fontSize: 13,
              letterSpacing: 1,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
