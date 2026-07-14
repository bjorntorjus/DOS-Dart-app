import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/app_version.dart';
import 'package:dart_scoring/services/app_settings.dart';
import 'package:dart_scoring/services/game_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('formatStandings joins name:score pairs', () {
    expect(GameLogger.formatStandings(['Aa', 'Aaa'], [69, 76]), 'Aa:69  Aaa:76');
  });

  test('formatStandings tolerates length mismatch (zips to shortest)', () {
    expect(GameLogger.formatStandings(['Aa'], [69, 76]), 'Aa:69');
  });

  test('kAppVersion is a non-empty v-string', () {
    expect(kAppVersion.startsWith('v'), isTrue);
  });

  test('logStandings and logRoster are gated by isGeneralAllowed (no throw when disabled)', () {
    GameLogger.instance.setMode(LogMode.off);
    expect(
      () => GameLogger.instance.logStandings(roundNumber: 1, names: ['Aa'], scores: [69]),
      returnsNormally,
    );
    expect(
      () => GameLogger.instance.logRoster(
        action: 'ADD',
        playerIndex: 2,
        playerName: 'Bb',
        names: ['Aa', 'Bb'],
        scores: [69, 0],
      ),
      returnsNormally,
    );
  });

  test('logGameStart accepts an optional build stamp (no throw when disabled)', () {
    GameLogger.instance.setMode(LogMode.off);
    expect(
      () => GameLogger.instance.logGameStart(
        gameMode: 'X01',
        playerNames: ['Aa'],
        playerScores: [501],
        build: kAppVersion,
      ),
      returnsNormally,
    );
  });
}
