import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/services/player_storage.dart';

/// F14/F20 (audit 2026-07-06): a corrupt saved_players blob must not crash
/// the app or be silently lost — mirror game_history_service's backup-key
/// pattern. Legacy JSON with missing optional fields must load with defaults.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('corrupt JSON returns [] and preserves the raw blob', () async {
    const raw = '{ this is not valid json ]';
    SharedPreferences.setMockInitialValues({'saved_players': raw});

    final players = await PlayerStorage.loadPlayers();

    expect(players, isEmpty);
    expect(PlayerStorage.lastLoadFailed, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('saved_players_corrupt'), raw,
        reason: 'raw data must be preserved for recovery, not discarded');
  });

  test('legacy JSON without newer fields loads with defaults', () async {
    const legacy =
        '[{"id":"p1","name":"Old Timer","createdAt":"2024-01-01T00:00:00.000"}]';
    SharedPreferences.setMockInitialValues({'saved_players': legacy});

    final players = await PlayerStorage.loadPlayers();

    expect(PlayerStorage.lastLoadFailed, isFalse);
    expect(players, hasLength(1));
    final p = players.first;
    expect(p.rating, 1200.0);
    expect(p.modeStats, isEmpty);
    expect(p.headToHead, isEmpty);
    expect(p.ratingHistory, isEmpty);
    expect(p.currentWinStreak, 0);
  });

  test('healthy load resets lastLoadFailed', () async {
    SharedPreferences.setMockInitialValues({'saved_players': '[]'});
    await PlayerStorage.loadPlayers();
    expect(PlayerStorage.lastLoadFailed, isFalse);
  });
}
