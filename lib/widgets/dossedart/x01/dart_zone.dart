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
  @override
  bool operator ==(Object other) => other is _Single && other.n == n;
  @override
  int get hashCode => Object.hash(_Single, n);
}

class _Double extends DartZone {
  const _Double(this.n);
  final int n;
  @override
  (int, int) toSegmentMultiplier() => (n, 2);
  @override
  bool operator ==(Object other) => other is _Double && other.n == n;
  @override
  int get hashCode => Object.hash(_Double, n);
}

class _Triple extends DartZone {
  const _Triple(this.n);
  final int n;
  @override
  (int, int) toSegmentMultiplier() => (n, 3);
  @override
  bool operator ==(Object other) => other is _Triple && other.n == n;
  @override
  int get hashCode => Object.hash(_Triple, n);
}

class _Bull extends DartZone {
  const _Bull();
  @override
  (int, int) toSegmentMultiplier() => (25, 1);
  @override
  bool operator ==(Object other) => other is _Bull;
  @override
  int get hashCode => runtimeType.hashCode;
}

class _DBull extends DartZone {
  const _DBull();
  @override
  (int, int) toSegmentMultiplier() => (25, 2);
  @override
  bool operator ==(Object other) => other is _DBull;
  @override
  int get hashCode => runtimeType.hashCode;
}

class _Miss extends DartZone {
  const _Miss();
  @override
  (int, int) toSegmentMultiplier() => (0, 1);
  @override
  bool operator ==(Object other) => other is _Miss;
  @override
  int get hashCode => runtimeType.hashCode;
}
