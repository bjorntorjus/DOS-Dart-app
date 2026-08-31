import 'package:flutter/material.dart';
import '../../models/game_config.dart';
import '../../models/player.dart';
import '../../widgets/dossedart/setup/dossedart_setup_scaffold.dart';
import '../../widgets/dossedart/setup/rules_primitives.dart';
import '../gotcha_game_screen.dart';

class DossedartGotchaSetupScreen extends StatefulWidget {
  const DossedartGotchaSetupScreen(
      {super.key, this.initialConfig, this.initialPlayerIds});

  /// Rematch prefill: the previous game's rules and roster (PLAY AGAIN).
  final GotchaConfig? initialConfig;
  final List<String>? initialPlayerIds;

  @override
  State<DossedartGotchaSetupScreen> createState() =>
      _DossedartGotchaSetupScreenState();
}

class _DossedartGotchaSetupScreenState
    extends State<DossedartGotchaSetupScreen> {
  late int _targetScore = widget.initialConfig?.targetScore ?? 301;
  late bool _hardcore = widget.initialConfig?.hardcore ?? false;

  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: 'GOTCHA',
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
          label: 'TARGET SCORE',
          value: _targetScore,
          options: const [('101', 101), ('201', 201), ('301', 301), ('501', 501)],
          onChanged: (v) => setState(() => _targetScore = v),
        ),
        const SizedBox(height: 14),
        ArcadeToggleRow(toggles: [
          ('RANDOM PLAYER ORDER', randomOrder, onRandomOrderChanged),
          ('HARDCORE · KILL TO 0', _hardcore, (v) => setState(() => _hardcore = v)),
        ]),
      ],
    );
  }

  String _summary(int playerCount) => [
        '$playerCount PLAYERS',
        'RACE TO $_targetScore',
        if (_hardcore) 'HARDCORE',
      ].join(' · ');

  void _startGame(List<Player> players, bool _) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GotchaGameScreen(
          players: players,
          config: GotchaConfig(targetScore: _targetScore, hardcore: _hardcore),
        ),
      ),
    );
  }
}
