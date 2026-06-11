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

  test('win/loss streaks update and bestWinStreak high-water-marks', () {
    final a = p('a'), b = p('b');
    play([a, b], [1, 2]); // a wins
    play([a, b], [1, 2]); // a wins
    play([a, b], [2, 1]); // a loses
    expect(a.currentWinStreak, 0);
    expect(a.bestWinStreak, 2);
    expect(a.currentLossStreak, 1);
    expect(b.currentWinStreak, 1);
    expect(b.currentLossStreak, 0);
  });

  test('a tie breaks both streaks without counting as win or loss', () {
    final a = p('a'), b = p('b');
    play([a, b], [1, 2]); // a wins
    play([a, b], [1, 1]); // tie
    expect(a.currentWinStreak, 0);
    expect(a.currentLossStreak, 0);
    expect(a.bestWinStreak, 1);
  });
}
