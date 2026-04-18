enum HalveItRoundType { number, anyDouble, anyTriple, bull }

class HalveItRound {
  final HalveItRoundType type;
  final int? targetNumber; // non-null for number type (1-20)

  const HalveItRound({required this.type, this.targetNumber});

  String get label {
    switch (type) {
      case HalveItRoundType.number:
        return '$targetNumber';
      case HalveItRoundType.anyDouble:
        return 'Double';
      case HalveItRoundType.anyTriple:
        return 'Triple';
      case HalveItRoundType.bull:
        return 'Bull';
    }
  }

  bool isHit(int segment, int multiplier) {
    switch (type) {
      case HalveItRoundType.number:
        return segment == targetNumber;
      case HalveItRoundType.anyDouble:
        return multiplier == 2;
      case HalveItRoundType.anyTriple:
        return multiplier == 3;
      case HalveItRoundType.bull:
        return segment == 25;
    }
  }

  int pointsFor(int segment, int multiplier) {
    if (!isHit(segment, multiplier)) return 0;
    return segment * multiplier;
  }
}
