import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/elo_service.dart';

SavedPlayer p(String id, double rating) =>
    SavedPlayer(id: id, name: id, createdAt: DateTime(2026), rating: rating);

void main() {
  test('cricket counts under both of its history keys', () {
    expect(EloService.isRatedMode('cricket'), isTrue);
    expect(EloService.isRatedMode('cricket_cutthroat'), isTrue,
        reason: 'the cutthroat variant writes its own key');
  });

  test('wildcard and killer do not count', () {
    expect(EloService.isRatedMode('wildcard'), isFalse);
    expect(EloService.isRatedMode('killer'), isFalse);
  });

  test('an unknown future mode is rated by default', () {
    expect(EloService.isRatedMode('shuffleboard'), isTrue,
        reason: 'the set lists exclusions, so forgetting one is the safe way');
  });

  test('an unrated game leaves every rating untouched', () {
    final players = [p('a', 1300), p('b', 1100)];
    EloService.updateRatings(
      gameMode: 'killer',
      playerIds: const ['a', 'b'],
      placements: const [1, 2],
      savedPlayers: players,
    );
    expect(players[0].rating, 1300);
    expect(players[1].rating, 1100);
  });

  test('a rated game still moves them', () {
    final players = [p('a', 1300), p('b', 1100)];
    EloService.updateRatings(
      gameMode: 'x01',
      playerIds: const ['a', 'b'],
      placements: const [1, 2],
      savedPlayers: players,
    );
    expect(players[0].rating, greaterThan(1300));
    expect(players[1].rating, lessThan(1100));
  });
}
