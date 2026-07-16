import 'package:flutter/material.dart';
import '../../models/game_config.dart';
import '../../models/one_up_engine.dart';
import '../../models/player.dart';
import '../../widgets/dossedart/setup/dossedart_setup_scaffold.dart';
import '../../widgets/dossedart/setup/rules_primitives.dart';
import '../one_up_game_screen.dart';

class DossedartOneUpSetupScreen extends StatefulWidget {
  const DossedartOneUpSetupScreen({super.key});

  @override
  State<DossedartOneUpSetupScreen> createState() =>
      _DossedartOneUpSetupScreenState();
}

class _DossedartOneUpSetupScreenState extends State<DossedartOneUpSetupScreen> {
  int _lives = 3;
  OneUpVariant _variant = OneUpVariant.beatTheLast;
  bool _shuffleEachRound = false;

  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: '1UP',
      minPlayers: 2,
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
          label: 'LIVES',
          value: _lives,
          options: const [('1', 1), ('3', 3), ('5', 5)],
          onChanged: (v) => setState(() => _lives = v),
        ),
        const SizedBox(height: 14),
        ArcadeChipRow<OneUpVariant>(
          label: 'VARIANT',
          value: _variant,
          options: const [
            ('BEAT THE LAST', OneUpVariant.beatTheLast),
            ('SURVIVOR', OneUpVariant.survivor),
          ],
          onChanged: (v) => setState(() => _variant = v),
        ),
        const SizedBox(height: 14),
        ArcadeToggleRow(toggles: [
          ('RANDOM PLAYER ORDER', randomOrder, onRandomOrderChanged),
          ('SHUFFLE EVERY ROUND', _shuffleEachRound,
              (v) => setState(() => _shuffleEachRound = v)),
        ]),
      ],
    );
  }

  String _summary(int playerCount) => [
        '$playerCount PLAYERS',
        '$_lives ${_lives == 1 ? 'LIFE' : 'LIVES'}',
        _variant == OneUpVariant.survivor ? 'SURVIVOR' : 'BEAT THE LAST',
        if (_shuffleEachRound) 'SHUFFLE',
      ].join(' · ');

  void _startGame(List<Player> players, bool _) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OneUpGameScreen(
          players: players,
          config: OneUpConfig(
            lives: _lives,
            variant: _variant,
            randomOrder: _shuffleEachRound,
          ),
        ),
      ),
    );
  }
}
