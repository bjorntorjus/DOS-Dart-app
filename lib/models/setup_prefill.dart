import 'game_config.dart';
import 'player.dart';

/// Prefill payload for the rematch flow ("PLAY AGAIN" on the result screen):
/// the previous game's rules + end-of-game roster, handed to a setup screen.
class SetupPrefill {
  const SetupPrefill({
    required this.playerIds,
    this.masterOut,
    this.handicap,
    this.noBust,
    this.config,
  });

  /// SavedPlayer ids in seat order at game end — mid-game joiners included,
  /// removed players excluded.
  final List<String> playerIds;

  // X01 options (X01 has no GameConfig subclass — it uses discrete params).
  final String? masterOut;
  final bool? handicap;
  final bool? noBust;

  /// The previous game's config for every other mode.
  final GameConfig? config;
}

/// Saved-player ids for the end-of-game roster, in seat order. [isRemoved] is
/// the calling screen's own removed-marker — the same check its
/// `_buildGameResult` uses. Guests (no saved id) are skipped.
List<String> rematchPlayerIds(
    List<Player> players, bool Function(int seat) isRemoved) {
  return [
    for (int i = 0; i < players.length; i++)
      if (!isRemoved(i) && players[i].savedPlayerId != null)
        players[i].savedPlayerId!,
  ];
}
