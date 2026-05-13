import 'package:flutter/material.dart';
import '../../models/game_config.dart';
import '../../models/player.dart';
import '../../widgets/dossedart/setup/dossedart_setup_scaffold.dart';
import '../../widgets/dossedart/setup/rules_primitives.dart';
import '../around_the_clock_game_screen.dart';

class DossedartAtcSetupScreen extends StatefulWidget {
  const DossedartAtcSetupScreen({super.key});

  @override
  State<DossedartAtcSetupScreen> createState() =>
      _DossedartAtcSetupScreenState();
}

class _DossedartAtcSetupScreenState extends State<DossedartAtcSetupScreen> {
  bool _includeBull = false;
  bool _countMultiples = true;
  bool _reverse = false;

  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: 'AROUND THE CLOCK',
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
          label: 'DIRECTION',
          value: _reverse,
          options: const [('1 → 20', false), ('20 → 1', true)],
          onChanged: (v) => setState(() => _reverse = v),
        ),
        const SizedBox(height: 14),
        ArcadeToggleRow(toggles: [
          ('BULL', _includeBull, (v) => setState(() => _includeBull = v)),
          ('D/T = ×N', _countMultiples, (v) => setState(() => _countMultiples = v)),
          ('RANDOM ORDER', randomOrder, onRandomOrderChanged),
        ]),
      ],
    );
  }

  String _summary(int playerCount) {
    return [
      '$playerCount PLAYERS',
      if (_reverse) '20→1' else '1→20',
      if (_includeBull) 'BULL',
      if (_countMultiples) 'D/T=×N',
    ].join(' · ');
  }

  void _startGame(List<Player> players, bool _) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AroundTheClockGameScreen(
          players: players,
          config: AroundTheClockConfig(
            includeBull: _includeBull,
            countMultiples: _countMultiples,
            reverse: _reverse,
          ),
        ),
      ),
    );
  }
}
