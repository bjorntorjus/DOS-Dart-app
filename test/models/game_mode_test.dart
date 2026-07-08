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

  test('wildcard mode metadata', () {
    expect(GameMode.wildcard.label, 'WILDCARD');
    expect(GameMode.wildcard.emoji, '🃏');
    expect(const WildcardConfig().rounds, 10);
    expect(const WildcardConfig().startingChaos, 5);
    expect(const WildcardConfig(rounds: 15, startingChaos: 8).rounds, 15);
    expect(
      const WildcardConfig(rounds: 15, startingChaos: 8).startingChaos,
      8,
    );
    expect(const WildcardConfig().mode, GameMode.wildcard);
  });
}
