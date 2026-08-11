import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/game_result.dart';

void main() {
  test('durationSeconds defaults to null and round-trips when set', () {
    final bare = GameResult(gameMode: 'x01', results: const []);
    expect(bare.durationSeconds, isNull);

    final timed =
        GameResult(gameMode: 'x01', results: const [], durationSeconds: 1122);
    expect(timed.durationSeconds, 1122);
  });
}
