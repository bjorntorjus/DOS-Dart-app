// test/services/elo_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/elo_service.dart';

/// F20 (audit 2026-07-06): the app's headline number had zero tests.
/// These characterize EloService with its compile-time defaults
/// (K-new 32, K-exp 16, threshold 20, floor 100). loadSettings() is
/// deliberately never called — it mutates process-wide static state.
void main() {
  SavedPlayer sp(String id, {double rating = 1200, int games = 0}) =>
      SavedPlayer(id: id, name: id, createdAt: DateTime(2020))
        ..rating = rating
        ..gamesPlayed = games;

  group('kFactor', () {
    test('new player (< 20 games) gets K=32', () {
      expect(EloService.kFactor(0), 32.0);
      expect(EloService.kFactor(19), 32.0);
    });
    test('experienced player (>= 20 games) gets K=16', () {
      expect(EloService.kFactor(20), 16.0);
      expect(EloService.kFactor(500), 16.0);
    });
  });

  group('updateRatings — two equal players', () {
    test('winner +16, loser -16 at default K (zero-sum)', () {
      final a = sp('a'), b = sp('b');
      EloService.updateRatings(
        gameMode: 'x01',
        playerIds: ['a', 'b'],
        placements: [1, 2],
        savedPlayers: [a, b],
      );
      expect(a.rating, closeTo(1216, 0.001));
      expect(b.rating, closeTo(1184, 0.001));
    });

    test('draw moves nothing', () {
      final a = sp('a'), b = sp('b');
      EloService.updateRatings(
        gameMode: 'x01',
        playerIds: ['a', 'b'],
        placements: [1, 1],
        savedPlayers: [a, b],
      );
      expect(a.rating, 1200);
      expect(b.rating, 1200);
    });
  });

  test('each player uses their OWN K — asymmetric deltas', () {
    final newbie = sp('n', games: 0); // K=32
    final vet = sp('v', games: 100); // K=16
    EloService.updateRatings(
        gameMode: 'x01',
      playerIds: ['n', 'v'],
      placements: [1, 2],
      savedPlayers: [newbie, vet],
    );
    expect(newbie.rating, closeTo(1216, 0.001)); // 32 * 0.5
    expect(vet.rating, closeTo(1192, 0.001)); // 16 * 0.5
  });

  test('rating floor: a heavy loss never drops a player below 100', () {
    // Losing to an evenly-matched opponent costs ~16 points; from 105
    // that would land at ~88.8, which the floor clamps to 100.
    final low = sp('low', rating: 105), weak = sp('weak', rating: 100);
    EloService.updateRatings(
        gameMode: 'x01',
      playerIds: ['low', 'weak'],
      placements: [2, 1],
      savedPlayers: [low, weak],
    );
    expect(low.rating, 100);
    expect(weak.rating, greaterThan(100)); // winner still gains normally
  });

  group('guests', () {
    test('a game with fewer than two saved players changes nothing', () {
      final a = sp('a');
      EloService.updateRatings(
        gameMode: 'x01',
        playerIds: ['a', null, null],
        placements: [1, 2, 3],
        savedPlayers: [a],
      );
      expect(a.rating, 1200);
    });

    test('F29 characterization: guests dilute the 1/(n-1) scale', () {
      // 2 saved + 2 guests: scale = 1/3 instead of 1/1, so the single
      // saved-vs-saved pair moves ratings a third as much as a pure
      // 2-player game. This matches the doc comment on updateRatings;
      // audit F29 questions whether guests SHOULD count in the divisor.
      // If that product decision changes, flip this expectation.
      final a = sp('a'), b = sp('b');
      EloService.updateRatings(
        gameMode: 'x01',
        playerIds: ['a', null, 'b', null],
        placements: [1, 2, 3, 4],
        savedPlayers: [a, b],
      );
      expect(a.rating, closeTo(1200 + 16.0 / 3, 0.001));
      expect(b.rating, closeTo(1200 - 16.0 / 3, 0.001));
    });
  });

  test('unknown ids are treated as guests', () {
    final a = sp('a');
    EloService.updateRatings(
        gameMode: 'x01',
      playerIds: ['a', 'ghost'],
      placements: [1, 2],
      savedPlayers: [a],
    );
    expect(a.rating, 1200);
  });
}
