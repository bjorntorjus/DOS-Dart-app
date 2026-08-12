import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/services/shot_clock.dart';

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

  test('the first turn of a game never counts, however long it takes', () {
    turnTaking('Ada', 600);
    expect(ShotClock.instance.slowTurnsFor('Ada'), 0);
  });

  test('the 60 second bar is exclusive on one side and inclusive on the other',
      () {
    turnTaking('Ada', 1); // first turn — ignored
    turnTaking('Ada', 59);
    expect(ShotClock.instance.slowTurnsFor('Ada'), 0);
    turnTaking('Ada', 61);
    expect(ShotClock.instance.slowTurnsFor('Ada'), 1);
  });

  test('slow turns accumulate per player', () {
    turnTaking('Ada', 1); // first turn
    turnTaking('Ada', 90);
    turnTaking('Bo', 90);
    turnTaking('Ada', 90);
    expect(ShotClock.instance.slowTurnsFor('Ada'), 2);
    expect(ShotClock.instance.slowTurnsFor('Bo'), 1);
  });

  test('a turn with no dart records nothing, even a very long one', () {
    ShotClock.instance.startTurn('Ada'); // first turn
    ShotClock.instance.startTurn('Bo');
    ShotClock.elapsedOverride = () => const Duration(hours: 8);
    ShotClock.instance.startTurn('Ada'); // Bo never threw

    expect(ShotClock.instance.slowTurnsFor('Bo'), 0,
        reason: 'an abandoned turn is not a slow turn — nobody was there');
  });

  test('only the first dart of a turn measures it', () {
    turnTaking('Ada', 1); // first turn
    ShotClock.instance.startTurn('Ada');
    ShotClock.elapsedOverride = () => const Duration(seconds: 90);
    ShotClock.instance.registerDart();
    ShotClock.instance.registerDart();
    ShotClock.instance.registerDart();

    expect(ShotClock.instance.slowTurnsFor('Ada'), 1,
        reason: 'three darts in one turn is still one slow turn');
  });

  test('stop ends the turn without measuring it', () {
    turnTaking('Ada', 1); // first turn
    ShotClock.instance.startTurn('Ada');
    ShotClock.elapsedOverride = () => const Duration(seconds: 90);
    ShotClock.instance.stop();
    ShotClock.instance.registerDart();

    expect(ShotClock.instance.slowTurnsFor('Ada'), 0);
  });

  test('resetGame clears the tally and the first-turn grace returns', () {
    turnTaking('Ada', 1);
    turnTaking('Ada', 90);
    expect(ShotClock.instance.slowTurnsFor('Ada'), 1);

    ShotClock.instance.resetGame();

    expect(ShotClock.instance.slowTurnsFor('Ada'), 0);
    turnTaking('Ada', 600);
    expect(ShotClock.instance.slowTurnsFor('Ada'), 0,
        reason: 'a new game gets its first-turn grace back');
  });

  test('an unknown name has no slow turns', () {
    expect(ShotClock.instance.slowTurnsFor('Nobody'), 0);
  });
}
