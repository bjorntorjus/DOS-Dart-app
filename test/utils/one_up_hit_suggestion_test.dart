import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/utils/one_up_hit_suggestion.dart';

void main() {
  group('oneUpHitSuggestion', () {
    test('exact single-dart hits, simplest label wins', () {
      expect(oneUpHitSuggestion(20), '20'); // S20 exact
      expect(oneUpHitSuggestion(25), '25'); // 25 beats D? (no D=25); exact
      expect(oneUpHitSuggestion(40), 'D20'); // no single 40; D20 exact
      expect(oneUpHitSuggestion(48), 'T16'); // T16 exact
      expect(oneUpHitSuggestion(60), 'T20'); // max
      expect(oneUpHitSuggestion(50), 'BULL'); // 50: no S/D25×2=D25? BULL label
    });

    test('overshoot gets the + suffix', () {
      expect(oneUpHitSuggestion(47), 'T16 +'); // lowest >= 47 is 48 = T16
      expect(oneUpHitSuggestion(41), 'T14 +'); // 42 = T14 (D21 does not exist)
      expect(oneUpHitSuggestion(59), 'T20 +'); // 60
    });

    test('bounds: nothing needed or impossible', () {
      expect(oneUpHitSuggestion(0), isNull);
      expect(oneUpHitSuggestion(-5), isNull);
      expect(oneUpHitSuggestion(61), isNull);
    });

    test('every need 1..60 returns a suggestion', () {
      for (var need = 1; need <= 60; need++) {
        expect(oneUpHitSuggestion(need), isNotNull, reason: 'need=$need');
      }
    });
  });
}
