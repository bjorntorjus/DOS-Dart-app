/// Seat-picking for mid-game joiners.
///
/// A joiner is seeded from the active player currently placed LAST in the
/// mode's own ranking — never from the table average, which used to hand a
/// newcomer a better position than the player who had been struggling all
/// game (tester feedback, 2026-08-10).
///
/// No mode re-derives "what is best" here: each one passes the comparator or
/// direction its own ranking already uses.
library;

/// Appends seat order as the final tiebreak to [bestFirst].
///
/// Two purposes. A joiner is seeded from last place and is therefore tied with
/// them; holding the highest seat index, the joiner sorts behind — so the
/// player who earned last place keeps their position and no score is invented.
/// Independently, `List.sort` in Dart is NOT stable, so without this, genuinely
/// tied players order arbitrarily between rebuilds.
Comparator<int> withSeatTiebreak(Comparator<int> bestFirst) => (a, b) {
      final c = bestFirst(a, b);
      return c != 0 ? c : a.compareTo(b);
    };

/// The seat that sorts last among [activeSeats] under [bestFirst] — i.e. the
/// worst-placed active seat. Returns null when [activeSeats] is empty, which
/// callers translate into their mode's default starting state.
///
/// [bestFirst] is wrapped in [withSeatTiebreak], so equal seats resolve to the
/// latest one.
int? worstSeatBy(Iterable<int> activeSeats, Comparator<int> bestFirst) {
  final seats = activeSeats.toList();
  if (seats.isEmpty) return null;
  seats.sort(withSeatTiebreak(bestFirst));
  return seats.last;
}

/// [worstSeatBy] for the modes whose ranking is a single int list indexed by
/// seat: remaining score, total, lives, strokes, segments remaining.
///
/// [higherIsBetter] states the direction — true for point-accumulating modes
/// and for lives, false for countdowns and stroke/segment counts.
int? worstSeat(
  List<int> values,
  Iterable<int> activeSeats, {
  required bool higherIsBetter,
}) =>
    worstSeatBy(
      activeSeats,
      (a, b) => higherIsBetter
          ? values[b].compareTo(values[a])
          : values[a].compareTo(values[b]),
    );
