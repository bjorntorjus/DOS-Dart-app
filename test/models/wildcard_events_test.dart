import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/wildcard_events.dart';
import 'package:dart_scoring/theme/dossedart_tokens.dart';

void main() {
  group('segment sets (locked interpretation #1/#2)', () {
    test('segment sets are disjoint halves per locked interpretation', () {
      expect(wcUpperHalf.intersection(wcLowerHalf), isEmpty);
      expect(wcUpperHalf.length, 9);
      expect(wcLowerHalf.length, 9);
      expect(wcUpperHalf.contains(6), isFalse); // east boundary in neither
      expect(wcLowerHalf.contains(11), isFalse); // west boundary in neither
      expect(wcRightHalf.contains(20), isFalse); // north boundary in neither L/R
      expect(wcBlackSegments.length, 10);
    });

    test('wcBlackSegments exact members', () {
      expect(wcBlackSegments, {20, 18, 13, 10, 2, 3, 7, 8, 14, 12});
    });

    test('wcUpperHalf exact members', () {
      expect(wcUpperHalf, {14, 9, 12, 5, 20, 1, 18, 4, 13});
    });

    test('wcLowerHalf exact members', () {
      expect(wcLowerHalf, {10, 15, 2, 17, 3, 19, 7, 16, 8});
    });

    test('wcRightHalf exact members', () {
      expect(wcRightHalf, {1, 18, 4, 13, 6, 10, 15, 2, 17});
    });

    test('wcLeftHalf exact members', () {
      expect(wcLeftHalf, {19, 7, 16, 8, 11, 14, 9, 12, 5});
    });

    test('left/right halves disjoint and boundary segments excluded', () {
      expect(wcLeftHalf.intersection(wcRightHalf), isEmpty);
      expect(wcLeftHalf.length, 9);
      expect(wcLeftHalf.contains(20), isFalse); // north boundary
      expect(wcRightHalf.contains(3), isFalse); // south boundary
    });
  });

  group('wcModifiers definitions (spec §4)', () {
    test('exact ids in order', () {
      expect(wcModifiers.map((m) => m.id).toList(), [
        'onlyEvens',
        'onlyOdds',
        'onlyBlack',
        'onlyWhite',
        'divideByThree',
        'upperHalf',
        'lowerHalf',
        'leftHalf',
        'rightHalf',
        'everythingX2',
        'goldenDart',
        'holyTrinity',
        'bullsFortune',
        'bullsCurse',
        'doubleTrouble',
        'theWindow',
      ]);
    });

    test('exact display names, locked terminology', () {
      final byId = {for (final m in wcModifiers) m.id: m.name};
      expect(byId['onlyEvens'], 'ONLY EVENS');
      expect(byId['onlyOdds'], 'ONLY ODDS');
      expect(byId['onlyBlack'], 'ONLY BLACK');
      expect(byId['onlyWhite'], 'ONLY WHITE');
      expect(byId['divideByThree'], 'DIVIDE BY THREE');
      expect(byId['upperHalf'], 'UPPER HALF');
      expect(byId['lowerHalf'], 'LOWER HALF');
      expect(byId['leftHalf'], 'LEFT HALF');
      expect(byId['rightHalf'], 'RIGHT HALF');
      expect(byId['everythingX2'], 'EVERYTHING ×2');
      expect(byId['goldenDart'], 'GOLDEN DART');
      expect(byId['holyTrinity'], 'HOLY TRINITY');
      expect(byId['bullsFortune'], "BULL'S FORTUNE");
      expect(byId['bullsCurse'], "BULL'S CURSE");
      expect(byId['doubleTrouble'], 'DOUBLE TROUBLE');
      expect(byId['theWindow'], 'THE WINDOW');
    });

    test('severities per spec §4 table', () {
      final byId = {for (final m in wcModifiers) m.id: m.severity};
      for (final id in [
        'onlyEvens',
        'onlyOdds',
        'onlyBlack',
        'onlyWhite',
        'divideByThree',
        'upperHalf',
        'lowerHalf',
        'leftHalf',
        'rightHalf',
        'everythingX2',
        'goldenDart',
        'holyTrinity',
      ]) {
        expect(byId[id], WcSeverity.mild, reason: id);
      }
      for (final id in ['bullsFortune', 'bullsCurse', 'doubleTrouble', 'theWindow']) {
        expect(byId[id], WcSeverity.medium, reason: id);
      }
    });

    test('holyTrinity desc is the literal classic combo text', () {
      final byId = {for (final m in wcModifiers) m.id: m.desc};
      expect(byId['holyTrinity'], 'Hit single 20, 5 and 1 — the classic');
    });

    test('bullScores is true for all modifiers per locked rules', () {
      for (final m in wcModifiers) {
        expect(m.bullScores, isTrue, reason: m.id);
      }
    });

    WcModifierDef modifier(String id) => wcModifiers.firstWhere((m) => m.id == id);

    test('onlyEvens: value-based, not segment-based — D5 (=10) scores', () {
      final dims = modifier('onlyEvens').dims!;
      expect(dims(5, 1), isTrue); // S5 = 5, odd, dimmed
      expect(dims(5, 2), isFalse); // D5 = 10, even, scores!
      expect(dims(5, 3), isTrue); // T5 = 15, odd, dimmed
      expect(dims(8, 1), isFalse); // S8 = 8, even, scores
    });

    test('onlyOdds: value-based — D5 (=10, even) is dimmed', () {
      final dims = modifier('onlyOdds').dims!;
      expect(dims(5, 2), isTrue); // D5 = 10, even, dimmed
      expect(dims(5, 1), isFalse); // S5 = 5, odd, scores
    });

    test('onlyBlack dims non-black (white) segments, ignores multiplier', () {
      final dims = modifier('onlyBlack').dims!;
      for (final s in wcBlackSegments) {
        expect(dims(s, 1), isFalse, reason: 'black segment $s should score');
      }
      expect(dims(1, 1), isTrue); // 1 is white
      expect(dims(20, 1), isFalse); // 20 is black
    });

    test('onlyWhite dims black segments, ignores multiplier', () {
      final dims = modifier('onlyWhite').dims!;
      for (final s in wcBlackSegments) {
        expect(dims(s, 1), isTrue, reason: 'black segment $s should be dimmed');
      }
      expect(dims(1, 1), isFalse); // 1 is white, scores
    });

    test('divideByThree: value-based — T7 (=21) scores, S7 (=7) is dimmed', () {
      final dims = modifier('divideByThree').dims!;
      expect(dims(7, 3), isFalse); // T7 = 21, divisible by 3, scores
      expect(dims(7, 1), isTrue); // S7 = 7, not divisible by 3, dimmed
      expect(dims(9, 1), isFalse); // S9 = 9, divisible by 3, scores
      for (final s in [3, 6, 12, 15, 18]) {
        expect(dims(s, 1), isFalse, reason: '$s is a multiple of 3');
      }
      expect(dims(20, 1), isTrue);
    });

    test('upperHalf dims everything outside wcUpperHalf, ignores multiplier',
        () {
      final dims = modifier('upperHalf').dims!;
      for (final s in wcUpperHalf) {
        expect(dims(s, 1), isFalse);
      }
      expect(dims(10, 1), isTrue); // in lower half
      expect(dims(6, 1), isTrue); // boundary, dims (not in upper)
      // Ignores the multiplier — position is what matters here.
      expect(dims(10, 2), dims(10, 1));
    });

    test('lowerHalf dims everything outside wcLowerHalf', () {
      final dims = modifier('lowerHalf').dims!;
      for (final s in wcLowerHalf) {
        expect(dims(s, 1), isFalse);
      }
      expect(dims(20, 1), isTrue); // in upper half
      expect(dims(11, 1), isTrue); // boundary, dims (not in lower)
    });

    test('leftHalf dims everything outside wcLeftHalf', () {
      final dims = modifier('leftHalf').dims!;
      for (final s in wcLeftHalf) {
        expect(dims(s, 1), isFalse);
      }
      expect(dims(1, 1), isTrue); // in right half
      expect(dims(20, 1), isTrue); // boundary, dims (not in left)
    });

    test('rightHalf dims everything outside wcRightHalf', () {
      final dims = modifier('rightHalf').dims!;
      for (final s in wcRightHalf) {
        expect(dims(s, 1), isFalse);
      }
      expect(dims(19, 1), isTrue); // in left half
      expect(dims(3, 1), isTrue); // boundary, dims (not in right)
    });

    test('non-restriction modifiers have null dims (no board dimming)', () {
      for (final id in [
        'everythingX2',
        'goldenDart',
        'holyTrinity',
        'bullsFortune',
        'bullsCurse',
        'doubleTrouble',
        'theWindow',
      ]) {
        expect(modifier(id).dims, isNull, reason: id);
      }
    });
  });

  group('wcInstantEvents definitions (spec §5)', () {
    test('exact ids in order', () {
      expect(wcInstantEvents.map((e) => e.id).toList(), [
        'chaosSurge',
        'scoreSwap',
        'robinHood',
        'gift',
        'freeze',
        'cursedNumber',
        'doubleJeopardy',
        'cutEvent',
        'rewindEvent',
      ]);
    });

    test('exact display names, locked terminology', () {
      final byId = {for (final e in wcInstantEvents) e.id: e.name};
      expect(byId['chaosSurge'], 'CHAOS SURGE');
      expect(byId['scoreSwap'], 'SCORE SWAP');
      expect(byId['robinHood'], 'ROBIN HOOD');
      expect(byId['gift'], 'GIFT');
      expect(byId['freeze'], 'FREEZE');
      expect(byId['cursedNumber'], 'CURSED NUMBER');
      expect(byId['doubleJeopardy'], 'DOUBLE JEOPARDY');
      expect(byId['cutEvent'], 'CUT!');
      expect(byId['rewindEvent'], 'REWIND');
    });

    test('severities per spec §5 table', () {
      final byId = {for (final e in wcInstantEvents) e.id: e.severity};
      expect(byId['chaosSurge'], WcSeverity.mild);
      for (final id in ['scoreSwap', 'robinHood', 'gift', 'freeze', 'cursedNumber']) {
        expect(byId[id], WcSeverity.medium, reason: id);
      }
      for (final id in ['doubleJeopardy', 'cutEvent', 'rewindEvent']) {
        expect(byId[id], WcSeverity.wild, reason: id);
      }
    });

    test('icons are non-empty for every definition', () {
      for (final e in wcInstantEvents) {
        expect(e.icon, isNotEmpty, reason: e.id);
      }
      for (final m in wcModifiers) {
        expect(m.icon, isNotEmpty, reason: m.id);
        expect(m.desc, isNotEmpty, reason: m.id);
      }
    });
  });

  group('chaos tables (spec §3)', () {
    test('modifier chance table matches spec §3', () {
      expect(
        [for (var l = 0; l <= 10; l++) wcModifierChancePct(l)],
        [0, 5, 5, 15, 15, 30, 30, 50, 50, 80, 80],
      );
    });

    test('joker count table', () {
      expect(wcJokerCount(0), 0);
      for (var l = 1; l <= 6; l++) {
        expect(wcJokerCount(l), 1, reason: 'level $l');
      }
      expect(wcJokerCount(7), 1);
      expect(wcJokerCount(8), 1);
      expect(wcJokerCount(9), 2);
      expect(wcJokerCount(10), 2);
    });

    test('severity pools per level', () {
      expect(wcSeverityPool(0), isEmpty);
      expect(wcSeverityPool(1), [WcSeverity.mild]);
      expect(wcSeverityPool(3), [WcSeverity.mild]);
      expect(wcSeverityPool(4), [WcSeverity.mild]);
      expect(wcSeverityPool(5), [WcSeverity.mild, WcSeverity.medium]);
      expect(wcSeverityPool(6), containsAll([WcSeverity.mild, WcSeverity.medium]));
      expect(wcSeverityPool(6).contains(WcSeverity.wild), isFalse);
      expect(
        wcSeverityPool(7),
        containsAll([WcSeverity.mild, WcSeverity.medium, WcSeverity.wild]),
      );
      expect(wcSeverityPool(7).where((s) => s == WcSeverity.wild).length, 1);
      expect(wcSeverityPool(9).where((s) => s == WcSeverity.wild).length, 2); // wild weighted up
      expect(wcSeverityPool(10).where((s) => s == WcSeverity.wild).length, 2);
    });
  });

  group('wcRollWindow (locked rule #8)', () {
    test('window bounds: low shape spans 6, within 3..15', () {
      final rng = math.Random(42);
      for (var i = 0; i < 200; i++) {
        final w = wcRollWindow(rng, 8);
        expect(w.hi - w.lo, isIn([6, 20, 40]));
        expect(w.lo, greaterThanOrEqualTo(3));
      }
    });

    test('shapes stay within documented bounds for low chaos (1:2:2)', () {
      final rng = math.Random(7);
      for (var i = 0; i < 500; i++) {
        final w = wcRollWindow(rng, 2);
        final span = w.hi - w.lo;
        expect(span, isIn([6, 20, 40]));
        if (span == 6) {
          expect(w.lo, inInclusiveRange(3, 9));
          expect(w.hi, inInclusiveRange(9, 15));
        } else if (span == 20) {
          expect(w.lo, inInclusiveRange(40, 60));
          expect(w.hi, inInclusiveRange(60, 80));
        } else {
          expect(w.lo, inInclusiveRange(80, 120));
          expect(w.hi, inInclusiveRange(120, 160));
        }
      }
    });

    test('high chaos (>=7) skews toward the low shape (weight 3:2:1)', () {
      final rng = math.Random(99);
      var lowCount = 0;
      const iterations = 2000;
      for (var i = 0; i < iterations; i++) {
        final w = wcRollWindow(rng, 9);
        if (w.hi - w.lo == 6) lowCount++;
      }
      // Expected ~3/6 = 50%; allow generous tolerance for a statistical test.
      expect(lowCount / iterations, greaterThan(0.35));
      expect(lowCount / iterations, lessThan(0.65));
    });
  });

  group('wcChaosColor / wcChaosLabel', () {
    test('chaos color + label bands', () {
      expect(wcChaosColor(2), DossedartTokens.cyan);
      expect(wcChaosColor(10), DossedartTokens.red);
      expect(wcChaosLabel(0), 'DORMANT');
      expect(wcChaosLabel(10), 'TOTAL CHAOS');
    });

    test('full color band mapping', () {
      expect(wcChaosColor(0), DossedartTokens.cyan);
      expect(wcChaosColor(1), DossedartTokens.cyan);
      expect(wcChaosColor(3), DossedartTokens.green);
      expect(wcChaosColor(4), DossedartTokens.green);
      expect(wcChaosColor(5), DossedartTokens.yellow);
      expect(wcChaosColor(6), DossedartTokens.yellow);
      expect(wcChaosColor(7), DossedartTokens.orange);
      expect(wcChaosColor(8), DossedartTokens.orange);
      expect(wcChaosColor(9), DossedartTokens.red);
    });

    test('full label band mapping', () {
      expect(wcChaosLabel(1), 'MILD');
      expect(wcChaosLabel(2), 'MILD');
      expect(wcChaosLabel(3), 'BUBBLING');
      expect(wcChaosLabel(4), 'BUBBLING');
      expect(wcChaosLabel(5), 'SPICY');
      expect(wcChaosLabel(6), 'SPICY');
      expect(wcChaosLabel(7), 'WILD');
      expect(wcChaosLabel(8), 'WILD');
      expect(wcChaosLabel(9), 'TOTAL CHAOS');
    });
  });
}
