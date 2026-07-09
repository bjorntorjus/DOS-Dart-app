import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/gotcha_engine.dart';

void main() {
  group('GotchaEngine core', () {
    test('players start at 0 and climb', () {
      final e = GotchaEngine(target: 301, playerCount: 2);
      expect(e.totals, [0, 0]);
      final r = e.applyDart(20, 3); // T20
      expect(r.points, 60);
      expect(e.totals[0], 60);
      expect(e.dartsInTurn, 1);
      expect(r.turnEnded, isFalse);
    });

    test('turn ends after 3 darts and rotation advances', () {
      final e = GotchaEngine(target: 301, playerCount: 2);
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      final r = e.applyDart(20, 1);
      expect(r.turnEnded, isTrue);
      expect(e.currentPlayerIndex, 1);
      expect(e.dartsInTurn, 0);
      expect(e.turnStartScore, 0); // next player's turn baseline
    });

    test('exact target wins immediately', () {
      final e = GotchaEngine(target: 101, playerCount: 2);
      e.applyDart(20, 3);
      e.applyDart(20, 2); // 100
      final r = e.applyDart(1, 1); // 101
      expect(r.playerWon, isTrue);
      expect(e.gameOver, isTrue);
      expect(e.winnerIndex, 0);
      // Game is frozen at the winning state — turn advance is skipped when
      // gameOver, so the darts-in-turn counter and seat are left as-is.
      expect(e.dartsInTurn, 3);
      expect(e.currentPlayerIndex, 0);
    });

    test('overshoot busts: revert to turn start, turn ends, bust counted', () {
      final e = GotchaEngine(target: 101, playerCount: 2);
      e.applyDart(20, 3); // 60
      final r = e.applyDart(20, 3); // 120 > 101 → bust
      expect(r.isBust, isTrue);
      expect(r.turnEnded, isTrue);
      expect(e.totals[0], 0); // reverted to turn start (0)
      expect(e.busts[0], 1);
      expect(e.currentPlayerIndex, 1);
    });

    test('bust reverts to score at START of turn, not previous dart', () {
      final e = GotchaEngine(target: 201, playerCount: 2);
      e.applyDart(20, 1);
      e.applyDart(20, 1);
      e.applyDart(20, 1); // P0 = 60, turn ends
      e.applyDart(1, 1);
      e.applyDart(1, 1);
      e.applyDart(1, 1); // P1 = 3, turn ends, back to P0
      e.applyDart(20, 3); // P0 = 120 (not bust)
      e.applyDart(20, 3); // P0 = 180 (not bust)
      final result = e.applyDart(19, 3); // P0 = 237 > 201 → bust
      expect(result.isBust, isTrue);
      expect(e.totals[0], 60); // start-of-turn baseline, NOT 180
      expect(e.busts[0], 1);
      expect(e.currentPlayerIndex, 1);
    });

    test('snapshot undo restores everything', () {
      final e = GotchaEngine(target: 101, playerCount: 2);
      e.applyDart(20, 3); // 60
      final r = e.applyDart(20, 3); // bust → 0, seat advanced
      expect(r.isBust, isTrue);
      e.undo();
      expect(e.totals[0], 60);
      expect(e.busts[0], 0);
      expect(e.currentPlayerIndex, 0);
      expect(e.dartsInTurn, 1);
      e.undo();
      expect(e.totals[0], 0);
      expect(e.canUndo, isFalse);
      e.undo(); // empty stack: silent no-op
      expect(e.totals[0], 0);
    });

    test('undo across a win reopens the game', () {
      final e = GotchaEngine(target: 101, playerCount: 2);
      e.applyDart(20, 3);
      e.applyDart(20, 2);
      e.applyDart(1, 1); // win
      expect(e.gameOver, isTrue);
      e.undo();
      expect(e.gameOver, isFalse);
      expect(e.winnerIndex, isNull);
      expect(e.totals[0], 100);
    });

    test('miss (0 points) consumes a dart, cannot bust', () {
      final e = GotchaEngine(target: 101, playerCount: 2);
      final r = e.applyDart(0, 0);
      expect(r.points, 0);
      expect(r.isBust, isFalse);
      expect(e.dartsInTurn, 1);
    });
  });

  group('GotchaEngine kills', () {
    test('landing exactly on an opponent resets them, thrower keeps score', () {
      // hardcore: general kill-mechanic test (thrower keeps score, counters
      // increment) — not testing halving vs. reset, so pin v1 semantics.
      final e = GotchaEngine(target: 301, playerCount: 2, hardcore: true);
      e.applyDart(15, 3); e.applyDart(0, 0); e.applyDart(0, 0); // P0 = 45
      e.applyDart(20, 1); e.applyDart(20, 1); final r0 = e.applyDart(5, 1); // P1 = 45!
      expect(r0.killed, [0]);
      expect(e.totals[0], 0);   // P0 gotcha'd
      expect(e.totals[1], 45);  // thrower unaffected
      expect(e.killsMade[1], 1);
      expect(e.timesKilled[0], 1);
    });
    test('multiple opponents on the same score all reset on one dart', () {
      // White-box direct total setup: sequentially scripting P0 and P1 both
      // to 20 via applyDart is not possible without P1's own build-up dart
      // killing P0 mid-turn first (landing exactly on 20 kills on ANY
      // scoring dart, per the "kills stand when thrower busts" spec point).
      // hardcore: intent is the double-kill-on-one-dart mechanic, not
      // halving vs. reset — pin v1 semantics for a simple totals literal.
      final e = GotchaEngine(target: 301, playerCount: 3, hardcore: true);
      e.totals[0] = 20; e.totals[1] = 20; e.totals[2] = 0;
      e.currentPlayerIndex = 2;
      final r = e.applyDart(20, 1); // P2 = 20 → double kill
      expect(r.killed, [0, 1]);
      expect(e.totals, [0, 0, 20]);
      expect(e.killsMade[2], 2);
    });
    test('kills stand when the thrower busts later in the same turn', () {
      // hardcore: intent is that a kill survives a later bust-revert, not
      // halving vs. reset — pin v1 semantics.
      final e = GotchaEngine(target: 101, playerCount: 2, hardcore: true);
      e.applyDart(20, 2); e.applyDart(0, 0); e.applyDart(0, 0); // P0 = 40
      final rKill = e.applyDart(20, 2);   // P1 dart 1: 40 → lands on P0 → kill
      expect(rKill.killed, [0]);
      expect(e.totals[0], 0);
      e.applyDart(20, 3);                  // P1 dart 2: 100 (≤101, fine)
      final rBust = e.applyDart(2, 1);     // P1 dart 3: 102 > 101 → bust
      expect(rBust.isBust, isTrue);
      expect(e.totals[1], 0);              // reverted to P1's turn start (0)
      expect(e.totals[0], 0);              // the kill is NOT rolled back
      expect(e.killsMade[1], 1);
      expect(e.timesKilled[0], 1);
    });
    test('a kill dart ignores opponents at 0', () {
      // hardcore: intent is that dead (0) players are excluded from the kill
      // scan, not halving vs. reset — pin v1 semantics.
      final e = GotchaEngine(target: 301, playerCount: 3, hardcore: true);
      e.totals[0] = 60; e.totals[1] = 45; e.totals[2] = 0;
      e.currentPlayerIndex = 1;
      final r = e.applyDart(15, 1);        // P1: 45+15 = 60 → kills P0 only
      expect(r.killed, [0]);
      expect(e.totals[0], 0);
      expect(e.totals[2], 0);
      expect(e.timesKilled[2], 0);         // the dead player was never "killed again"
    });
    test('a miss never kills, even at a shared total', () {
      final e = GotchaEngine(target: 301, playerCount: 2);
      e.totals[0] = 45; e.totals[1] = 45;  // shared-total state (reachable via bust-revert/addPlayer)
      e.currentPlayerIndex = 1;
      final r = e.applyDart(0, 0);         // miss: total stays 45 == opponent's 45
      expect(r.killed, isEmpty);
      expect(e.totals[0], 45);
      expect(e.timesKilled[0], 0);
    });
    test('undo across a kill restores the victim', () {
      // hardcore: intent is that undo restores the victim's pre-kill total,
      // not halving vs. reset — pin v1 semantics.
      final e = GotchaEngine(target: 301, playerCount: 2, hardcore: true);
      e.applyDart(15, 3); e.applyDart(0, 0); e.applyDart(0, 0); // P0 = 45
      e.applyDart(15, 3);                                        // P1 = 45 → kill P0
      expect(e.totals[0], 0);
      e.undo();
      expect(e.totals[0], 45);
      expect(e.killsMade[1], 0);
      expect(e.timesKilled[0], 0);
    });
  });

  group('GotchaEngine halving mode (default)', () {
    test('kill halves the victim instead of resetting', () {
      final e = GotchaEngine(target: 301, playerCount: 2);
      e.totals[0] = 300; e.currentPlayerIndex = 1; e.totals[1] = 280;
      final r = e.applyDart(20, 1); // 280+20=300 -> lands on P0
      expect(r.killed, [0]);
      expect(e.totals[0], 150);
      expect(e.timesKilled[0], 1);
    });
    test('halving 1 finishes the player (1 ~/ 2 == 0)', () {
      final e = GotchaEngine(target: 301, playerCount: 2);
      e.totals[0] = 1; e.currentPlayerIndex = 1; e.totals[1] = 0;
      e.applyDart(1, 1); // lands on 1
      expect(e.totals[0], 0);
    });
    test('hardcore resets to 0 (v1 behavior)', () {
      final e = GotchaEngine(target: 301, playerCount: 2, hardcore: true);
      e.totals[0] = 300; e.currentPlayerIndex = 1; e.totals[1] = 240;
      final r = e.applyDart(20, 3); // 240+60=300 -> lands on P0
      expect(r.killed, [0]);
      expect(e.totals[0], 0);
      expect(e.timesKilled[0], 1);
    });
    test('chain-halving: same victim halved twice in one round by two attackers', () {
      final e = GotchaEngine(target: 501, playerCount: 3);
      e.totals[0] = 300; e.totals[1] = 240; e.totals[2] = 90;
      e.currentPlayerIndex = 1;
      e.applyDart(20, 3); // P1: 240+60=300 -> lands on P0 -> halves to 150
      expect(e.totals[0], 150);
      e.applyDart(0, 0); e.applyDart(0, 0); // P1 darts 2-3, turn ends -> P2
      expect(e.currentPlayerIndex, 2);
      expect(e.round, 0); // no wrap yet
      e.applyDart(20, 3); // P2: 90+60=150 -> lands on P0 (now 150) -> halves to 75
      expect(e.totals[0], 75);
      expect(e.round, 0); // both kills happened before the wrap back to P0
      expect(e.killLog, [
        (round: 0, attacker: 1, victim: 0),
        (round: 0, attacker: 2, victim: 0),
      ]);
    });
    test('undo restores the halved total, round and killLog', () {
      final e = GotchaEngine(target: 301, playerCount: 2);
      e.totals[0] = 300; e.currentPlayerIndex = 1; e.totals[1] = 280;
      e.applyDart(20, 1);
      expect(e.killLog, hasLength(1));
      e.undo();
      expect(e.totals[0], 300);
      expect(e.killLog, isEmpty);
    });
    test('halving kills stand when the thrower busts later in the same turn', () {
      final e = GotchaEngine(target: 101, playerCount: 2);
      e.totals[0] = 80; e.currentPlayerIndex = 1; e.totals[1] = 40;
      e.turnStartScore = 40;
      final rKill = e.applyDart(20, 2); // P1 dart 1: D20 = 40 points, newTotal 40+40=80
      expect(rKill.killed, [0]);
      expect(e.totals[0], 40); // P0 halved from 80 to 40
      expect(e.totals[1], 80); // P1 at landing value
      final rBust = e.applyDart(20, 3); // P1 dart 2: T20 = 60 points, newTotal 80+60=140 > 101
      expect(rBust.isBust, isTrue);
      expect(e.totals[1], 40); // reverted to turnStartScore
      expect(e.totals[0], 40); // the kill stands, not rolled back
      expect(e.killsMade[1], 1);
      expect(e.timesKilled[0], 1);
    });
    test('one dart halves multiple opponents on the shared total', () {
      final e = GotchaEngine(target: 501, playerCount: 3);
      e.totals[0] = 200; e.totals[1] = 200; e.totals[2] = 140;
      e.currentPlayerIndex = 2;
      final r = e.applyDart(20, 3); // P2: T20 = 60 points, newTotal 140+60=200
      expect(r.killed, [0, 1]); // both P0 and P1 at 200
      expect(e.totals, [100, 100, 200]); // both halved to 100
      expect(e.killLog, [
        (round: 0, attacker: 2, victim: 0),
        (round: 0, attacker: 2, victim: 1),
      ]);
    });
    test('a halving dart ignores opponents at 0', () {
      final e = GotchaEngine(target: 301, playerCount: 3);
      e.totals[0] = 60; e.totals[1] = 0; e.totals[2] = 45;
      e.currentPlayerIndex = 2;
      final r = e.applyDart(15, 1); // P2: S15 = 15 points, newTotal 45+15=60
      expect(r.killed, [0]); // only P0 at 60
      expect(e.totals[0], 30); // P0 halved
      expect(e.totals[1], 0); // P1 untouched (was already at 0)
      expect(e.totals[2], 60); // P2 at landing value
      expect(e.timesKilled[1], 0); // P1 never killed
    });
    test('halving leaves the thrower untouched', () {
      final e = GotchaEngine(target: 301, playerCount: 2);
      e.totals[0] = 100; e.currentPlayerIndex = 1; e.totals[1] = 90;
      final r = e.applyDart(10, 1); // P1: S10 = 10 points, newTotal 90+10=100
      expect(r.killed, [0]); // P0 at 100
      expect(e.totals[0], 50); // P0 halved
      expect(e.totals[1], 100); // P1 at landing value, not halved
    });
    test('undo across a halving restores counters and log', () {
      final e = GotchaEngine(target: 301, playerCount: 2);
      e.totals[0] = 300; e.currentPlayerIndex = 1; e.totals[1] = 280;
      e.applyDart(20, 1); // lands on 300, halves P0
      expect(e.totals[0], 150);
      expect(e.killsMade[1], 1);
      expect(e.timesKilled[0], 1);
      expect(e.killLog, hasLength(1));
      e.undo();
      expect(e.totals[0], 300); // restored
      expect(e.killsMade[1], 0);
      expect(e.timesKilled[0], 0);
      expect(e.killLog, isEmpty);
    });
  });

  group('GotchaEngine round counter', () {
    test('round increments on rotation wrap and restores on undo', () {
      final e = GotchaEngine(target: 301, playerCount: 2);
      expect(e.round, 0);
      for (var i = 0; i < 6; i++) {
        e.applyDart(1, 1);
      } // P0 turn + P1 turn
      expect(e.round, 1);
      e.undo();
      expect(e.round, 0);
    });
  });

  group('GotchaEngine.singleDartLabel', () {
    test('notation preferences per spec §3.2', () {
      expect(GotchaEngine.singleDartLabel(18), 'S18'); // not D9/T6
      expect(GotchaEngine.singleDartLabel(25), '25');
      expect(GotchaEngine.singleDartLabel(50), 'BULL');
      expect(GotchaEngine.singleDartLabel(40), 'D20');
      expect(GotchaEngine.singleDartLabel(57), 'T19');
      expect(GotchaEngine.singleDartLabel(60), 'T20');
      expect(GotchaEngine.singleDartLabel(23), isNull);
      expect(GotchaEngine.singleDartLabel(41), isNull);
      expect(GotchaEngine.singleDartLabel(0), isNull);
      expect(GotchaEngine.singleDartLabel(-5), isNull);
      expect(GotchaEngine.singleDartLabel(61), isNull);
    });
  });

  group('GotchaEngine.killTips', () {
    test('one tip per killable opponent; dead and trailing excluded', () {
      final e = GotchaEngine(target: 301, playerCount: 4);
      // craft totals directly (white-box, engine lists are public)
      e.totals[0] = 132; e.totals[1] = 149; e.totals[2] = 172; e.totals[3] = 0;
      e.currentPlayerIndex = 0;
      final tips = e.killTips();
      expect(tips, [('S17', 1), ('D20', 2)]); // 149-132=17, 172-132=40; P3 dead
    });
    test('no tips when game over', () {
      final e = GotchaEngine(target: 301, playerCount: 2);
      e.totals[1] = 20; e.gameOver = true;
      expect(e.killTips(), isEmpty);
    });
  });

  group('GotchaEngine roster', () {
    test('addPlayer joins at initial score and clears undo', () {
      final e = GotchaEngine(target: 301, playerCount: 2);
      e.applyDart(20, 1);
      e.addPlayer(initialScore: 50);
      expect(e.playerCount, 3);
      expect(e.totals[2], 50);
      expect(e.canUndo, isFalse);
    });
    test('removing current player advances the seat and resets turn baseline', () {
      final e = GotchaEngine(target: 301, playerCount: 3);
      e.applyDart(20, 1); // P0 mid-turn
      e.removePlayer(0);
      expect(e.currentPlayerIndex, 1);
      expect(e.dartsInTurn, 0);
      expect(e.isSkipped(0), isTrue);
    });
    test('removal down to one active player ends the game with the survivor', () {
      final e = GotchaEngine(target: 301, playerCount: 3);
      e.removePlayer(0);
      e.removePlayer(2);
      expect(e.gameOver, isTrue);
      expect(e.winnerIndex, 1);
    });
    test('a removed player is never the winner', () {
      final e = GotchaEngine(target: 301, playerCount: 3);
      e.totals[0] = 250; // leader
      e.removePlayer(0);
      e.removePlayer(2);
      expect(e.winnerIndex, 1); // survivor, not the removed leader
    });
  });
}
