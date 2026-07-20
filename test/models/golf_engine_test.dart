import 'package:dart_scoring/models/golf_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GolfEngine scoring table', () {
    // (missesBefore, multiplier) -> expected strokes
    const cases = [
      (0, 3, 1), (0, 2, 2), (0, 1, 3),
      (1, 3, 2), (1, 2, 3), (1, 1, 4),
      (2, 3, 3), (2, 2, 4), (2, 1, 5),
    ];
    for (final (misses, mult, expected) in cases) {
      test('$misses miss(es) then x$mult = $expected strokes', () {
        final e = GolfEngine(playerCount: 2, holes: 18);
        for (var i = 0; i < misses; i++) {
          expect(e.applyDart(0).holeEnded, isFalse);
        }
        final r = e.applyDart(mult);
        expect(r.holeEnded, isTrue);
        expect(r.holeStrokes, expected);
        expect(e.scorecards[0][0], expected);
      });
    }

    test('three misses = 6 (TRIPLE BOGEY)', () {
      final e = GolfEngine(playerCount: 2, holes: 18);
      e.applyDart(0); e.applyDart(0);
      final r = e.applyDart(0);
      expect(r.holeEnded, isTrue);
      expect(r.holeStrokes, 6);
      expect(r.wasHit, isFalse);
    });

    test('hole ends on first hit — no fourth-dart gamble', () {
      final e = GolfEngine(playerCount: 2, holes: 18);
      final r = e.applyDart(1); // single, dart 1
      expect(r.holeEnded, isTrue);
      expect(e.currentPlayerIndex, 1); // turn passed immediately
    });

    test('golfTerm maps the full range', () {
      expect(golfTerm(1), 'ACE');
      expect(golfTerm(4), 'BOGEY');
      expect(golfTerm(6), 'TRIPLE BOGEY');
    });
  });

  group('GolfEngine round structure', () {
    test('every player completes hole N before hole N+1 starts', () {
      final e = GolfEngine(playerCount: 3, holes: 18);
      expect(e.holeNumber, 1);
      e.applyDart(1);              // P0 done
      expect(e.holeNumber, 1);
      expect(e.currentPlayerIndex, 1);
      e.applyDart(1);              // P1 done
      expect(e.holeNumber, 1);
      e.applyDart(1);              // P2 done → wrap
      expect(e.holeNumber, 2);
      expect(e.currentPlayerIndex, 0);
    });

    test('9-hole game ends after hole 9; lowest total wins', () {
      final e = GolfEngine(playerCount: 2, holes: 9);
      for (var h = 0; h < 9; h++) {
        e.applyDart(3); // P0: ace every hole (9 total)
        e.applyDart(1); // P1: par every hole (27 total)
      }
      expect(e.gameOver, isTrue);
      expect(e.winnerIndex, 0);
      expect(e.total(0), 9);
      expect(e.total(1), 27);
      expect(e.vsPar(0), -18);
    });

    test('stats: aces, bogeys, first-dart hits, best hole', () {
      final e = GolfEngine(playerCount: 1, holes: 9);
      e.applyDart(3);               // ace, first-dart hit
      e.applyDart(0); e.applyDart(1); // 4 = bogey
      e.applyDart(0); e.applyDart(0); e.applyDart(0); // 6
      expect(e.aces[0], 1);
      expect(e.bogeys[0], 2);       // the 4 and the 6
      expect(e.firstDartHits[0], 1);
      expect(e.bestHole[0], 1);
      expect(e.dartsThrown[0], 6);
    });
  });

  group('GolfEngine undo', () {
    test('undoing a hit reopens the hole with prior misses intact', () {
      final e = GolfEngine(playerCount: 2, holes: 18);
      e.applyDart(0);               // miss
      e.applyDart(2);               // double → 3 strokes, hole done
      expect(e.currentPlayerIndex, 1);
      e.undo();
      expect(e.currentPlayerIndex, 0);
      expect(e.missesThisHole, 1);
      expect(e.scorecards[0][0], isNull);
    });

    test('undo crosses a round transition', () {
      final e = GolfEngine(playerCount: 2, holes: 18);
      e.applyDart(1); e.applyDart(1); // hole 1 done for both → hole 2
      expect(e.holeNumber, 2);
      e.undo();
      expect(e.holeNumber, 1);
      expect(e.currentPlayerIndex, 1);
      expect(e.scorecards[1][0], isNull);
    });

    test('undo reopens a finished game', () {
      final e = GolfEngine(playerCount: 2, holes: 9);
      for (var h = 0; h < 9; h++) { e.applyDart(3); e.applyDart(1); }
      expect(e.gameOver, isTrue);
      e.undo();
      expect(e.gameOver, isFalse);
      expect(e.winnerIndex, isNull);
    });
  });

  group('GolfEngine sudden death', () {
    GolfEngine tied2() {
      final e = GolfEngine(playerCount: 2, holes: 9);
      for (var h = 0; h < 9; h++) { e.applyDart(1); e.applyDart(1); } // both 27
      return e;
    }

    test('tie for 1st starts sudden death on 19', () {
      final e = tied2();
      expect(e.gameOver, isFalse);
      expect(e.inSuddenDeath, isTrue);
      expect(e.playoffTarget, 19);
      expect(e.playoffParticipants, [0, 1]);
    });

    test('lowest playoff stroke wins; totals unchanged', () {
      final e = tied2();
      e.applyDart(3);              // P0: 1
      final r = e.applyDart(1);    // P1: 3
      expect(r.gameOver, isTrue);
      expect(e.winnerIndex, 0);
      expect(e.wonBySuddenDeath, isTrue);
      expect(e.total(0), 27);      // playoff strokes excluded
    });

    test('still tied → next target 20, then Bull, then cycles to 19', () {
      final e = tied2();
      e.applyDart(1); e.applyDart(1);          // both 3 on 19
      expect(e.inSuddenDeath, isTrue);
      expect(e.playoffTarget, 20);
      e.applyDart(1); e.applyDart(1);          // both 3 on 20
      expect(e.playoffTarget, 25);             // Bull
      e.applyDart(2); e.applyDart(2);          // both D-Bull (BIRDIE)
      expect(e.playoffTarget, 19);             // cycles
    });

    test('3-way tie: playoff winner 1st, losers share 2nd, next player 4th', () {
      final e = GolfEngine(playerCount: 4, holes: 9);
      for (var h = 0; h < 9; h++) {
        e.applyDart(1); e.applyDart(1); e.applyDart(1); // P0-P2: 27
        e.applyDart(0); e.applyDart(1);                 // P3: 4/hole = 36
      }
      expect(e.playoffParticipants, [0, 1, 2]);
      e.applyDart(3); e.applyDart(1); e.applyDart(1);   // P0 wins playoff
      expect(e.placements(), [1, 2, 2, 4]);
    });

    test('lower-placement ties share without playoff', () {
      final e = GolfEngine(playerCount: 3, holes: 9);
      for (var h = 0; h < 9; h++) {
        e.applyDart(3);                 // P0: 9
        e.applyDart(1); e.applyDart(1); // P1+P2: 27
      }
      expect(e.gameOver, isTrue);       // unique leader — no sudden death
      expect(e.placements(), [1, 2, 2]);
    });

    test('undo crosses the sudden-death start', () {
      final e = tied2();
      expect(e.inSuddenDeath, isTrue);
      e.undo();                          // undo P1's last regulation dart
      expect(e.inSuddenDeath, isFalse);
      expect(e.gameOver, isFalse);
      expect(e.holeNumber, 9);
    });
  });
}
