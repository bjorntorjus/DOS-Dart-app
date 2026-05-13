import 'package:flutter/material.dart';
import '../../models/game_config.dart';
import '../../models/player.dart';
import '../../widgets/dossedart/setup/dossedart_setup_scaffold.dart';
import '../../widgets/dossedart/setup/rules_primitives.dart';
import '../halve_it_game_screen.dart';

class DossedartSplitscoreSetupScreen extends StatefulWidget {
  const DossedartSplitscoreSetupScreen({super.key});

  @override
  State<DossedartSplitscoreSetupScreen> createState() =>
      _DossedartSplitscoreSetupScreenState();
}

class _DossedartSplitscoreSetupScreenState
    extends State<DossedartSplitscoreSetupScreen> {
  bool _isRandom = false;
  int _roundCount = 9;
  bool _includeDouble = true;
  bool _includeTriple = true;
  bool _includeBull = false;

  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: 'SPLITSCORE',
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
        ArcadeChipRow<bool>(
          label: 'ROUNDS',
          value: _isRandom,
          options: const [('STANDARD', false), ('RANDOM', true)],
          onChanged: (v) => setState(() => _isRandom = v),
        ),
        if (_isRandom) ...[
          const SizedBox(height: 14),
          ArcadeStepper(
            label: 'COUNT',
            value: _roundCount,
            min: 5,
            max: 20,
            onChanged: (v) => setState(() => _roundCount = v),
          ),
          const SizedBox(height: 14),
          ArcadeToggleRow(toggles: [
            ('DBL', _includeDouble, (v) => setState(() => _includeDouble = v)),
            ('TPL', _includeTriple, (v) => setState(() => _includeTriple = v)),
            ('BULL', _includeBull, (v) => setState(() => _includeBull = v)),
          ]),
          const SizedBox(height: 14),
          ArcadeToggleRow(toggles: [
            ('RANDOM ORDER', randomOrder, onRandomOrderChanged),
          ]),
        ] else ...[
          const SizedBox(height: 14),
          ArcadeToggleRow(toggles: [
            ('BULL', _includeBull, (v) => setState(() => _includeBull = v)),
            ('RANDOM ORDER', randomOrder, onRandomOrderChanged),
          ]),
        ],
      ],
    );
  }

  String _summary(int playerCount) {
    return [
      '$playerCount PLAYERS',
      if (_isRandom) 'RANDOM · $_roundCount RND' else 'STANDARD',
      if (_includeBull) 'BULL',
    ].join(' · ');
  }

  void _startGame(List<Player> players, bool _) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HalveItGameScreen(
          players: players,
          config: HalveItConfig(
            isRandom: _isRandom,
            roundCount: _roundCount,
            includeDouble: _includeDouble,
            includeTriple: _includeTriple,
            includeBull: _includeBull,
          ),
        ),
      ),
    );
  }
}
