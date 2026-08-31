/// Placement compaction for games with a mid-game roster change
/// (spec `docs/superpowers/specs/2026-08-26-midgame-roster-stats-design.md`).
///
/// The Family-A screens (X01, ATC, Splitscore, Killer) build placements from
/// their own ordering (`finishedPlayers`, lives, total score), which gives a
/// removed seat a REAL rank. Every consumer excludes that seat afterwards, so
/// the numbers that survive can have a hole in them: with seat 2 removed and
/// holding 1st, the actual winner is persisted as `2`, the runner-up as `3`.
/// The history rows, KAMPDETALJER and the season tables all read those raw
/// numbers, so they must be compacted before they are handed on.
///
/// [denseRankActive] renumbers the NON-excluded seats densely — sorted
/// distinct placement values map to 1, 2, 3, … — while leaving excluded seats'
/// values untouched (they are dropped by `excludedSeats` downstream anyway).
/// Ties are preserved: two seats sharing an old placement share the new rank.
///
/// An empty [excludedSeats] is the identity: a game with no roster change gets
/// byte-for-byte the placements its screen built, competition-style ties and
/// all.
///
///     denseRankActive([2, 3, 1], {2})    // [1, 2, 1]
///     denseRankActive([1, 1, 3, 2], {3}) // [1, 1, 2, 2]
///     denseRankActive([1, 1, 3], {})     // [1, 1, 3]
List<int> denseRankActive(List<int> placements, Set<int> excludedSeats) {
  if (excludedSeats.isEmpty) return List<int>.from(placements);

  final distinct = <int>{
    for (var i = 0; i < placements.length; i++)
      if (!excludedSeats.contains(i)) placements[i],
  }.toList()
    ..sort();
  final rankOf = {
    for (var i = 0; i < distinct.length; i++) distinct[i]: i + 1,
  };

  return [
    for (var i = 0; i < placements.length; i++)
      excludedSeats.contains(i) ? placements[i] : rankOf[placements[i]]!,
  ];
}
