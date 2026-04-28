import 'dart:math';
import 'game_mode.dart';
import 'halve_it_round.dart';

sealed class GameConfig {
  final GameMode mode;
  const GameConfig(this.mode);
}

class X01Config extends GameConfig {
  final int startingScore;
  final bool doubleOut;
  const X01Config({required this.startingScore, this.doubleOut = false})
      : super(GameMode.x01);
}

class CricketConfig extends GameConfig {
  final bool isRandom;
  final bool isOpen; // all numbers 1-20 (+bull)
  final int targetCount; // 3-15, used if isRandom
  final bool includeBull;
  final bool isCutthroat; // reverse scoring: points go to opponents
  const CricketConfig({
    this.isRandom = false,
    this.isOpen = false,
    this.targetCount = 7,
    this.includeBull = true,
    this.isCutthroat = false,
  }) : super(GameMode.cricket);

  List<int> generateTargets() {
    if (isOpen) {
      final targets = List.generate(20, (i) => i + 1);
      if (includeBull) targets.add(25);
      // Sort descending, bull last
      targets.sort((a, b) {
        if (a == 25) return 1;
        if (b == 25) return -1;
        return b.compareTo(a);
      });
      return targets;
    }
    if (!isRandom) {
      final targets = [15, 16, 17, 18, 19, 20];
      if (includeBull) targets.add(25);
      return targets;
    }
    final rng = Random();
    final pool = List.generate(20, (i) => i + 1);
    pool.shuffle(rng);
    final count = includeBull ? targetCount - 1 : targetCount;
    final targets = pool.take(count.clamp(1, 20)).toList();
    if (includeBull) targets.add(25);
    targets.sort((a, b) {
      if (a == 25) return 1;
      if (b == 25) return -1;
      return b.compareTo(a); // descending like standard cricket
    });
    return targets;
  }
}

class AroundTheClockConfig extends GameConfig {
  final bool includeBull;
  final bool countMultiples; // D=2 steps, T=3 steps
  final bool reverse; // 20→1 instead of 1→20
  const AroundTheClockConfig({
    this.includeBull = false,
    this.countMultiples = true,
    this.reverse = false,
  }) : super(GameMode.aroundTheClock);
}

class KillerConfig extends GameConfig {
  final bool throwToPick; // true = throw, false = random
  final int lives;
  final bool multiplyHits; // double = 2× damage, triple = 3×
  final bool shields; // bull gives shields
  final bool suicide; // hitting own number costs lives
  const KillerConfig({
    this.throwToPick = true,
    this.lives = 3,
    this.multiplyHits = false,
    this.shields = false,
    this.suicide = false,
  }) : super(GameMode.killer);
}

class HalveItConfig extends GameConfig {
  final bool isRandom;
  final int roundCount; // 5-20
  final bool includeDouble;
  final bool includeTriple;
  final bool includeBull;
  const HalveItConfig({
    this.isRandom = false,
    this.roundCount = 9,
    this.includeDouble = true,
    this.includeTriple = true,
    this.includeBull = true,
  }) : super(GameMode.halveIt);

  List<HalveItRound> generateRounds() {
    if (!isRandom) {
      return [
        const HalveItRound(type: HalveItRoundType.number, targetNumber: 15),
        const HalveItRound(type: HalveItRoundType.number, targetNumber: 16),
        const HalveItRound(type: HalveItRoundType.anyDouble),
        const HalveItRound(type: HalveItRoundType.number, targetNumber: 17),
        const HalveItRound(type: HalveItRoundType.number, targetNumber: 18),
        const HalveItRound(type: HalveItRoundType.anyTriple),
        const HalveItRound(type: HalveItRoundType.number, targetNumber: 19),
        const HalveItRound(type: HalveItRoundType.number, targetNumber: 20),
        if (includeBull) const HalveItRound(type: HalveItRoundType.bull),
      ];
    }

    final rng = Random();
    final rounds = <HalveItRound>[];
    final numbers = List.generate(20, (i) => i + 1)..shuffle(rng);

    // Add special rounds first
    final specials = <HalveItRound>[];
    if (includeDouble) {
      specials
          .add(const HalveItRound(type: HalveItRoundType.anyDouble));
    }
    if (includeTriple) {
      specials
          .add(const HalveItRound(type: HalveItRoundType.anyTriple));
    }
    if (includeBull) {
      specials.add(const HalveItRound(type: HalveItRoundType.bull));
    }

    // Fill remaining with number rounds
    final numberCount = roundCount - specials.length;
    for (int i = 0; i < numberCount.clamp(0, 20); i++) {
      rounds.add(
          HalveItRound(type: HalveItRoundType.number, targetNumber: numbers[i]));
    }

    // Insert specials at random positions
    rounds.shuffle(rng);
    for (final s in specials) {
      final pos = rng.nextInt(rounds.length + 1);
      rounds.insert(pos, s);
    }

    return rounds;
  }
}
