import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/services/app_settings.dart';
import 'package:dart_scoring/services/game_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mode setter exposes current mode', () {
    GameLogger.instance.setMode(LogMode.full);
    expect(GameLogger.instance.mode, LogMode.full);

    GameLogger.instance.setMode(LogMode.minimal);
    expect(GameLogger.instance.mode, LogMode.minimal);

    GameLogger.instance.setMode(LogMode.off);
    expect(GameLogger.instance.mode, LogMode.off);
  });

  test('isBatteryAllowed reflects mode rules', () {
    GameLogger.instance.setMode(LogMode.full);
    expect(GameLogger.instance.isBatteryAllowed, isTrue);

    GameLogger.instance.setMode(LogMode.minimal);
    expect(GameLogger.instance.isBatteryAllowed, isTrue);

    GameLogger.instance.setMode(LogMode.off);
    expect(GameLogger.instance.isBatteryAllowed, isFalse);
  });

  test('isGeneralAllowed reflects mode rules', () {
    GameLogger.instance.setMode(LogMode.full);
    expect(GameLogger.instance.isGeneralAllowed, isTrue);

    GameLogger.instance.setMode(LogMode.minimal);
    expect(GameLogger.instance.isGeneralAllowed, isFalse);

    GameLogger.instance.setMode(LogMode.off);
    expect(GameLogger.instance.isGeneralAllowed, isFalse);
  });
}
