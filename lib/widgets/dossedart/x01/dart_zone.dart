/// A region on the DOSSEDART dartboard that a tap can resolve to.
///
/// Use [toSegmentMultiplier] to feed the result into the existing
/// `_GameScreenState._onDartHit(int segment, int multiplier)` API.
sealed class DartZone {
  const DartZone();

  const factory DartZone.single(int n) = _Single;
  const factory DartZone.double_(int n) = _Double;
  const factory DartZone.triple(int n) = _Triple;
  const factory DartZone.bull() = _Bull;
  const factory DartZone.dBull() = _DBull;
  const factory DartZone.miss() = _Miss;

  /// (segment, multiplier) pair for the production scoring engine.
  /// MISS maps to (0, 1) so points = 0 * 1 = 0.
  (int, int) toSegmentMultiplier();
}

class _Single extends DartZone {
  const _Single(this.n);
  final int n;
  @override
  (int, int) toSegmentMultiplier() => (n, 1);
}

class _Double extends DartZone {
  const _Double(this.n);
  final int n;
  @override
  (int, int) toSegmentMultiplier() => (n, 2);
}

class _Triple extends DartZone {
  const _Triple(this.n);
  final int n;
  @override
  (int, int) toSegmentMultiplier() => (n, 3);
}

class _Bull extends DartZone {
  const _Bull();
  @override
  (int, int) toSegmentMultiplier() => (25, 1);
}

class _DBull extends DartZone {
  const _DBull();
  @override
  (int, int) toSegmentMultiplier() => (25, 2);
}

class _Miss extends DartZone {
  const _Miss();
  @override
  (int, int) toSegmentMultiplier() => (0, 1);
}
