import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/dart_throw.dart';

void main() {
  test('isBust defaults to false and round-trips through constructor', () {
    final t = DartThrow(
      playerIndex: 0,
      segment: 20,
      multiplier: 3,
      points: 60,
      scoreBefore: 100,
      turnNumber: 0,
      scoreAtStartOfTurn: 100,
    );
    expect(t.isBust, isFalse);

    final bust = DartThrow(
      playerIndex: 0,
      segment: 20,
      multiplier: 3,
      points: 60,
      scoreBefore: 40,
      turnNumber: 1,
      scoreAtStartOfTurn: 100,
      isBust: true,
    );
    expect(bust.isBust, isTrue);
  });
}
