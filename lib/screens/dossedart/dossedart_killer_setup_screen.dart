import 'package:flutter/material.dart';
import '../../models/game_config.dart';
import '../../models/player.dart';
import '../../widgets/dossedart/setup/dossedart_setup_scaffold.dart';
import '../../widgets/dossedart/setup/rules_primitives.dart';
import '../killer_game_screen.dart';

class DossedartKillerSetupScreen extends StatefulWidget {
  const DossedartKillerSetupScreen({super.key});

  @override
  State<DossedartKillerSetupScreen> createState() =>
      _DossedartKillerSetupScreenState();
}

class _DossedartKillerSetupScreenState
    extends State<DossedartKillerSetupScreen> {
  int _lives = 3;
  bool _throwToPick = true;
  bool _multiplyHits = false;
  bool _shields = false;
  bool _suicide = false;

  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: 'KILLER',
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
          options: const [('1', 1), ('2', 2), ('3', 3), ('4', 4), ('5', 5)],
          onChanged: (v) => setState(() => _lives = v),
        ),
        const SizedBox(height: 14),
        ArcadeChipRow<bool>(
          label: 'PICK NUMBER',
          value: _throwToPick,
          options: const [('THROW', true), ('RANDOM', false)],
          onChanged: (v) => setState(() => _throwToPick = v),
        ),
        const SizedBox(height: 14),
        ArcadeToggleRow(toggles: [
          ('×HITS', _multiplyHits, (v) => setState(() => _multiplyHits = v)),
          ('SHIELD', _shields, (v) => setState(() => _shields = v)),
          ('SUICIDE', _suicide, (v) => setState(() => _suicide = v)),
        ]),
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
      '$_lives LIVES',
      if (_throwToPick) 'THROW-PICK' else 'RANDOM PICK',
      if (_multiplyHits) '×HITS',
      if (_shields) 'SHIELDS',
      if (_suicide) 'SUICIDE',
    ].join(' · ');
  }

  void _startGame(List<Player> players, bool _) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => KillerGameScreen(
          players: players,
          config: KillerConfig(
            throwToPick: _throwToPick,
            lives: _lives,
            multiplyHits: _multiplyHits,
            shields: _shields,
            suicide: _suicide,
          ),
        ),
      ),
    );
  }
}
