import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/shot_clock.dart';
import 'package:dart_scoring/services/stats_recorder.dart';
import 'package:dart_scoring/stats/profile_stats.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ShotClock.instance.resetGame();
    ShotClock.disableForTest = true;
  });

  tearDown(() {
    ShotClock.elapsedOverride = null;
    ShotClock.disableForTest = false;
  });

  void slowTurn(String name) {
    ShotClock.instance.startTurn(name);
    ShotClock.elapsedOverride = () => const Duration(seconds: 90);
    ShotClock.instance.registerDart();
  }

  test('the tally lands in modeStats and the clock resets for the next game',
      () {
    ShotClock.instance.startTurn('Ada'); // first turn — grace
    slowTurn('Ada');
    slowTurn('Ada');

    final ada = SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026));
    StatsRecorder.recordGame(
      gameMode: 'x01',
      playerIds: const ['a'],
      playerNames: const ['Ada'],
      placements: const [1],
      savedPlayers: [ada],
    );

    expect(ada.modeStats['x01']!.get('slowTurns'), 2);
    expect(ShotClock.instance.slowTurnsFor('Ada'), 0,
        reason: 'the tally is per game and resets once recorded');
  });

  test('a clean game records no counter at all', () {
    final ada = SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026));
    StatsRecorder.recordGame(
      gameMode: 'x01',
      playerIds: const ['a'],
      playerNames: const ['Ada'],
      placements: const [1],
      savedPlayers: [ada],
    );
    expect(ada.modeStats['x01']?.get('slowTurns') ?? 0, 0);
  });

  test('a guest without a saved id does not break the merge', () {
    ShotClock.instance.startTurn('Ada'); // first turn
    slowTurn('Guest');

    final ada = SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026));
    StatsRecorder.recordGame(
      gameMode: 'x01',
      playerIds: const [null, 'a'],
      playerNames: const ['Guest', 'Ada'],
      placements: const [1, 2],
      savedPlayers: [ada],
    );

    expect(ada.modeStats['x01']?.get('slowTurns') ?? 0, 0,
        reason: "the guest's slow turn belongs to nobody on file");
  });

  test('the profile sums slow turns across modes', () {
    final ada = SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026));
    ada.modeStats['x01'] = ModeStats(played: 5, counters: {'slowTurns': 4});
    ada.modeStats['cricket'] = ModeStats(played: 3, counters: {'slowTurns': 3});

    final tile = careerRecords(ada).firstWhere((r) => r.label == 'slow turns');

    expect(tile.value, '7');
  });

  test('a player who has never dawdled gets no tile', () {
    final ada = SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026));
    ada.modeStats['x01'] = ModeStats(played: 5);

    expect(careerRecords(ada).where((r) => r.label == 'slow turns'), isEmpty,
        reason: 'an empty shame counter is not worth a tile');
  });
}
