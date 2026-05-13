import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../widgets/dossedart/setup/dossedart_setup_scaffold.dart';
import '../../widgets/dossedart/setup/rules_primitives.dart';
import '../game_screen.dart';

/// DOSSEDART X01 setup — picks players + X01 rules.
/// Start score is chosen on the home screen and passed in.
class DossedartX01SetupScreen extends StatefulWidget {
  const DossedartX01SetupScreen({super.key, required this.startingScore});

  final int startingScore;

  @override
  State<DossedartX01SetupScreen> createState() =>
      _DossedartX01SetupScreenState();
}

class _DossedartX01SetupScreenState extends State<DossedartX01SetupScreen> {
  String _outRule = 'none'; // 'none' (free) | 'double' | 'master'
  bool _noBust = false;
  bool _handicap = false;

  @override
  Widget build(BuildContext context) {
    return DossedartSetupScaffold(
      title: 'NEW MATCH · ${widget.startingScore}',
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
        ArcadeChipRow<String>(
          label: 'OUT RULE',
          value: _outRule,
          options: const [
            ('FREE OUT', 'none'),
            ('DOUBLE OUT', 'double'),
            ('MASTER OUT', 'master'),
          ],
          onChanged: (v) => setState(() => _outRule = v),
        ),
        const SizedBox(height: 14),
        ArcadeToggleRow(toggles: [
          ('NO-BUST', _noBust, (v) => setState(() => _noBust = v)),
          ('HANDICAP', _handicap, (v) => setState(() => _handicap = v)),
          ('RANDOM ORDER', randomOrder, onRandomOrderChanged),
        ]),
      ],
    );
  }

  String _summary(int playerCount) {
    final outLabel = switch (_outRule) {
      'double' => 'DOUBLE OUT',
      'master' => 'MASTER OUT',
      _ => 'FREE OUT',
    };
    return [
      '$playerCount PLAYERS',
      outLabel,
      if (_noBust) 'NO-BUST',
      if (_handicap) 'HANDICAP',
    ].join(' · ');
  }

  void _startGame(List<Player> players, bool randomize) {
    // X01 starting score override (and would be where handicap applies).
    final withScore = players
        .map((p) => Player(
              name: p.name,
              score: widget.startingScore,
              savedPlayerId: p.savedPlayerId,
              avatarPath: p.avatarPath,
            ))
        .toList();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          players: withScore,
          masterOut: _outRule,
          startingScore: widget.startingScore,
          handicap: _handicap,
          noBust: _noBust,
        ),
      ),
    );
  }
}
