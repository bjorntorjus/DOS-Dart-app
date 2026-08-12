import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/services/shot_clock.dart';

/// NOTE ON THE FIRST TURN (corrected 2026-08-12 from a real log).
///
/// An earlier version of this file asserted that "the first turn of a game
/// never counts", and the service implemented a grace period to match. Both
/// were wrong, and the test passed only because it tested the same mistaken
/// model as the code.
///
/// No mode announces a player at game start — every `announceNextPlayer` call
/// site sits in an advance/turn-end method. So the game's opening turn never
/// reaches the clock at all, and the FIRST call it does see is the second
/// player's first real turn. The grace was eating exactly the turn the feature
/// exists to measure.
void main() {
  setUp(() {
    ShotClock.instance.resetGame();
    ShotClock.disableForTest = true; // no real Timer in unit tests
  });

  tearDown(() {
    ShotClock.elapsedOverride = null;
    ShotClock.disableForTest = false;
  });

  void turnTaking(String name, int seconds) {
    ShotClock.instance.startTurn(name);
    ShotClock.elapsedOverride = () => Duration(seconds: seconds);
    ShotClock.instance.registerDart();
  }

  test('the very first announced turn is a real turn and counts', () {
    // Reproduces the 2026-08-12 report: P0 threw three darts, the turn
    // advanced to P1, and nothing ever fired.
    turnTaking('Aaa', 90);
    expect(ShotClock.instance.slowTurnsFor('Aaa'), 1,
        reason: 'the first startTurn of a game is the SECOND player, and '
            'their turn is as real as any other');
  });

  test('the 60 second bar is exclusive on one side and inclusive on the other',
      () {
    turnTaking('Ada', 59);
    expect(ShotClock.instance.slowTurnsFor('Ada'), 0);
    turnTaking('Ada', 61);
    expect(ShotClock.instance.slowTurnsFor('Ada'), 1);
  });

  test('slow turns accumulate per player', () {
    turnTaking('Ada', 90);
    turnTaking('Bo', 90);
    turnTaking('Ada', 90);
    expect(ShotClock.instance.slowTurnsFor('Ada'), 2);
    expect(ShotClock.instance.slowTurnsFor('Bo'), 1);
  });

  test('a turn with no dart records nothing, even a very long one', () {
    ShotClock.instance.startTurn('Bo');
    ShotClock.elapsedOverride = () => const Duration(hours: 8);
    ShotClock.instance.startTurn('Ada'); // Bo never threw

    expect(ShotClock.instance.slowTurnsFor('Bo'), 0,
        reason: 'an abandoned turn is not a slow turn — nobody was there');
  });

  test('only the first dart of a turn measures it', () {
    ShotClock.instance.startTurn('Ada');
    ShotClock.elapsedOverride = () => const Duration(seconds: 90);
    ShotClock.instance.registerDart();
    ShotClock.instance.registerDart();
    ShotClock.instance.registerDart();

    expect(ShotClock.instance.slowTurnsFor('Ada'), 1,
        reason: 'three darts in one turn is still one slow turn');
  });

  test('stop ends the turn without measuring it', () {
    ShotClock.instance.startTurn('Ada');
    ShotClock.elapsedOverride = () => const Duration(seconds: 90);
    ShotClock.instance.stop();
    ShotClock.instance.registerDart();

    expect(ShotClock.instance.slowTurnsFor('Ada'), 0);
  });

  test('resetGame clears the tally', () {
    turnTaking('Ada', 90);
    expect(ShotClock.instance.slowTurnsFor('Ada'), 1);

    ShotClock.instance.resetGame();

    expect(ShotClock.instance.slowTurnsFor('Ada'), 0);
  });

  test('a new game measures its first announced turn too', () {
    turnTaking('Ada', 90);
    ShotClock.instance.resetGame();

    turnTaking('Ada', 90);
    expect(ShotClock.instance.slowTurnsFor('Ada'), 1,
        reason: 'no grace period survives a reset, because there is none');
  });

  test('an unknown name has no slow turns', () {
    expect(ShotClock.instance.slowTurnsFor('Nobody'), 0);
  });
}
