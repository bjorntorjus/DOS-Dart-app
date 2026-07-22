import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/stats_recorder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  SavedPlayer p(String id) =>
      SavedPlayer(id: id, name: id, createdAt: DateTime(2020));

  void play(List<SavedPlayer> sps, List<int> placements) {
    StatsRecorder.recordGame(
      gameMode: 'x01',
      playerIds: sps.map((s) => s.id).toList(),
      playerNames: sps.map((s) => s.name).toList(),
      placements: placements,
      savedPlayers: sps,
    );
  }

  test('H2H accumulates wins/losses/draws symmetrically across games', () {
    final a = p('a'), b = p('b');
    play([a, b], [1, 2]); // a wins
    play([a, b], [2, 1]); // b wins
    play([a, b], [1, 1]); // draw

    final aVsB = a.headToHead['b']!;
    expect(aVsB.wins, 1);
    expect(aVsB.losses, 1);
    expect(aVsB.draws, 1);

    final bVsA = b.headToHead['a']!;
    expect(bVsA.wins, 1);
    expect(bVsA.losses, 1);
    expect(bVsA.draws, 1);
  });

  test('H2H skips guest (null) opponents', () {
    final a = p('a');
    StatsRecorder.recordGame(
      gameMode: 'x01',
      playerIds: [a.id, null],
      playerNames: [a.name, 'Guest'],
      placements: [1, 2],
      savedPlayers: [a],
    );

    expect(a.headToHead, isEmpty);
  });

  test('shared best placement is a draw: nobody gets won, sole loser gets a loss streak', () {
    final a = p('a'), b = p('b'), c = p('c');
    play([a, b, c], [1, 1, 2]);

    expect(a.modeStats['x01']!.won, 0);
    expect(b.modeStats['x01']!.won, 0);
    expect(c.currentLossStreak, 1);
  });

  test('rating-history snapshot captures call-time rating and rank-based placement', () {
    final a = p('a')..rating = 1300;
    final b = p('b')..rating = 1200;
    final c = p('c')..rating = 1100;
    final sps = [a, b, c];

    play(sps, [1, 2, 3]); // first game, ratings as set above
    a.rating = 1350;
    play(sps, [2, 1, 3]); // second game, a's rating changed since the first call

    expect(a.ratingHistory.length, 2);
    expect(a.ratingHistory[0].rating, 1300);
    expect(a.ratingHistory[1].rating, 1350);
    // b sits in the middle by rating (1200) among [1300, 1200, 1100] -> rank 2.
    expect(b.ratingHistory[0].placement, 2);
  });

  test('counter merge: max: keeps larger, min: keeps smaller (unset 0 loses first), plain key sums', () {
    final a = p('a'), b = p('b');

    StatsRecorder.recordGame(
      gameMode: 'halveIt',
      playerIds: [a.id, b.id],
      playerNames: [a.name, b.name],
      placements: [1, 2],
      savedPlayers: [a, b],
      modeCounters: {
        'a': {'max:biggestHalving': 40, 'min:bestLeg': 15, 'doublesHit': 2},
      },
    );
    final afterGame1 = a.modeStats['halveIt']!;
    expect(afterGame1.get('biggestHalving'), 40);
    expect(afterGame1.get('bestLeg'), 15);
    expect(afterGame1.get('doublesHit'), 2);

    StatsRecorder.recordGame(
      gameMode: 'halveIt',
      playerIds: [a.id, b.id],
      playerNames: [a.name, b.name],
      placements: [2, 1],
      savedPlayers: [a, b],
      modeCounters: {
        'a': {'max:biggestHalving': 30, 'min:bestLeg': 10, 'doublesHit': 3},
      },
    );
    final afterGame2 = a.modeStats['halveIt']!;
    expect(afterGame2.get('biggestHalving'), 40); // max keeps the larger of 40/30
    expect(afterGame2.get('bestLeg'), 10); // min keeps the smaller of 15/10
    expect(afterGame2.get('doublesHit'), 5); // plain key sums 2 + 3
  });
}
