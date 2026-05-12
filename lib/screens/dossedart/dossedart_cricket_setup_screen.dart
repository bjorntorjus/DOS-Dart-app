import 'package:flutter/material.dart';
import '../../models/game_config.dart';
import '../../models/player.dart';
import '../../theme/dossedart_tokens.dart';
import '../../widgets/dossedart/setup/dossedart_setup_scaffold.dart';
import '../../widgets/dossedart/setup/rules_primitives.dart';
import '../cricket_game_screen.dart';

class DossedartCricketSetupScreen extends StatefulWidget {
  const DossedartCricketSetupScreen({super.key});

  @override
  State<DossedartCricketSetupScreen> createState() =>
      _DossedartCricketSetupScreenState();
}

class _DossedartCricketSetupScreenState
    extends State<DossedartCricketSetupScreen> {
  bool _isCutthroat = false;
  bool _isRandom = false;
  int _targetCount = 7;
  bool _includeBull = true;

  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: 'CRICKET',
      minPlayers: 2,
      rulesSection: _buildRules(),
      summaryBuilder: _summary,
      onStart: _startGame,
    );
  }

  Widget _buildRules() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArcadeChipRow<bool>(
          label: 'MODE',
          value: _isCutthroat,
          options: const [('STANDARD', false), ('CUTTHROAT', true)],
          onChanged: (v) => setState(() => _isCutthroat = v),
        ),
        const SizedBox(height: 14),
        ArcadeChipRow<bool>(
          label: 'TARGETS',
          value: _isRandom,
          options: const [('15-20', false), ('RANDOM', true)],
          onChanged: (v) => setState(() => _isRandom = v),
        ),
        if (_isRandom) ...[
          const SizedBox(height: 14),
          ArcadeStepper(
            label: 'COUNT',
            value: _targetCount,
            min: 3,
            max: 15,
            onChanged: (v) => setState(() => _targetCount = v),
          ),
        ],
        const SizedBox(height: 14),
        ArcadeToggleRow(toggles: [
          ('BULL', _includeBull, DossedartTokens.magenta,
              (v) => setState(() => _includeBull = v)),
        ]),
      ],
    );
  }

  String _summary(int playerCount) {
    return [
      '$playerCount PLAYERS',
      if (_isCutthroat) 'CUTTHROAT' else 'STANDARD',
      if (_isRandom) 'RANDOM TARGETS' else '15-20',
      if (_includeBull) 'BULL',
    ].join(' · ');
  }

  void _startGame(List<Player> players, bool _) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CricketGameScreen(
          players: players,
          config: CricketConfig(
            isRandom: _isRandom,
            targetCount: _targetCount,
            includeBull: _includeBull,
            isCutthroat: _isCutthroat,
          ),
        ),
      ),
    );
  }
}
