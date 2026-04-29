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
                Icon(Icons.adjust, size: 80, color: Theme.of(context).colorScheme.secondary),
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
                  'v1.6.1',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (_topPlayers.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildPodium(),
                ],
                const SizedBox(height: 32),
                Text(
                  'X01',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _x01Button(context, 301),
                    const SizedBox(width: 12),
                    _x01Button(context, 501),
                    const SizedBox(width: 12),
                    _x01Button(context, 701),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Other Games',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                _modeButton(context, GameMode.cricket),
                const SizedBox(height: 8),
                _modeButton(context, GameMode.aroundTheClock),
                const SizedBox(height: 8),
                _modeButton(context, GameMode.killer),
                const SizedBox(height: 8),
                _modeButton(context, GameMode.halveIt),
                const SizedBox(height: 8),
                _modeButton(context, GameMode.shanghai),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.bar_chart,
                          color: Colors.grey, size: 28),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const StatsScreen()),
                        );
                        _loadTopPlayers();
                      },
                      tooltip: 'Statistics',
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.settings,
                          color: Colors.grey, size: 28),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      ),
                      tooltip: 'Settings',
                    ),
                  ],
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
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
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
            color: Colors.grey[600],
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
    return SizedBox(
      width: 90,
      child: ElevatedButton(
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
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle:
              const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        child: Text('$score'),
      ),
    );
  }

  Widget _modeButton(BuildContext context, GameMode mode) {
    return SizedBox(
      width: 220,
      child: ElevatedButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerSetupScreen(gameMode: mode),
            ),
          );
          _loadTopPlayers();
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        child: Text(mode.label),
      ),
    );
  }
}
