import 'package:flutter/material.dart';
import '../../models/game_config.dart';
import '../../models/player.dart';
import '../../widgets/dossedart/setup/dossedart_setup_scaffold.dart';
import '../../widgets/dossedart/setup/rules_primitives.dart';
import '../shanghai_game_screen.dart';

class DossedartShanghaiSetupScreen extends StatefulWidget {
  const DossedartShanghaiSetupScreen({super.key});

  @override
  State<DossedartShanghaiSetupScreen> createState() =>
      _DossedartShanghaiSetupScreenState();
}

class _DossedartShanghaiSetupScreenState
    extends State<DossedartShanghaiSetupScreen> {
  int _targetEnd = 7;

  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: 'SHANGHAI',
      minPlayers: 1,
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
          label: 'TARGET RANGE',
          value: _targetEnd,
          options: const [('1-7', 7), ('1-9', 9), ('1-20', 20)],
          onChanged: (v) => setState(() => _targetEnd = v),
        ),
        const SizedBox(height: 14),
        ArcadeToggleRow(toggles: [
          ('RANDOM ORDER', randomOrder, onRandomOrderChanged),
        ]),
      ],
    );
  }

  String _summary(int playerCount) {
    return [
      '$playerCount PLAYERS',
      '1 → $_targetEnd',
    ].join(' · ');
  }

  void _startGame(List<Player> players, bool _) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ShanghaiGameScreen(
          players: players,
          config: ShanghaiConfig(targetEnd: _targetEnd),
        ),
      ),
    );
  }
}
