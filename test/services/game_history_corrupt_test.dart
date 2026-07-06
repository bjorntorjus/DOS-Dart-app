import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/services/game_history_service.dart';

/// F14 (audit 2026-07-06): a single decode failure used to wipe all history —
/// load() returned [] and the next record() overwrote the store with one entry.
/// Now the unreadable data is preserved under a corrupt-backup key.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  GameHistoryEntry entry(String id) => GameHistoryEntry(
        id: id,
        gameMode: 'x01',
        date: DateTime(2026, 1, 1),
        players: const [],
        throwHistory: [
          DartThrow(playerIndex: 0, segment: 20, multiplier: 1, points: 20,
              scoreBefore: 501, turnNumber: 0, scoreAtStartOfTurn: 501,
              turnId: 1, roundNumber: 1),
        ],
      );

  test('load reports failure and preserves unparseable data', () async {
    SharedPreferences.setMockInitialValues({
      'game_history_v1': '{ this is not valid json ]',
    });

    final result = await GameHistoryService.load();

    expect(result, isEmpty);
    expect(GameHistoryService.lastLoadFailed, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('game_history_v1_corrupt'),
        '{ this is not valid json ]',
        reason: 'the raw unreadable data must be backed up, not discarded');
  });

  test('record after a corrupt load keeps the backup and does not lose it',
      () async {
    SharedPreferences.setMockInitialValues({
      'game_history_v1': 'totally broken',
    });

    await GameHistoryService.record(entry('new'));

    final prefs = await SharedPreferences.getInstance();
    // Old (corrupt) data still recoverable...
    expect(prefs.getString('game_history_v1_corrupt'), 'totally broken');
    // ...and the new game was still recorded (fresh store), not dropped.
    final reloaded = await GameHistoryService.load();
    expect(reloaded.map((e) => e.id), ['new']);
    expect(GameHistoryService.lastLoadFailed, isFalse);
  });

  test('normal round-trip is unaffected', () async {
    await GameHistoryService.record(entry('a'));
    await GameHistoryService.record(entry('b'));
    final reloaded = await GameHistoryService.load();
    expect(reloaded.map((e) => e.id), ['b', 'a']); // newest first
    expect(GameHistoryService.lastLoadFailed, isFalse);
  });
}
