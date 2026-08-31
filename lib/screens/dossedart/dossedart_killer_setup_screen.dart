import 'package:flutter/material.dart';
import '../../models/game_config.dart';
import '../../models/player.dart';
import '../../widgets/dossedart/setup/dossedart_setup_scaffold.dart';
import '../../widgets/dossedart/setup/rules_primitives.dart';
import '../killer_game_screen.dart';

class DossedartKillerSetupScreen extends StatefulWidget {
  const DossedartKillerSetupScreen(
      {super.key, this.initialConfig, this.initialPlayerIds});

  /// Rematch prefill: the previous game's rules and roster (PLAY AGAIN).
  final KillerConfig? initialConfig;
  final List<String>? initialPlayerIds;

  @override
  State<DossedartKillerSetupScreen> createState() =>
      _DossedartKillerSetupScreenState();
}

class _DossedartKillerSetupScreenState
    extends State<DossedartKillerSetupScreen> {
  late int _lives = widget.initialConfig?.lives ?? 3;
  late bool _throwToPick = widget.initialConfig?.throwToPick ?? true;
  late bool _multiplyHits = widget.initialConfig?.multiplyHits ?? false;
  late bool _shields = widget.initialConfig?.shields ?? false;
  late bool _suicide = widget.initialConfig?.suicide ?? false;

  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: 'KILLER',
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
          ('RANDOM PLAYER ORDER', randomOrder, onRandomOrderChanged),
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
          useDossedartDesign: true,
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
