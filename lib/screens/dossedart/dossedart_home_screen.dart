import 'package:flutter/material.dart';
import '../../models/game_mode.dart';
import '../../models/saved_player.dart';
import '../../services/player_storage.dart';
import '../../theme/dossedart_tokens.dart';
import '../../widgets/dossedart/arcade_frame.dart';
import '../settings_screen.dart';
import '../stats_screen.dart';
import 'dossedart_atc_setup_screen.dart';
import 'dossedart_cricket_setup_screen.dart';
import 'dossedart_killer_setup_screen.dart';
import 'dossedart_shanghai_setup_screen.dart';
import 'dossedart_splitscore_setup_screen.dart';
import 'dossedart_x01_setup_screen.dart';

/// DOSSEDART arcade home screen — leaderboard variant B (tight list).
class DossedartHomeScreen extends StatefulWidget {
  const DossedartHomeScreen({super.key});

  @override
  State<DossedartHomeScreen> createState() => _DossedartHomeScreenState();
}

class _DossedartHomeScreenState extends State<DossedartHomeScreen> {
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

  TextStyle _press(double size, {Color? color, double letterSpacing = 1}) {
    return TextStyle(
      fontFamily: 'PressStart2P',
      fontSize: size,
      color: color ?? Colors.white,
      letterSpacing: letterSpacing,
      height: 1.3,
    );
  }

  TextStyle _vt(double size, {Color? color, double letterSpacing = 1}) {
    return TextStyle(
      fontFamily: 'VT323',
      fontSize: size,
      color: color ?? Colors.white,
      letterSpacing: letterSpacing,
      height: 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DossedartTokens.bg,
      body: ArcadeFrame(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildLeaderboard(),
                      _buildX01Block(),
                      _buildModesBlock(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              _buildCabinetFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      decoration: const Border(
        bottom: BorderSide(color: DossedartTokens.magenta, width: 2),
      ).toBoxDecoration(Colors.black),
      child: Column(
        children: [
          Text(
            '★ ★ ★  INSERT COIN  ★ ★ ★',
            style: _vt(16, color: DossedartTokens.cyan, letterSpacing: 4),
          ),
          const SizedBox(height: 12),
          Text(
            'DOSSE\nDART',
            textAlign: TextAlign.center,
            style: _press(30, color: DossedartTokens.yellow, letterSpacing: 1).copyWith(
              shadows: const [
                Shadow(color: DossedartTokens.yellow, blurRadius: 10),
                Shadow(color: DossedartTokens.magenta, offset: Offset(3, 3)),
              ],
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '©2026 DOSSE GAMES INC.',
            style: _vt(16, color: Colors.white, letterSpacing: 2),
          ),
          Text(
            'v1.8.0',
            style: _vt(13, color: Colors.white38, letterSpacing: 2),
          ),
        ],
      ),
    );
  }

  // ─── Leaderboard B (tight list) ────────────────────────────────────────────
  Widget _buildLeaderboard() {
    if (_topPlayers.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0x66FF00AA), width: 1),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('━━━━',
                  style: _vt(16, color: DossedartTokens.magenta)),
              const SizedBox(width: 12),
              Text('★ HIGH SCORES ★',
                  style: _press(11,
                      color: DossedartTokens.cyan, letterSpacing: 1.5)),
              const SizedBox(width: 12),
              Text('━━━━',
                  style: _vt(16, color: DossedartTokens.magenta)),
            ],
          ),
          const SizedBox(height: 12),
          // Column header
          Container(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0x4DFF00AA), width: 1),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Center(
                    child: Text('#',
                        style: _vt(12,
                            color: Colors.white60, letterSpacing: 2)),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text('HANDLE',
                      style: _vt(12, color: Colors.white60, letterSpacing: 1.5)),
                ),
                Expanded(
                  child: Text('PLAYER',
                      style: _vt(12, color: Colors.white60, letterSpacing: 2)),
                ),
                SizedBox(
                  width: 58,
                  child: Text('RATING',
                      textAlign: TextAlign.right,
                      style: _vt(12, color: Colors.white60, letterSpacing: 1.5)),
                ),
                SizedBox(
                  width: 44,
                  child: Text('WIN%',
                      textAlign: TextAlign.right,
                      style: _vt(12, color: Colors.white60, letterSpacing: 1.5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < _topPlayers.length; i++)
            _leaderboardRow(_topPlayers[i], i),
          const SizedBox(height: 6),
          Center(
            child: Text(
              '▼ MORE ▼',
              style: _vt(15, color: Colors.white54, letterSpacing: 2),
            ),
          ),
        ],
      ),
    );
  }

  String _handleFor(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (cleaned.length >= 3) return cleaned.substring(0, 3);
    return cleaned.padRight(3, 'X');
  }

  Widget _leaderboardRow(SavedPlayer player, int index) {
    final hero = index == 0;
    final accents = const [
      DossedartTokens.yellow,
      DossedartTokens.cyan,
      DossedartTokens.magenta
    ];
    final medals = const ['🥇', '🥈', '🥉'];
    final accent = accents[index];

    final winPct = player.gamesPlayed > 0
        ? '${(player.winRate * 100).round()}%'
        : '—';

    return Container(
      margin: EdgeInsets.only(bottom: hero ? 8 : 0),
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: hero ? 14 : 10,
      ),
      decoration: BoxDecoration(
        color: hero ? const Color(0x14FFD200) : Colors.transparent,
        border: Border.all(
          color: hero ? DossedartTokens.yellow : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Center(
              child: Text(medals[index],
                  style: TextStyle(fontSize: hero ? 24 : 18)),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              _handleFor(player.name),
              style: _press(hero ? 14 : 11,
                  color: accent, letterSpacing: 1),
            ),
          ),
          Expanded(
            child: Text(
              player.name.toUpperCase(),
              style: _vt(hero ? 22 : 18,
                  color: Colors.white, letterSpacing: 1),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 58,
            child: Text(
              player.rating.toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: _press(hero ? 14 : 11,
                  color: accent, letterSpacing: 0.5),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              winPct,
              textAlign: TextAlign.right,
              style: _vt(hero ? 18 : 16,
                  color: Colors.white60, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  // ─── X01 Block ─────────────────────────────────────────────────────────────
  Widget _buildX01Block() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '► PLAYER 1 SELECT',
            style: _press(11, color: DossedartTokens.cyan, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _x01Card(301, '🥉', 'SHORT', false)),
              const SizedBox(width: 8),
              Expanded(child: _x01Card(501, '🍻', 'CLASSIC', true)),
              const SizedBox(width: 8),
              Expanded(child: _x01Card(701, '🏆', 'LONG', false)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _x01Card(int score, String emoji, String tag, bool hero) {
    final accent =
        hero ? DossedartTokens.yellow : DossedartTokens.magenta;
    return InkWell(
      onTap: () => _startGame(GameMode.x01, startingScore: score),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: DossedartTokens.surface,
          border: Border.all(color: accent, width: 3),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text('$score',
                style: _press(22, color: accent, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(tag,
                style: _vt(15,
                    color: Colors.white70, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  // ─── Modes Block ───────────────────────────────────────────────────────────
  Widget _buildModesBlock() {
    final modes = const [
      (GameMode.cricket, 'Cricket', '🎯'),
      (GameMode.aroundTheClock, 'Around the Clock', '🕐'),
      (GameMode.killer, 'Killer', '🔪'),
      (GameMode.halveIt, 'Halve It', '✂️'),
      (GameMode.shanghai, 'Shanghai', '🐉'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('► OR PICK A LEVEL',
              style: _press(11, color: DossedartTokens.cyan, letterSpacing: 1)),
          const SizedBox(height: 12),
          for (var i = 0; i < modes.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: _modeCell(modes[i].$1, modes[i].$2, modes[i].$3)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: i + 1 < modes.length
                        ? _modeCell(modes[i + 1].$1, modes[i + 1].$2,
                            modes[i + 1].$3)
                        : _comingSoonCell(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _modeCell(GameMode mode, String label, String emoji) {
    return InkWell(
      onTap: () => _startGame(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: DossedartTokens.surface,
          border: Border.all(color: DossedartTokens.cyan, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              label.toUpperCase(),
              style: _press(10, color: Colors.white, letterSpacing: 1),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _comingSoonCell() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(
            color: DossedartTokens.magenta.withValues(alpha: 0.4), width: 2),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✨', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text('?? COMING ??',
              style: _vt(15, color: Colors.white54, letterSpacing: 2)),
        ],
      ),
    );
  }

  // ─── Cabinet Footer ────────────────────────────────────────────────────────
  Widget _buildCabinetFooter() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: DossedartTokens.yellow, width: 2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _cabinetButton(
              label: 'STATS',
              sub: 'P-1',
              icon: Icons.bar_chart,
              color: DossedartTokens.cyan,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StatsScreen()),
                );
                _loadTopPlayers();
              },
            ),
          ),
          Expanded(
            child: _cabinetButton(
              label: 'HISTORY',
              sub: 'LOG',
              icon: Icons.history,
              color: DossedartTokens.yellow,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('History screen not yet wired')),
                );
              },
            ),
          ),
          Expanded(
            child: _cabinetButton(
              label: 'SETTINGS',
              sub: 'CFG',
              icon: Icons.settings,
              color: DossedartTokens.magenta,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cabinetButton({
    required String label,
    required String sub,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
            decoration: BoxDecoration(
              color: DossedartTokens.bg,
              border: Border(
                top: BorderSide(color: color, width: 3),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(height: 6),
                Text(label, style: _press(11, color: color, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(sub,
                    style: _vt(13, color: Colors.white54, letterSpacing: 2)),
              ],
            ),
          ),
          Positioned(
            top: -4,
            child: Container(
              width: 18,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Navigation ────────────────────────────────────────────────────────────
  Future<void> _startGame(GameMode mode, {int? startingScore}) async {
    Widget screen;
    switch (mode) {
      case GameMode.x01:
        screen = DossedartX01SetupScreen(startingScore: startingScore!);
      case GameMode.cricket:
        screen = const DossedartCricketSetupScreen();
      case GameMode.killer:
        screen = const DossedartKillerSetupScreen();
      case GameMode.aroundTheClock:
        screen = const DossedartAtcSetupScreen();
      case GameMode.halveIt:
        screen = const DossedartSplitscoreSetupScreen();
      case GameMode.shanghai:
        screen = const DossedartShanghaiSetupScreen();
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _loadTopPlayers();
  }
}

extension _BoxDecorationFromBorder on Border {
  BoxDecoration toBoxDecoration(Color color) =>
      BoxDecoration(color: color, border: this);
}
