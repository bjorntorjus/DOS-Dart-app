/// Pure data layer for WILDCARD — no game-state logic, no Flutter widgets.
///
/// Every turn-modifier (spec §4) and instant event (spec §5) is a plain data
/// definition consumed by `WildcardEngine` (a later task). Also carries the
/// chaos-meter tuning tables (spec §3), the four board-half/black-white
/// segment sets (locked interpretations #1/#2 in the implementation plan),
/// and the THE WINDOW bounds generator (locked interpretation #8).
///
/// The only Flutter dependency is `Color` (for [wcChaosColor]), which is
/// otherwise a pure-Dart file.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart' show Color;

import '../theme/dossedart_tokens.dart';

/// How rare/disruptive a modifier or event is; drives the chaos-level pools
/// in [wcSeverityPool] (spec §3).
enum WcSeverity { mild, medium, wild }

/// A per-turn personal modifier (spec §4): announced before the thrower's
/// turn, applies to that one turn only.
class WcModifierDef {
  /// Stable identifier, also used as the map key in [wcModifiers] lookups.
  final String id;

  /// UI headline — locked terminology, always upper-case English.
  final String name;

  /// Emoji glyph shown alongside [name] in the announcement overlay.
  final String icon;

  /// Directive sub-line explaining the effect in plain English.
  final String desc;

  final WcSeverity severity;

  /// Returns true for a (segment, multiplier) dart that does NOT score while
  /// this modifier is active. Value-based modifiers (ONLY EVENS/ODDS, DIVIDE
  /// BY THREE) judge the resulting dart *value* (segment × multiplier), so a
  /// D5 scores under ONLY EVENS even though S5 does not; positional
  /// modifiers (ONLY BLACK/WHITE, the board halves) ignore the multiplier.
  /// Also drives live board dimming (spec §6). `null` means the modifier
  /// does not restrict which segments score (e.g. EVERYTHING ×2). Bull is
  /// never covered by [dims] — see [bullScores].
  final bool Function(int segment, int multiplier)? dims;

  /// Whether bull hits score under this modifier. Always `true` per the
  /// locked rules (interpretation #1/#2): no modifier currently excludes
  /// bull. Kept as a field so a future modifier can flip it without an
  /// interface change.
  final bool bullScores;

  const WcModifierDef({
    required this.id,
    required this.name,
    required this.icon,
    required this.desc,
    required this.severity,
    this.dims,
    this.bullScores = true,
  });
}

/// An instant event fired when a joker is hit (spec §5).
class WcInstantEventDef {
  final String id;
  final String name;
  final String icon;
  final WcSeverity severity;

  const WcInstantEventDef({
    required this.id,
    required this.name,
    required this.icon,
    required this.severity,
  });
}

// ---------------------------------------------------------------------------
// Segment sets (locked interpretations #1 and #2 in the implementation plan).
//
// Derived from the board painter's segment order, clockwise from north:
//   kSegmentOrder = [20,1,18,4,13,6,10,15,2,17,3,19,7,16,8,11,14,9,12,5]
// Segment at index i sits at center angle i·18° (0° = north = 20, clockwise).
//
// BLACK = the dark-felt set = even indices (i % 2 == 0): 0,2,4,6,8,10,12,14,16,18
//   -> {20,18,13,10,2,3,7,8,14,12}. WHITE is the complementary 10 segments.
//   Bull counts as scoring for BOTH (it is neither felt).
//
// UPPER = centers in (270°, 90°) exclusive = indices 16-19 ∪ 0-4
//   -> {14,9,12,5,20,1,18,4,13}
// LOWER = centers in (90°, 270°) exclusive = indices 6-14
//   -> {10,15,2,17,3,19,7,16,8}
//   Boundary segments: index 5 (6, east/90°) and index 15 (11, west/270°)
//   belong to neither UPPER nor LOWER.
//
// RIGHT = indices 1-9  -> {1,18,4,13,6,10,15,2,17}
// LEFT  = indices 11-19 -> {19,7,16,8,11,14,9,12,5}
//   Boundary segments: index 0 (20, north/0°) and index 10 (3, south/180°)
//   belong to neither LEFT nor RIGHT.
// ---------------------------------------------------------------------------

/// The 10 dark-felt segments (locked interpretation #1).
const Set<int> wcBlackSegments = {20, 18, 13, 10, 2, 3, 7, 8, 14, 12};

/// Upper 9 segments by center angle (locked interpretation #2).
const Set<int> wcUpperHalf = {14, 9, 12, 5, 20, 1, 18, 4, 13};

/// Lower 9 segments by center angle (locked interpretation #2).
const Set<int> wcLowerHalf = {10, 15, 2, 17, 3, 19, 7, 16, 8};

/// Right 9 segments by center angle (locked interpretation #2).
const Set<int> wcRightHalf = {1, 18, 4, 13, 6, 10, 15, 2, 17};

/// Left 9 segments by center angle (locked interpretation #2).
const Set<int> wcLeftHalf = {19, 7, 16, 8, 11, 14, 9, 12, 5};

// ---------------------------------------------------------------------------
// Modifier definitions (spec §4). Order matches the plan's binding list.
// ---------------------------------------------------------------------------

const onlyEvens = WcModifierDef(
  id: 'onlyEvens',
  name: 'ONLY EVENS',
  icon: '🔢',
  desc: 'Only even dart values score this turn',
  severity: WcSeverity.mild,
  dims: _dimsOddValue,
);
bool _dimsOddValue(int s, int m) => (s * m).isOdd;

const onlyOdds = WcModifierDef(
  id: 'onlyOdds',
  name: 'ONLY ODDS',
  icon: '🔢',
  desc: 'Only odd dart values score this turn',
  severity: WcSeverity.mild,
  dims: _dimsEvenValue,
);
bool _dimsEvenValue(int s, int m) => (s * m).isEven;

const onlyBlack = WcModifierDef(
  id: 'onlyBlack',
  name: 'ONLY BLACK',
  icon: '⚫',
  desc: 'Only black segments score this turn',
  severity: WcSeverity.mild,
  dims: _dimsNonBlack,
);
bool _dimsNonBlack(int s, int _) => !wcBlackSegments.contains(s);

const onlyWhite = WcModifierDef(
  id: 'onlyWhite',
  name: 'ONLY WHITE',
  icon: '⚪',
  desc: 'Only white segments score this turn',
  severity: WcSeverity.mild,
  dims: _dimsBlack,
);
bool _dimsBlack(int s, int _) => wcBlackSegments.contains(s);

const divideByThree = WcModifierDef(
  id: 'divideByThree',
  name: 'DIVIDE BY THREE',
  icon: '➗',
  desc: 'Only dart values divisible by 3 score',
  severity: WcSeverity.mild,
  dims: _dimsNotDivisibleByThree,
);
bool _dimsNotDivisibleByThree(int s, int m) => (s * m) % 3 != 0;

const upperHalf = WcModifierDef(
  id: 'upperHalf',
  name: 'UPPER HALF',
  icon: '⬆️',
  desc: 'Only the upper half of the board scores this turn',
  severity: WcSeverity.mild,
  dims: _dimsNotUpper,
);
bool _dimsNotUpper(int s, int _) => !wcUpperHalf.contains(s);

const lowerHalf = WcModifierDef(
  id: 'lowerHalf',
  name: 'LOWER HALF',
  icon: '⬇️',
  desc: 'Only the lower half of the board scores this turn',
  severity: WcSeverity.mild,
  dims: _dimsNotLower,
);
bool _dimsNotLower(int s, int _) => !wcLowerHalf.contains(s);

const leftHalf = WcModifierDef(
  id: 'leftHalf',
  name: 'LEFT HALF',
  icon: '⬅️',
  desc: 'Only the left half of the board scores this turn',
  severity: WcSeverity.mild,
  dims: _dimsNotLeft,
);
bool _dimsNotLeft(int s, int _) => !wcLeftHalf.contains(s);

const rightHalf = WcModifierDef(
  id: 'rightHalf',
  name: 'RIGHT HALF',
  icon: '➡️',
  desc: 'Only the right half of the board scores this turn',
  severity: WcSeverity.mild,
  dims: _dimsNotRight,
);
bool _dimsNotRight(int s, int _) => !wcRightHalf.contains(s);

const everythingX2 = WcModifierDef(
  id: 'everythingX2',
  name: 'EVERYTHING ×2',
  icon: '✖️',
  desc: 'Turn total doubled',
  severity: WcSeverity.mild,
);

const goldenDart = WcModifierDef(
  id: 'goldenDart',
  name: 'GOLDEN DART',
  icon: '🌟',
  desc: 'Last dart counts ×3',
  severity: WcSeverity.mild,
);

const holyTrinity = WcModifierDef(
  id: 'holyTrinity',
  name: 'HOLY TRINITY',
  icon: '🙏',
  desc: 'Hit single 20, 5 and 1 — the classic',
  severity: WcSeverity.mild,
);

const bullsFortune = WcModifierDef(
  id: 'bullsFortune',
  name: "BULL'S FORTUNE",
  icon: '🍀',
  desc: 'Bull worth 100 this turn',
  severity: WcSeverity.medium,
);

const bullsCurse = WcModifierDef(
  id: 'bullsCurse',
  name: "BULL'S CURSE",
  icon: '💀',
  desc: 'Bull drains 100 this turn',
  severity: WcSeverity.medium,
);

const doubleTrouble = WcModifierDef(
  id: 'doubleTrouble',
  name: 'DOUBLE TROUBLE',
  icon: '🎭',
  desc: 'Doubles score triple, triples score zero',
  severity: WcSeverity.medium,
);

const theWindow = WcModifierDef(
  id: 'theWindow',
  name: 'THE WINDOW',
  icon: '🪟',
  desc: 'Land your turn total inside the window for a flat 100',
  severity: WcSeverity.medium,
);

/// All 16 turn-modifiers, exact ids per the implementation plan.
const wcModifiers = <WcModifierDef>[
  onlyEvens,
  onlyOdds,
  onlyBlack,
  onlyWhite,
  divideByThree,
  upperHalf,
  lowerHalf,
  leftHalf,
  rightHalf,
  everythingX2,
  goldenDart,
  holyTrinity,
  bullsFortune,
  bullsCurse,
  doubleTrouble,
  theWindow,
];

// ---------------------------------------------------------------------------
// Instant event definitions (spec §5). Order matches the plan's binding list.
// ---------------------------------------------------------------------------

const chaosSurge = WcInstantEventDef(
  id: 'chaosSurge',
  name: 'CHAOS SURGE',
  icon: '⚡',
  severity: WcSeverity.mild,
);

const scoreSwap = WcInstantEventDef(
  id: 'scoreSwap',
  name: 'SCORE SWAP',
  icon: '🔄',
  severity: WcSeverity.medium,
);

const robinHood = WcInstantEventDef(
  id: 'robinHood',
  name: 'ROBIN HOOD',
  icon: '🏹',
  severity: WcSeverity.medium,
);

const gift = WcInstantEventDef(
  id: 'gift',
  name: 'GIFT',
  icon: '🎁',
  severity: WcSeverity.medium,
);

const freeze = WcInstantEventDef(
  id: 'freeze',
  name: 'FREEZE',
  icon: '🧊',
  severity: WcSeverity.medium,
);

const cursedNumber = WcInstantEventDef(
  id: 'cursedNumber',
  name: 'CURSED NUMBER',
  icon: '☠️',
  severity: WcSeverity.medium,
);

const doubleJeopardy = WcInstantEventDef(
  id: 'doubleJeopardy',
  name: 'DOUBLE JEOPARDY',
  icon: '🎲',
  severity: WcSeverity.wild,
);

const cutEvent = WcInstantEventDef(
  id: 'cutEvent',
  name: 'CUT!',
  icon: '✂️',
  severity: WcSeverity.wild,
);

const rewindEvent = WcInstantEventDef(
  id: 'rewindEvent',
  name: 'REWIND',
  icon: '⏪',
  severity: WcSeverity.wild,
);

/// All 9 instant events, exact ids per the implementation plan.
const wcInstantEvents = <WcInstantEventDef>[
  chaosSurge,
  scoreSwap,
  robinHood,
  gift,
  freeze,
  cursedNumber,
  doubleJeopardy,
  cutEvent,
  rewindEvent,
];

// ---------------------------------------------------------------------------
// Chaos tables (spec §3).
// ---------------------------------------------------------------------------

const List<int> _modifierChancePctByLevel = [
  0, 5, 5, 15, 15, 30, 30, 50, 50, 80, 80,
];

/// Percent chance a modifier is rolled at turn start, per chaos level (0-10).
int wcModifierChancePct(int level) => _modifierChancePctByLevel[level];

/// Deterministic joker count per chaos level (spec §3 table). The 7-8 band
/// nominally reads "1-2" but the extra joker there only appears via the
/// DOUBLE JEOPARDY event (added by the engine, not this base table) so the
/// RNG-independent baseline stays 1.
int wcJokerCount(int level) {
  if (level <= 0) return 0;
  if (level <= 8) return 1;
  return 2;
}

/// Severities eligible to be drawn for an instant event at this chaos level
/// (spec §3). At levels 9-10 [WcSeverity.wild] appears twice to weight wild
/// events up in a uniform random pick over the returned list.
List<WcSeverity> wcSeverityPool(int level) {
  if (level <= 0) return const [];
  if (level <= 4) return const [WcSeverity.mild];
  if (level <= 6) return const [WcSeverity.mild, WcSeverity.medium];
  if (level <= 8) {
    return const [WcSeverity.mild, WcSeverity.medium, WcSeverity.wild];
  }
  return const [
    WcSeverity.mild,
    WcSeverity.medium,
    WcSeverity.wild,
    WcSeverity.wild,
  ];
}

// ---------------------------------------------------------------------------
// THE WINDOW bounds generator (locked interpretation #8).
// ---------------------------------------------------------------------------

/// Rolls THE WINDOW bounds (inclusive) for one activation.
///
/// Three shapes: low `[a, a+6]` with `a` in 3..9, mid `[a, a+20]` with `a` in
/// 40..60, high `[a, a+40]` with `a` in 80..120. At `chaosLevel >= 7` the
/// shapes are weighted low:mid:high = 3:2:1 (skewing toward the narrow, brutal
/// windows); otherwise 1:2:2. [rng] must be injected — never construct
/// `Random` inside this function.
({int lo, int hi}) wcRollWindow(math.Random rng, int chaosLevel) {
  final weights = chaosLevel >= 7 ? const [3, 2, 1] : const [1, 2, 2];
  final total = weights[0] + weights[1] + weights[2];
  final roll = rng.nextInt(total);

  if (roll < weights[0]) {
    final a = 3 + rng.nextInt(7); // 3..9 inclusive
    return (lo: a, hi: a + 6);
  }
  if (roll < weights[0] + weights[1]) {
    final a = 40 + rng.nextInt(21); // 40..60 inclusive
    return (lo: a, hi: a + 20);
  }
  final a = 80 + rng.nextInt(41); // 80..120 inclusive
  return (lo: a, hi: a + 40);
}

// ---------------------------------------------------------------------------
// Chaos meter presentation helpers (widgets consume these; pure functions).
// ---------------------------------------------------------------------------

/// Heat color for the chaos meter at [level] (0-10).
Color wcChaosColor(int level) {
  if (level <= 2) return DossedartTokens.cyan;
  if (level <= 4) return DossedartTokens.green;
  if (level <= 6) return DossedartTokens.yellow;
  if (level <= 8) return DossedartTokens.orange;
  return DossedartTokens.red;
}

/// Heat label for the chaos meter at [level] (0-10).
String wcChaosLabel(int level) {
  if (level <= 0) return 'DORMANT';
  if (level <= 2) return 'MILD';
  if (level <= 4) return 'BUBBLING';
  if (level <= 6) return 'SPICY';
  if (level <= 8) return 'WILD';
  return 'TOTAL CHAOS';
}
