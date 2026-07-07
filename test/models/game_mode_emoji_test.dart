import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/game_mode.dart';

void main() {
  test('every mode has one canonical emoji (DOSSEDART set)', () {
    expect(GameMode.cricket.emoji, '🎯');
    expect(GameMode.aroundTheClock.emoji, '🕐');
    expect(GameMode.killer.emoji, '🔪');
    expect(GameMode.halveIt.emoji, '✂️');
    expect(GameMode.shanghai.emoji, '🐉');
    expect(GameMode.x01.emoji, '💯');
  });

  test('halveIt label is Splitscore (F24 regression)', () {
    expect(GameMode.halveIt.label, 'Splitscore');
  });
}
