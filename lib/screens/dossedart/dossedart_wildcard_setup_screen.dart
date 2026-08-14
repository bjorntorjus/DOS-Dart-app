import 'package:flutter/material.dart';
import '../../models/game_config.dart';
import '../../models/player.dart';
import '../../widgets/dossedart/setup/dossedart_setup_scaffold.dart';
import '../../widgets/dossedart/setup/rules_primitives.dart';
import '../wildcard_game_screen.dart';

class DossedartWildcardSetupScreen extends StatefulWidget {
  const DossedartWildcardSetupScreen(
      {super.key, this.initialConfig, this.initialPlayerIds});

  /// Rematch prefill: the previous game's rules and roster (PLAY AGAIN).
  final WildcardConfig? initialConfig;
  final List<String>? initialPlayerIds;

  @override
  State<DossedartWildcardSetupScreen> createState() =>
      _DossedartWildcardSetupScreenState();
}

class _DossedartWildcardSetupScreenState
    extends State<DossedartWildcardSetupScreen> {
  late int _rounds = widget.initialConfig?.rounds ?? 10;
  late int _chaos = widget.initialConfig?.startingChaos ?? 5;

  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: 'WILDCARD',
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
          label: 'ROUNDS',
          value: _rounds,
          options: const [('5', 5), ('10', 10), ('15', 15)],
          onChanged: (v) => setState(() => _rounds = v),
        ),
        const SizedBox(height: 14),
        ArcadeChipRow<int>(
          label: 'STARTING CHAOS',
          value: _chaos,
          options: const [('MILD', 2), ('SPICY', 5), ('TOTAL CHAOS', 8)],
          onChanged: (v) => setState(() => _chaos = v),
        ),
        const SizedBox(height: 14),
        ArcadeToggleRow(toggles: [
          ('RANDOM PLAYER ORDER', randomOrder, onRandomOrderChanged),
        ]),
      ],
    );
  }

  String _summary(int playerCount) =>
      '$playerCount PLAYERS · $_rounds ROUNDS · CHAOS $_chaos';

  void _startGame(List<Player> players, bool _) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WildcardGameScreen(
          players: players,
          config: WildcardConfig(rounds: _rounds, startingChaos: _chaos),
        ),
      ),
    );
  }
}
