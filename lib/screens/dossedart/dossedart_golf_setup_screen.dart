import 'package:flutter/material.dart';
import '../../models/game_config.dart';
import '../../models/player.dart';
import '../../widgets/dossedart/setup/dossedart_setup_scaffold.dart';
import '../../widgets/dossedart/setup/rules_primitives.dart';
import '../golf_game_screen.dart';

class DossedartGolfSetupScreen extends StatefulWidget {
  const DossedartGolfSetupScreen(
      {super.key, this.initialConfig, this.initialPlayerIds});

  /// Rematch prefill: the previous game's rules and roster (PLAY AGAIN).
  final GolfConfig? initialConfig;
  final List<String>? initialPlayerIds;

  @override
  State<DossedartGolfSetupScreen> createState() =>
      _DossedartGolfSetupScreenState();
}

class _DossedartGolfSetupScreenState extends State<DossedartGolfSetupScreen> {
  late int _holes = widget.initialConfig?.holes ?? 18;

  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: 'GOLF',
      minPlayers: 2,
      initialSelectedIds: widget.initialPlayerIds,
      rulesSection: _buildRules,
      summaryBuilder: _summary,
      onStart: _startGame,
    );
  }

  Widget _buildRules(bool randomOrder, ValueChanged<bool> onRandomOrderChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArcadeChipRow<int>(
          label: 'COURSE',
          value: _holes,
          options: const [('9 HOLES', 9), ('18 HOLES', 18)],
          onChanged: (v) => setState(() => _holes = v),
        ),
        const SizedBox(height: 14),
        ArcadeToggleRow(toggles: [
          ('RANDOM PLAYER ORDER', randomOrder, onRandomOrderChanged),
        ]),
      ],
    );
  }

  String _summary(int playerCount) =>
      '$playerCount PLAYERS · $_holes HOLES · LOWEST WINS';

  void _startGame(List<Player> players, bool _) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GolfGameScreen(
          players: players,
          config: GolfConfig(holes: _holes),
        ),
      ),
    );
  }
}
