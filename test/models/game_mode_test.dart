import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/game_mode.dart';
import 'package:dart_scoring/models/game_config.dart';

void main() {
  test('gotcha mode metadata', () {
    expect(GameMode.gotcha.label, 'Gotcha');
    expect(GameMode.gotcha.emoji, '💀');
    expect(const GotchaConfig().targetScore, 301);
    expect(const GotchaConfig(targetScore: 101).mode, GameMode.gotcha);
  });
}
