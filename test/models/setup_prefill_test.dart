import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/setup_prefill.dart';

void main() {
  test('rematchPlayerIds keeps seat order, drops removed seats and guests',
      () {
    final players = [
      Player(name: 'A', score: 0, savedPlayerId: 'a'),
      Player(name: 'Guest', score: 0), // no saved id
      Player(name: 'B', score: 0, savedPlayerId: 'b'),
      Player(name: 'C', score: 0, savedPlayerId: 'c'),
    ];
    final ids = rematchPlayerIds(players, (i) => i == 3); // C removed mid-game
    expect(ids, ['a', 'b']);
  });
}
